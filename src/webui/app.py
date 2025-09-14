import os
import json
import requests
import re
import secrets
import uuid
import queue
import threading
from collections import defaultdict, deque
from datetime import datetime, timedelta
from flask import Flask, render_template, request, jsonify, send_file, redirect, url_for, session
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.utils import secure_filename
import tempfile
import yaml
import hashlib
import time
import concurrent.futures
from multiprocessing import cpu_count

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = '/app/voices'

# Security Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', secrets.token_hex(32))
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024  # 16KB max request size

# Session-based user identification
def get_session_id():
    """Get or create a session ID for the user, with fallback for no cookies"""
    try:
        # Try to use session cookies first
        if 'user_id' not in session:
            session['user_id'] = str(uuid.uuid4())
            session.permanent = True
            app.permanent_session_lifetime = timedelta(days=30)
        return session['user_id'], 'session'
    except Exception:
        # Fallback to IP-based identification when cookies are disabled
        ip = get_remote_address()
        return f"ip:{ip}", 'ip'

def get_user_info():
    """Get user ID and type, with appropriate limits"""
    user_id, user_type = get_session_id()
    ip_address = get_remote_address()

    # Always have IP-based limits to prevent abuse
    ip_limits = {
        'requests_per_minute': 50,  # Per IP regardless of sessions
        'requests_per_hour': 200,   # Per IP abuse prevention
        'max_concurrent_per_ip': 5  # Hard limit per IP
    }

    # Session-specific limits for fair sharing
    if user_type == 'ip':
        # When cookies disabled, be more conservative
        session_limits = {
            'max_concurrent': 1,
            'fair_usage_limit': 5,
            'description': 'Limited mode (cookies disabled - IP tracking only)'
        }
    else:
        # Full features with session tracking
        session_limits = {
            'max_concurrent': 3,
            'fair_usage_limit': 15,
            'description': 'Full mode (session + IP tracking)'
        }

    return {
        'user_id': user_id,
        'user_type': user_type,
        'ip_address': ip_address,
        'ip_limits': ip_limits,
        'session_limits': session_limits
    }

# Global job queue and user management
class UserJobManager:
    def __init__(self, max_concurrent_per_user=3, max_queue_per_user=10):
        self.user_queues = defaultdict(deque)
        self.user_active_jobs = defaultdict(int)
        self.user_last_activity = defaultdict(datetime)
        self.max_concurrent_per_user = max_concurrent_per_user
        self.max_queue_per_user = max_queue_per_user
        self.lock = threading.Lock()

    def can_add_job(self, user_id):
        """Check if user can add more jobs"""
        with self.lock:
            total_jobs = self.user_active_jobs[user_id] + len(self.user_queues[user_id])
            return total_jobs < (self.max_concurrent_per_user + self.max_queue_per_user)

    def add_job(self, user_id, job_data):
        """Add job to user's queue"""
        with self.lock:
            if self.can_add_job(user_id):
                self.user_queues[user_id].append(job_data)
                self.user_last_activity[user_id] = datetime.now()
                return True
            return False

    def start_job(self, user_id):
        """Mark job as started for user"""
        with self.lock:
            if self.user_queues[user_id] and self.user_active_jobs[user_id] < self.max_concurrent_per_user:
                self.user_active_jobs[user_id] += 1
                return self.user_queues[user_id].popleft()
        return None

    def finish_job(self, user_id):
        """Mark job as finished for user"""
        with self.lock:
            if self.user_active_jobs[user_id] > 0:
                self.user_active_jobs[user_id] -= 1

    def get_user_status(self, user_id):
        """Get user's queue status"""
        with self.lock:
            return {
                'active_jobs': self.user_active_jobs[user_id],
                'queued_jobs': len(self.user_queues[user_id]),
                'can_add_more': self.can_add_job(user_id)
            }

    def cleanup_inactive_users(self, hours=24):
        """Remove data for users inactive for X hours"""
        cutoff = datetime.now() - timedelta(hours=hours)
        with self.lock:
            inactive_users = [
                user_id for user_id, last_activity in self.user_last_activity.items()
                if last_activity < cutoff and self.user_active_jobs[user_id] == 0
            ]
            for user_id in inactive_users:
                del self.user_queues[user_id]
                del self.user_active_jobs[user_id]
                del self.user_last_activity[user_id]

