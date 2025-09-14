#!/usr/bin/env python3
"""
FastAPI PiperTTS Server
Direct integration with PiperTTS
"""

import os
import subprocess
import tempfile
import yaml
import re
import secrets
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from pydantic import BaseModel, validator
from typing import Dict
import logging
import uvicorn

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="PiperTTS Server", description="Native PiperTTS API Server", version="1.0.0")

# Security Configuration
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Only allow our web UI
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

VOICES_DIR = "/app/voices"
CONFIG_DIR = "/app/config"

# Security Constants
MAX_TEXT_LENGTH = 1000
ALLOWED_CHARS_PATTERN = re.compile(r'^[\w\s.,!?;:\'"()\-åäöáéíóúàèìòùâêîôûãõç]+$', re.UNICODE)
TEMP_FILE_PREFIX = 'piper_secure_'

# Pydantic models
class TTSRequest(BaseModel):
    text: str
    voice: str = "amy"
    format: str = "wav"

    @validator('text')
    def validate_text(cls, v):
        if not v or not isinstance(v, str):
            raise ValueError("Text must be a non-empty string")

        if len(v) > MAX_TEXT_LENGTH:
            raise ValueError(f"Text length exceeds maximum of {MAX_TEXT_LENGTH} characters")

        if not ALLOWED_CHARS_PATTERN.match(v):
            raise ValueError("Text contains invalid characters")

        return v.strip()

    @validator('format')
    def validate_format(cls, v):
        if v.lower() not in ['wav', 'mp3']:
            raise ValueError("Format must be 'wav' or 'mp3'")
        return v.lower()

def get_voice_mapping():
    """Load voice to model mapping from config"""
    try:
        with open(os.path.join(CONFIG_DIR, "voice_to_speaker.yaml"), 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Error loading voice mapping: {e}")
        return {}

def install_piper():
    """Install PiperTTS binary"""
    try:
        # Check if piper is already installed
        result = subprocess.run(["piper", "--version"], capture_output=True, text=True)
        if result.returncode == 0:
            logger.info(f"Piper already installed: {result.stdout.strip()}")
            return True
    except FileNotFoundError:
        pass

    logger.info("Installing PiperTTS...")
    try:
        # Install piper-tts
        subprocess.run(["pip", "install", "piper-tts"], check=True)
        logger.info("PiperTTS installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to install PiperTTS: {e}")
        return False

@app.get("/")
def root():
    return {"message": "PiperTTS Server", "docs": "/docs", "voices": "/voices"}

@app.get("/health")
@limiter.limit("30/minute")
def health(request: Request):
    return {"status": "healthy", "service": "PiperTTS"}

@app.get("/voices")
@limiter.limit("10/minute")
def list_voices(request: Request) -> Dict:
    """List available voices"""
    return get_voice_mapping()

@app.post("/generate")
@limiter.limit("10/minute")
def generate_speech(request: Request, tts_request: TTSRequest):
    """Generate speech using PiperTTS - always stores as WAV"""
    try:
        text = tts_request.text
        voice = tts_request.voice
        format = tts_request.format.lower()

        if not text:
            raise HTTPException(status_code=400, detail="No text provided")

        # Get voice model mapping
        voice_mapping = get_voice_mapping()
        if voice not in voice_mapping:
            raise HTTPException(status_code=400, detail=f"Voice '{voice}' not found. Available: {list(voice_mapping.keys())}")

        model_name = voice_mapping[voice]
        model_path = os.path.join(VOICES_DIR, f"{model_name}.onnx")

        if not os.path.exists(model_path):
            raise HTTPException(status_code=400, detail=f"Voice model file not found: {model_path}")

        # Always create WAV file - conversion happens on download
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_wav:
            wav_path = tmp_wav.name

        # Run PiperTTS
        cmd = [
            "piper",
            "--model", model_path,
            "--output_file", wav_path
        ]

        logger.info(f"Running PiperTTS: {voice} -> {model_name}")

        process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        stdout, stderr = process.communicate(input=text)

        if process.returncode != 0:
            logger.error(f"PiperTTS failed: {stderr}")
            os.unlink(wav_path)
            raise HTTPException(status_code=500, detail=f"PiperTTS error: {stderr}")

        if not os.path.exists(wav_path):
            raise HTTPException(status_code=500, detail="Failed to generate audio file")

        # Return WAV file info but indicate the requested format for later conversion
        return FileResponse(wav_path, media_type="audio/wav", filename=f"speech.wav",
                          headers={"X-Requested-Format": format})

    except Exception as e:
        logger.error(f"Error in generate_speech: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/download/{filename}")
def download_with_conversion(filename: str, format: str = "wav"):
    """Download file with optional format conversion"""
    try:
        # Find the source file (should be WAV)
        file_pattern = filename.replace('.wav', '').replace('.mp3', '')
        wav_file = None

        # Look for the WAV file in temp directory
        import glob
        temp_files = glob.glob(os.path.join(tempfile.gettempdir(), f"{file_pattern}*.wav"))
        if temp_files:
            wav_file = temp_files[0]
        else:
            raise HTTPException(status_code=404, detail="Source audio file not found")

        if not os.path.exists(wav_file):
            raise HTTPException(status_code=404, detail="Audio file not found")

        format = format.lower()

        # If requesting MP3, convert on-the-fly
        if format == "mp3":
            with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp_mp3:
                mp3_path = tmp_mp3.name

            # Convert WAV to MP3 using ffmpeg
            convert_cmd = [
                "ffmpeg", "-y", "-i", wav_file,
                "-acodec", "libmp3lame", "-ab", "128k",
                mp3_path
            ]

            convert_process = subprocess.run(
                convert_cmd,
                capture_output=True,
                text=True
            )

            if convert_process.returncode != 0:
                logger.error(f"MP3 conversion failed: {convert_process.stderr}")
                raise HTTPException(status_code=500, detail="MP3 conversion failed")

            return FileResponse(mp3_path, media_type="audio/mp3", filename=filename.replace('.wav', '.mp3'))
        else:
            # Return WAV file directly
            return FileResponse(wav_file, media_type="audio/wav", filename=filename)

    except Exception as e:
        logger.error(f"Error in download_with_conversion: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == '__main__':
    logger.info("Starting PiperTTS server...")

    # Install PiperTTS if needed
    if not install_piper():
        logger.error("Failed to install PiperTTS")
        exit(1)

    # Create required directories
    os.makedirs(VOICES_DIR, exist_ok=True)
    os.makedirs(CONFIG_DIR, exist_ok=True)

    logger.info(f"Voices directory: {VOICES_DIR}")
    logger.info(f"Config directory: {CONFIG_DIR}")

    # List available voices
    voices = get_voice_mapping()
    logger.info(f"Available voices: {list(voices.keys())}")

    # Start server
    uvicorn.run(app, host="0.0.0.0", port=8000)