# Initialize job manager
job_manager = UserJobManager(max_concurrent_per_user=3, max_queue_per_user=20)

# Server capacity and fair usage system
class ServerCapacityManager:
    def __init__(self):
        self.max_concurrent_generations = min(cpu_count(), 8) * 2  # Allow some queueing
        self.current_active_generations = 0
        self.user_generation_history = defaultdict(list)  # Track recent generations per user
        self.lock = threading.Lock()

        # DDOS protection only - very high limits
        self.ddos_limits = {
            'requests_per_minute': 200,  # Only to prevent abuse
            'requests_per_hour': 1000,   # Only to prevent abuse
        }

    def can_generate(self, user_id):
        """Check if user can start generation based on fair resource allocation"""
        with self.lock:
            # Clean old history (older than 5 minutes)
            cutoff = datetime.now() - timedelta(minutes=5)
            self.user_generation_history[user_id] = [
                timestamp for timestamp in self.user_generation_history[user_id]
                if timestamp > cutoff
            ]

            # Server capacity check
            if self.current_active_generations >= self.max_concurrent_generations:
                return False, "Server at capacity", {
                    'current_load': self.current_active_generations,
                    'max_capacity': self.max_concurrent_generations,
                    'reason': 'server_capacity'
                }

            # Fair usage - if server is busy, limit heavy users
            recent_generations = len(self.user_generation_history[user_id])
            server_load_ratio = self.current_active_generations / self.max_concurrent_generations

            if server_load_ratio > 0.7:  # Server getting busy
                max_recent = max(3, int(10 * (1 - server_load_ratio)))
                if recent_generations >= max_recent:
                    return False, "Fair usage limit during high server load", {
                        'recent_generations': recent_generations,
                        'fair_limit': max_recent,
                        'server_load': f"{server_load_ratio:.0%}",
                        'reason': 'fair_usage'
                    }

            return True, None, {
                'server_load': f"{server_load_ratio:.0%}",
                'recent_generations': recent_generations,
                'available_slots': self.max_concurrent_generations - self.current_active_generations
            }

    def start_generation(self, user_id):
        """Mark generation as started"""
        with self.lock:
            self.current_active_generations += 1
            self.user_generation_history[user_id].append(datetime.now())

    def finish_generation(self, user_id):
        """Mark generation as finished"""
        with self.lock:
            if self.current_active_generations > 0:
                self.current_active_generations -= 1

    def get_user_status(self, user_id):
        """Get detailed status for user"""
        with self.lock:
            # Clean old history
            cutoff = datetime.now() - timedelta(minutes=5)
            self.user_generation_history[user_id] = [
                timestamp for timestamp in self.user_generation_history[user_id]
                if timestamp > cutoff
            ]

            recent_generations = len(self.user_generation_history[user_id])
            server_load_ratio = self.current_active_generations / self.max_concurrent_generations

            can_gen, reason, details = self.can_generate(user_id)

            return {
                'can_generate': can_gen,
                'reason': reason,
                'server_status': {
                    'current_load': self.current_active_generations,
                    'max_capacity': self.max_concurrent_generations,
                    'load_percentage': f"{server_load_ratio:.0%}",
                    'available_slots': self.max_concurrent_generations - self.current_active_generations
                },
                'user_status': {
                    'recent_generations_5min': recent_generations,
                    'estimated_wait_time': self._estimate_wait_time() if not can_gen else 0
                },
                'details': details
            }

    def _estimate_wait_time(self):
        """Estimate wait time in seconds"""
        if self.current_active_generations >= self.max_concurrent_generations:
            # Assume average generation takes 3 seconds
            return max(5, (self.current_active_generations - self.max_concurrent_generations + 1) * 3)
        return 0

# Initialize capacity manager
capacity_manager = ServerCapacityManager()

# Minimal DDOS protection only - no arbitrary usage limits
limiter = Limiter(
    key_func=lambda: f"ddos:{get_remote_address()}",
    default_limits=["1000 per hour", "200 per minute"],  # DDOS protection only
    storage_uri="memory://"
)
limiter.init_app(app)

# TTS API endpoint
TTS_API_URL = "http://piper-tts:8000"

# Parallel processing configuration
MAX_WORKERS = min(cpu_count(), 8)  # Use up to 8 threads, or CPU count if less
print(f"Initializing TTS Web UI with {MAX_WORKERS} worker threads")

# Security Constants
MAX_TEXT_LENGTH = 1000
ALLOWED_CHARS_PATTERN = re.compile(r'^[\w\s.,!?;:\'"()\-]+$')
TEMP_FILE_PREFIX = 'tts_secure_'

# Cache Configuration
MAX_CACHE_SIZE_BYTES = 10 * 1024 * 1024 * 1024  # 10GB
CACHE_CLEANUP_THRESHOLD = 0.8  # Cleanup when 80% full

# Cache directory - use Docker volume in production, local output for dev
CACHE_DIR = os.environ.get('CACHE_DIR', '/app/output/cache')
CACHE_ACCESS_LOG = os.path.join(CACHE_DIR, '.access_log.json')

def validate_input_text(text):
    """Validate and sanitize input text"""
    if not text or not isinstance(text, str):
        return False, "Text must be a non-empty string"

    # Length check
    if len(text) > MAX_TEXT_LENGTH:
        return False, f"Text length exceeds maximum of {MAX_TEXT_LENGTH} characters"

    # Basic character validation
    if not ALLOWED_CHARS_PATTERN.match(text):
        return False, "Text contains invalid characters. Only alphanumeric, spaces, and basic punctuation allowed"

    return True, text.strip()

def secure_temp_file(suffix='.wav'):
    """Create a secure temporary file"""
    import tempfile
    fd, path = tempfile.mkstemp(suffix=suffix, prefix=TEMP_FILE_PREFIX, dir='/tmp')
    os.close(fd)  # Close the file descriptor
    return path

def cleanup_temp_file(filepath):
    """Safely cleanup temporary file"""
    try:
        if os.path.exists(filepath) and TEMP_FILE_PREFIX in os.path.basename(filepath):
            os.unlink(filepath)
    except Exception as e:
        print(f"Warning: Could not cleanup temp file {filepath}: {e}")

def generate_cache_key(text, voice):
    """Generate a CRC32-based cache key for text+voice combination"""
    # Normalize text: lowercase, remove extra spaces, keep only letters/numbers/basic punctuation
    import re
    normalized_text = re.sub(r'\s+', ' ', text.lower().strip())
    content = f"{normalized_text}|{voice.lower()}".encode('utf-8')
    crc = hashlib.md5(content).hexdigest()[:8]
    return crc

def load_access_log():
    """Load cache access tracking data"""
    try:
        if os.path.exists(CACHE_ACCESS_LOG):
            with open(CACHE_ACCESS_LOG, 'r') as f:
                return json.load(f)
    except Exception as e:
        print(f"Warning: Could not load access log: {e}")
    return {}

def save_access_log(access_data):
    """Save cache access tracking data"""
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(CACHE_ACCESS_LOG, 'w') as f:
            json.dump(access_data, f, indent=2)
    except Exception as e:
        print(f"Warning: Could not save access log: {e}")

def track_cache_access(cache_key, format):
    """Track cache file access for smart cleanup"""
    try:
        access_data = load_access_log()
        filename = f"{cache_key}.{format}"
        current_time = time.time()

        if filename not in access_data:
            access_data[filename] = {
                "access_count": 0,
                "first_access": current_time,
                "last_access": current_time
            }

        access_data[filename]["access_count"] += 1
        access_data[filename]["last_access"] = current_time

        save_access_log(access_data)
    except Exception as e:
        print(f"Warning: Could not track cache access: {e}")

def get_cached_file(cache_key, format):
    """Check if cached file exists and track access"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    cached_file = os.path.join(CACHE_DIR, f"{cache_key}.{format}")
    if os.path.exists(cached_file):
        track_cache_access(cache_key, format)
        return cached_file
    return None

def get_cache_size(cache_dir=None):
    """Calculate total cache directory size in bytes (excluding access log)"""
    if cache_dir is None:
        cache_dir = CACHE_DIR
    total_size = 0
    try:
        for dirpath, dirnames, filenames in os.walk(cache_dir):
            for filename in filenames:
                # Skip the access log file
                if filename.startswith('.access_log'):
                    continue
                filepath = os.path.join(dirpath, filename)
                if os.path.exists(filepath):
                    total_size += os.path.getsize(filepath)
    except OSError:
        pass
    return total_size

def cleanup_old_cache_files(cache_dir, target_size):
    """Remove least used + oldest cache files until we're under target_size"""
    try:
        access_data = load_access_log()
        current_time = time.time()

        # Get all cache files with their stats
        cache_files = []
        for filename in os.listdir(cache_dir):
            # Skip access log and non-audio files
            if filename.startswith('.access_log') or not (filename.endswith('.wav') or filename.endswith('.mp3')):
                continue

            filepath = os.path.join(cache_dir, filename)
            if not os.path.isfile(filepath):
                continue

            mtime = os.path.getmtime(filepath)
            size = os.path.getsize(filepath)

            # Get access stats
            file_access = access_data.get(filename, {
                "access_count": 1,  # Default to 1 if not tracked
                "last_access": mtime,
                "first_access": mtime
            })

            # Calculate smart priority score (lower = more likely to be removed)
            # Factors: access frequency, recency, and age
            access_count = file_access["access_count"]
            last_access = file_access["last_access"]
            days_since_access = (current_time - last_access) / 86400  # Convert to days
            days_old = (current_time - mtime) / 86400

            # Priority score: lower values get removed first
            # Heavy penalty for not being accessed recently, bonus for frequent access
            priority_score = (days_since_access * 2) + days_old - (access_count * 0.5)

            cache_files.append((priority_score, filepath, filename, size, access_count, days_since_access))

        # Sort by priority score (lowest first = least valuable files first)
        cache_files.sort()

        # Remove files until we're under target size
        current_size = sum(size for _, _, _, size, _, _ in cache_files)
        removed_count = 0
        removed_size = 0

        for priority_score, filepath, filename, size, access_count, days_since_access in cache_files:
            if current_size <= target_size:
                break
            try:
                os.unlink(filepath)
                current_size -= size
                removed_size += size
                removed_count += 1

                # Remove from access log
                if filename in access_data:
                    del access_data[filename]

                print(f"Removed cache file: {filename} (access: {access_count}x, {days_since_access:.1f}d ago, {size} bytes)")
            except OSError as e:
                print(f"Warning: Could not remove cache file {filepath}: {e}")

        if removed_count > 0:
            print(f"Smart cache cleanup: removed {removed_count} files ({removed_size / 1024 / 1024:.1f}MB)")
            save_access_log(access_data)  # Save updated access log

    except Exception as e:
        print(f"Warning: Cache cleanup failed: {e}")

def save_to_cache(cache_key, format, content):
    """Save audio content to cache with size management"""
    os.makedirs(CACHE_DIR, exist_ok=True)

    # Check cache size and cleanup if needed
    current_size = get_cache_size()
    content_size = len(content)

    # If adding this file would exceed the limit, cleanup first
    if current_size + content_size > MAX_CACHE_SIZE_BYTES:
        target_size = int(MAX_CACHE_SIZE_BYTES * CACHE_CLEANUP_THRESHOLD) - content_size
        print(f"Cache size ({current_size / 1024 / 1024:.1f}MB) approaching limit, cleaning up...")
        cleanup_old_cache_files(CACHE_DIR, max(0, target_size))

    # Save the new file
    cached_file = os.path.join(CACHE_DIR, f"{cache_key}.{format}")
    with open(cached_file, 'wb') as f:
        f.write(content)

    # Track initial access
    track_cache_access(cache_key, format)

    return cached_file

def get_voices_data():
    """Get voices data as dict"""
    try:
        with open('/app/config/voice_to_speaker.yaml', 'r') as f:
            voices = yaml.safe_load(f)
        return voices
    except:
        return {
            "alloy": "en_US-lessac-medium",
            "echo": "en_US-danny-low",
            "fable": "en_GB-alan-medium",
            "onyx": "en_US-ryan-medium",
            "nova": "en_US-amy-medium",
            "shimmer": "en_US-lessac-medium"
        }

def generate_single_voice(voice_name, text, format, user_id=None):
    """Generate speech for a single voice - used for parallel processing"""
    try:
        cache_key = generate_cache_key(text, voice_name)

        # Check cache first
        cached_file = get_cached_file(cache_key, format)
        if cached_file:
            filename = f"{voice_name}_{cache_key}.{format}"
            temp_filepath = os.path.join(tempfile.gettempdir(), filename)
            with open(cached_file, 'rb') as src, open(temp_filepath, 'wb') as dst:
                dst.write(src.read())

            return {
                "voice": voice_name,
                "success": True,
                "filename": filename,
                "size": os.path.getsize(cached_file),
                "cached": True
            }

        # Mark generation as started if user_id provided
        if user_id:
            capacity_manager.start_generation(user_id)

        try:
            # Generate new audio
            response = requests.post(
                f"{TTS_API_URL}/generate",
                json={
                    "text": text,
                    "voice": voice_name,
                    "format": format
                },
                timeout=30
            )
        except Exception as e:
            if user_id:
                capacity_manager.finish_generation(user_id)
            raise e

        if response.status_code == 200:
            # Save to cache
            cached_filepath = save_to_cache(cache_key, format, response.content)

            # Save the audio file for download
            filename = f"{voice_name}_{cache_key}.{format}"
            filepath = os.path.join(tempfile.gettempdir(), filename)

            with open(filepath, 'wb') as f:
                f.write(response.content)

            return {
                "voice": voice_name,
                "success": True,
                "filename": filename,
                "size": len(response.content),
                "cached": False
            }
        else:
            return {
                "voice": voice_name,
                "success": False,
                "error": f"TTS API error: {response.status_code}"
            }

    except Exception as e:
        return {
            "voice": voice_name,
            "success": False,
            "error": str(e)
        }
    finally:
        # Mark generation as finished for user
        if user_id:
            capacity_manager.finish_generation(user_id)
            job_manager.finish_job(user_id)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/voices')
def get_voices():
    """Get available voices"""
    try:
        with open('/app/config/voice_to_speaker.yaml', 'r') as f:
            voices = yaml.safe_load(f)
        return jsonify(voices)
    except:
        return jsonify({
            "alloy": "en_US-lessac-medium",
            "echo": "en_US-danny-low",
            "fable": "en_GB-alan-medium",
            "onyx": "en_US-ryan-medium",
            "nova": "en_US-amy-medium",
            "shimmer": "en_US-lessac-medium"
        })

@app.route('/api/generate', methods=['POST'])
@limiter.limit("200 per minute")  # DDOS protection only
def generate_speech():
    """Generate speech using the TTS API"""
    try:
        user_info = get_user_info()
        user_id = user_info['user_id']
        data = request.json or {}
        text = data.get('text', '')
        voice = data.get('voice', 'alloy')
        format = data.get('format', 'mp3')

        # Input validation
        is_valid, validated_text = validate_input_text(text)
        if not is_valid:
            return jsonify({"success": False, "error": validated_text}), 400

        # Voice validation
        voices_data = get_voices_data()
        if voice not in voices_data:
            return jsonify({"success": False, "error": "Invalid voice selection"}), 400

        text = validated_text

        # Server capacity check
        can_generate, reason, details = capacity_manager.can_generate(user_id)
        if not can_generate:
            status = capacity_manager.get_user_status(user_id)
            return jsonify({
                "success": False,
                "error": reason,
                "rate_limit_info": status,
                "retry_after": status['user_status']['estimated_wait_time']
            }), 429

        # Generate cache key
        cache_key = generate_cache_key(text, voice)

        # Check cache first
        cached_file = get_cached_file(cache_key, format)
        if cached_file:
            filename = f"{voice}_{cache_key}.{format}"
            # Copy cached file to temp location for download
            temp_filepath = os.path.join(tempfile.gettempdir(), filename)
            with open(cached_file, 'rb') as src, open(temp_filepath, 'wb') as dst:
                dst.write(src.read())

            # Get current status for user info
            status = capacity_manager.get_user_status(user_id)

            return jsonify({
                "success": True,
                "filename": filename,
                "size": os.path.getsize(cached_file),
                "cached": True,
                "server_info": status
            })

        # Call the TTS API
        response = requests.post(
            f"{TTS_API_URL}/generate",
            json={
                "text": text,
                "voice": voice,
                "format": format
            },
            timeout=30
        )

        if response.status_code == 200:
            # Save the audio file
            # Save to cache
            cached_filepath = save_to_cache(cache_key, format, response.content)

            # Save the audio file for download
            filename = f"{voice}_{cache_key}.{format}"
            filepath = os.path.join(tempfile.gettempdir(), filename)

            with open(filepath, 'wb') as f:
                f.write(response.content)

            # Get current status for user info
            status = capacity_manager.get_user_status(user_id)

            return jsonify({
                "success": True,
                "filename": filename,
                "size": len(response.content),
                "cached": False,
                "server_info": status
            })
        else:
            return jsonify({
                "success": False,
                "error": f"TTS API error: {response.status_code}"
            }), 400

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/generate-all', methods=['POST'])
@limiter.limit("10 per hour")  # Reasonable for batch operations
def generate_all_voices():
    """Generate speech with all available voices using parallel processing"""
    try:
        data = request.json or {}
        text = data.get('text', '')
        format = data.get('format', 'mp3')

        # Input validation
        is_valid, validated_text = validate_input_text(text)
        if not is_valid:
            return jsonify({"success": False, "error": validated_text}), 400

        text = validated_text

        # Get available voices
        voices = get_voices_data()
        voice_names = list(voices.keys())

        print(f"Starting parallel batch generation for {len(voice_names)} voices using {MAX_WORKERS} workers")
        start_time = time.time()

        # Use ThreadPoolExecutor for parallel processing
        with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            # Submit all tasks
            future_to_voice = {
                executor.submit(generate_single_voice, voice_name, text, format): voice_name
                for voice_name in voice_names
            }

            results = []
            for future in concurrent.futures.as_completed(future_to_voice):
                voice_name = future_to_voice[future]
                try:
                    result = future.result()
                    results.append(result)
                    print(f"Completed {voice_name}: {'cached' if result.get('cached') else 'generated'}")
                except Exception as exc:
                    print(f"Voice {voice_name} generated an exception: {exc}")
                    results.append({
                        "voice": voice_name,
                        "success": False,
                        "error": str(exc)
                    })

        elapsed_time = time.time() - start_time
        successful = len([r for r in results if r["success"]])
        cached_count = len([r for r in results if r.get("cached")])

        print(f"Batch generation completed in {elapsed_time:.2f}s: {successful}/{len(voice_names)} successful, {cached_count} cached")

        return jsonify({
            "success": True,
            "results": results,
            "total": len(voice_names),
            "successful": successful,
            "cached": cached_count,
            "elapsed_time": elapsed_time,
            "workers_used": MAX_WORKERS
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/download/<filename>')
@limiter.limit("30 per minute")
def download_file(filename):
    """Download generated audio file with optional format conversion"""
    try:
        # Validate filename
        safe_filename = secure_filename(filename)
        if not safe_filename or not safe_filename.endswith(('.wav', '.mp3')):
            return jsonify({"error": "Invalid filename"}), 400

        # Validate format parameter
        format_param = request.args.get('format', 'wav').lower()
        if format_param not in ['wav', 'mp3']:
            return jsonify({"error": "Invalid format parameter"}), 400

        filepath = os.path.join(tempfile.gettempdir(), safe_filename)

        # Ensure file is within temp directory (path traversal protection)
        real_temp_dir = os.path.realpath(tempfile.gettempdir())
        real_file_path = os.path.realpath(filepath)
        if not real_file_path.startswith(real_temp_dir):
            return jsonify({"error": "Access denied"}), 403

        if not os.path.exists(filepath):
            return jsonify({"error": "File not found"}), 404

        # If requesting MP3 conversion from WAV
        if format_param == 'mp3' and filename.endswith('.wav'):
            import subprocess
            mp3_filename = filename.replace('.wav', '.mp3')
            mp3_filepath = os.path.join(tempfile.gettempdir(), mp3_filename)

            # Convert WAV to MP3 using ffmpeg
            try:
                subprocess.run([
                    'ffmpeg', '-y', '-i', filepath,
                    '-acodec', 'libmp3lame', '-ab', '128k',
                    mp3_filepath
                ], check=True, capture_output=True)

                return send_file(mp3_filepath, as_attachment=True, download_name=mp3_filename)
            except subprocess.CalledProcessError:
                # Fall back to WAV if conversion fails
                return send_file(filepath, as_attachment=True)
        else:
            return send_file(filepath, as_attachment=True)

    except Exception as e:
        return f"Error processing download: {str(e)}", 500

@app.route('/api/status')
def get_status():
    """Check TTS server status"""
    try:
        response = requests.get(f"{TTS_API_URL}/health", timeout=5)

        # Add cache status
        cache_size = get_cache_size()
        cache_files_count = 0
        access_data = load_access_log()
        try:
            cache_files_count = len([f for f in os.listdir(CACHE_DIR)
                                   if f.endswith('.wav') or f.endswith('.mp3')])
        except OSError:
            pass

        # Get user's current rate limit status
        user_info = get_user_info()
        user_id = user_info['user_id']
        user_status = capacity_manager.get_user_status(user_id)

        return jsonify({
            "status": "online" if response.status_code == 200 else "offline",
            "url": TTS_API_URL,
            "user_session": user_id,
            "rate_limit_info": user_status,
            "cache": {
                "size_bytes": cache_size,
                "size_mb": round(cache_size / 1024 / 1024, 2),
                "max_size_gb": MAX_CACHE_SIZE_BYTES / 1024 / 1024 / 1024,
                "usage_percent": round((cache_size / MAX_CACHE_SIZE_BYTES) * 100, 2),
                "files_count": cache_files_count,
                "directory": CACHE_DIR,
                "total_accesses": sum(data.get("access_count", 0) for data in access_data.values()),
                "tracked_files": len(access_data)
            }
        })
    except:
        return jsonify({
            "status": "offline",
            "url": TTS_API_URL,
            "cache": {"error": "Could not get cache status"}
        })

@app.route('/api/cache/cleanup', methods=['POST'])
@limiter.limit("5 per minute")
def cleanup_cache():
    """Manually cleanup cache to target size"""
    try:
        data = request.json or {}
        target_percent = data.get('target_percent', CACHE_CLEANUP_THRESHOLD * 100)
        target_percent = max(0, min(100, target_percent))  # Clamp to 0-100%

        current_size = get_cache_size()
        target_size = int((target_percent / 100) * MAX_CACHE_SIZE_BYTES)

        if current_size <= target_size:
            return jsonify({
                "success": True,
                "message": "Cache already within target size",
                "current_size_mb": round(current_size / 1024 / 1024, 2),
                "target_size_mb": round(target_size / 1024 / 1024, 2)
            })

        # Perform cleanup
        cleanup_old_cache_files(CACHE_DIR, target_size)
        new_size = get_cache_size()

        return jsonify({
            "success": True,
            "message": "Cache cleanup completed",
            "old_size_mb": round(current_size / 1024 / 1024, 2),
            "new_size_mb": round(new_size / 1024 / 1024, 2),
            "freed_mb": round((current_size - new_size) / 1024 / 1024, 2),
            "target_percent": target_percent
        })

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=True)
