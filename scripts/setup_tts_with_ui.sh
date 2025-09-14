#!/bin/bash

set -e

echo "🎙️  Setting up Native PiperTTS Server with Web UI"
echo "===================================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Installing Docker via snap..."

    # Install Docker using snap
    echo "🔧 Installing Docker with snap..."
    sudo snap install docker

    # Setup docker socket permissions
    echo "🔧 Setting up Docker socket permissions..."
    sudo systemctl start snap.docker.dockerd.service
    sudo systemctl enable snap.docker.dockerd.service

    # Add user to docker group (for snap docker)
    sudo addgroup --system docker
    sudo adduser $USER docker

    # Setup socket permissions
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

    echo "✅ Docker installed successfully"
    echo "⚠️  You may need to log out and log back in for Docker group permissions to take effect"
    echo "⚠️  Or run: newgrp docker"

    # Wait for Docker to initialize
    sleep 10
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Attempting to start..."

    # Try to start docker service (snap version)
    sudo systemctl start snap.docker.dockerd.service 2>/dev/null || true

    # Also try traditional docker service
    sudo systemctl start docker 2>/dev/null || true

    # Fix socket permissions
    sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

    sleep 5

    if ! docker info &> /dev/null; then
        echo "❌ Docker is still not accessible. Trying to fix permissions..."

        # Create docker group if it doesn't exist and add user
        sudo groupadd docker 2>/dev/null || true
        sudo usermod -aG docker $USER

        # Set socket permissions
        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

        sleep 3

        if ! docker info &> /dev/null; then
            echo "❌ Please run the following commands manually and then rerun this script:"
            echo "  sudo systemctl start snap.docker.dockerd.service"
            echo "  sudo chmod 666 /var/run/docker.sock"
            echo "  newgrp docker"
            exit 1
        fi
    fi
fi

echo "✅ Docker is installed and running"

# Create directory for TTS server
TTS_DIR="$HOME/tts-server-ui"
mkdir -p "$TTS_DIR"
cd "$TTS_DIR"

echo "📁 Created directory: $TTS_DIR"

# Create docker-compose.yml with both TTS server and web UI
cat > docker-compose.yml << 'EOF'
services:
  openedai-speech:
    image: ghcr.io/matatonic/openedai-speech-min
    container_name: openedai-speech
    ports:
      - "8000:8000"
    volumes:
      - ./voices:/app/voices
      - ./config:/app/config
    environment:
      - TTS_HOME=/app/voices
      - HF_HOME=/app/voices
    command: ["python", "-m", "speech", "--host", "0.0.0.0", "--port", "8000", "--xtts_device", "none"]
    restart: unless-stopped

  tts-webui:
    image: python:3.11-slim
    container_name: tts-webui
    ports:
      - "3000:3000"
    volumes:
      - ./webui:/app
      - ./voices:/app/voices
      - ./config:/app/config
    working_dir: /app
    command: ["python", "app.py"]
    depends_on:
      - openedai-speech
    restart: unless-stopped

EOF

echo "📝 Created docker-compose.yml"

# Create config directory and voice mapping
mkdir -p config voices webui

cat > config/voice_to_speaker.yaml << 'EOF'
# Voice to speaker mapping for PiperTTS
# Format: voice_name: speaker_model_path

alloy: en_US-lessac-medium
echo: en_US-danny-low
fable: en_GB-alan-medium
onyx: en_US-ryan-medium
nova: en_US-amy-medium
shimmer: en_US-lessac-medium

EOF

echo "📝 Created voice configuration"

# Create the web UI
cat > webui/app.py << 'EOF'
import os
import json
import requests
from flask import Flask, render_template, request, jsonify, send_file, redirect, url_for
from werkzeug.utils import secure_filename
import tempfile
import yaml

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = '/app/voices'

# TTS API endpoint
TTS_API_URL = "http://openedai-speech:8000"

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
def generate_speech():
    """Generate speech using the TTS API"""
    try:
        data = request.json
        text = data.get('text', '')
        voice = data.get('voice', 'alloy')
        format = data.get('format', 'mp3')

        # Call the TTS API
        response = requests.post(
            f"{TTS_API_URL}/v1/audio/speech",
            json={
                "model": "tts-1",
                "input": text,
                "voice": voice,
                "response_format": format
            },
            timeout=30
        )

        if response.status_code == 200:
            # Save the audio file
            filename = f"generated_{voice}_{len(text)[:10]}.{format}"
            filepath = os.path.join(tempfile.gettempdir(), filename)

            with open(filepath, 'wb') as f:
                f.write(response.content)

            return jsonify({
                "success": True,
                "filename": filename,
                "size": len(response.content)
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

@app.route('/api/download/<filename>')
def download_file(filename):
    """Download generated audio file"""
    filepath = os.path.join(tempfile.gettempdir(), secure_filename(filename))
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return "File not found", 404

@app.route('/api/status')
def get_status():
    """Check TTS server status"""
    try:
        response = requests.get(f"{TTS_API_URL}/docs", timeout=5)
        return jsonify({
            "status": "online" if response.status_code == 200 else "offline",
            "url": TTS_API_URL
        })
    except:
        return jsonify({
            "status": "offline",
            "url": TTS_API_URL
        })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000, debug=True)
EOF

# Create templates directory
mkdir -p webui/templates

cat > webui/templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenedAI Speech Web UI</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .status {
            padding: 20px;
            text-align: center;
            border-bottom: 1px solid #eee;
        }

        .status.online {
            background-color: #d4edda;
            color: #155724;
        }

        .status.offline {
            background-color: #f8d7da;
            color: #721c24;
        }

        .content {
            padding: 30px;
        }

        .form-group {
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }

        textarea {
            width: 100%;
            padding: 15px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            resize: vertical;
            min-height: 120px;
            transition: border-color 0.3s;
        }

        textarea:focus {
            outline: none;
            border-color: #4CAF50;
        }

        select {
            width: 100%;
            padding: 12px;
            border: 2px solid #ddd;
            border-radius: 8px;
            font-size: 16px;
            background: white;
            transition: border-color 0.3s;
        }

        select:focus {
            outline: none;
            border-color: #4CAF50;
        }

        .form-row {
            display: flex;
            gap: 15px;
        }

        .form-row .form-group {
            flex: 1;
        }

        .btn {
            background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%);
            color: white;
            padding: 15px 30px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.3s;
            width: 100%;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(76, 175, 80, 0.3);
        }

        .btn:disabled {
            background: #ccc;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .result {
            margin-top: 25px;
            padding: 20px;
            border-radius: 8px;
            display: none;
        }

        .result.success {
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
        }

        .result.error {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }

        .audio-player {
            margin-top: 15px;
            width: 100%;
        }

        .download-btn {
            margin-top: 10px;
            background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%);
            padding: 10px 20px;
            font-size: 14px;
        }

        .loading {
            display: none;
            text-align: center;
            padding: 20px;
        }

        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #4CAF50;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 2s linear infinite;
            margin: 0 auto 10px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #eee;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎙️ OpenedAI Speech</h1>
            <p>Web Interface for Text-to-Speech Generation</p>
        </div>

        <div id="status" class="status">
            <span id="status-text">Checking server status...</span>
        </div>

        <div class="content">
            <form id="tts-form">
                <div class="form-group">
                    <label for="text">Text to Speech:</label>
                    <textarea id="text" name="text" placeholder="Enter the text you want to convert to speech..." required></textarea>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label for="voice">Voice:</label>
                        <select id="voice" name="voice">
                            <option value="alloy">Alloy</option>
                            <option value="echo">Echo</option>
                            <option value="fable">Fable</option>
                            <option value="onyx">Onyx</option>
                            <option value="nova">Nova</option>
                            <option value="shimmer">Shimmer</option>
                        </select>
                    </div>

                    <div class="form-group">
                        <label for="format">Format:</label>
                        <select id="format" name="format">
                            <option value="mp3">MP3</option>
                            <option value="wav">WAV</option>
                            <option value="flac">FLAC</option>
                            <option value="opus">Opus</option>
                            <option value="aac">AAC</option>
                            <option value="pcm">PCM</option>
                        </select>
                    </div>
                </div>

                <button type="submit" class="btn" id="generate-btn">
                    🎵 Generate Speech
                </button>
            </form>

            <div class="loading" id="loading">
                <div class="spinner"></div>
                <p>Generating speech, please wait...</p>
            </div>

            <div id="result" class="result">
                <div id="result-content"></div>
            </div>
        </div>

        <div class="footer">
            <p>Powered by OpenedAI Speech | PiperTTS Backend</p>
        </div>
    </div>

    <script>
        // Check server status on load
        async function checkStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                const statusEl = document.getElementById('status');
                const statusText = document.getElementById('status-text');

                if (data.status === 'online') {
                    statusEl.className = 'status online';
                    statusText.textContent = '✅ TTS Server Online';
                } else {
                    statusEl.className = 'status offline';
                    statusText.textContent = '❌ TTS Server Offline';
                }
            } catch (error) {
                const statusEl = document.getElementById('status');
                const statusText = document.getElementById('status-text');
                statusEl.className = 'status offline';
                statusText.textContent = '❌ Connection Error';
            }
        }

        // Load available voices
        async function loadVoices() {
            try {
                const response = await fetch('/api/voices');
                const voices = await response.json();
                const voiceSelect = document.getElementById('voice');
                voiceSelect.innerHTML = '';

                for (const [name, model] of Object.entries(voices)) {
                    const option = document.createElement('option');
                    option.value = name;
                    option.textContent = name.charAt(0).toUpperCase() + name.slice(1);
                    voiceSelect.appendChild(option);
                }
            } catch (error) {
                console.error('Failed to load voices:', error);
            }
        }

        // Handle form submission
        document.getElementById('tts-form').addEventListener('submit', async function(e) {
            e.preventDefault();

            const formData = new FormData(e.target);
            const data = {
                text: formData.get('text'),
                voice: formData.get('voice'),
                format: formData.get('format')
            };

            // Show loading
            document.getElementById('loading').style.display = 'block';
            document.getElementById('result').style.display = 'none';
            document.getElementById('generate-btn').disabled = true;

            try {
                const response = await fetch('/api/generate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(data)
                });

                const result = await response.json();

                // Hide loading
                document.getElementById('loading').style.display = 'none';
                document.getElementById('generate-btn').disabled = false;

                const resultEl = document.getElementById('result');
                const resultContent = document.getElementById('result-content');

                if (result.success) {
                    resultEl.className = 'result success';
                    resultContent.innerHTML = `
                        <h3>✅ Speech Generated Successfully!</h3>
                        <p><strong>File:</strong> ${result.filename}</p>
                        <p><strong>Size:</strong> ${result.size} bytes</p>
                        <audio controls class="audio-player" src="/api/download/${result.filename}">
                            Your browser does not support the audio element.
                        </audio>
                        <br>
                        <a href="/api/download/${result.filename}" class="btn download-btn" download>
                            📥 Download Audio File
                        </a>
                    `;
                } else {
                    resultEl.className = 'result error';
                    resultContent.innerHTML = `
                        <h3>❌ Generation Failed</h3>
                        <p>${result.error}</p>
                    `;
                }

                resultEl.style.display = 'block';

            } catch (error) {
                // Hide loading
                document.getElementById('loading').style.display = 'none';
                document.getElementById('generate-btn').disabled = false;

                const resultEl = document.getElementById('result');
                const resultContent = document.getElementById('result-content');
                resultEl.className = 'result error';
                resultContent.innerHTML = `
                    <h3>❌ Network Error</h3>
                    <p>${error.message}</p>
                `;
                resultEl.style.display = 'block';
            }
        });

        // Initialize on page load
        window.addEventListener('load', function() {
            checkStatus();
            loadVoices();
        });
    </script>
</body>
</html>
EOF

# Create requirements.txt for the web UI
cat > webui/requirements.txt << 'EOF'
Flask==2.3.3
requests==2.31.0
PyYAML==6.0.1
werkzeug==2.3.7
EOF

# Update the Dockerfile to install dependencies
cat > webui/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 3000

CMD ["python", "app.py"]
EOF

# Update docker-compose to build the web UI
cat > docker-compose.yml << 'EOF'
services:
  openedai-speech:
    image: ghcr.io/matatonic/openedai-speech-min
    container_name: openedai-speech
    ports:
      - "8000:8000"
    volumes:
      - ./voices:/app/voices
      - ./config:/app/config
    environment:
      - TTS_HOME=/app/voices
      - HF_HOME=/app/voices
    command: ["python", "-m", "speech", "--host", "0.0.0.0", "--port", "8000", "--xtts_device", "none"]
    restart: unless-stopped

  tts-webui:
    build: ./webui
    container_name: tts-webui
    ports:
      - "3000:3000"
    volumes:
      - ./voices:/app/voices
      - ./config:/app/config
    depends_on:
      - openedai-speech
    restart: unless-stopped

EOF

# Create management script
cat > manage_tts_ui.sh << 'EOF'
#!/bin/bash

# Function to detect docker-compose command
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"  # fallback
    fi
}

DOCKER_COMPOSE=$(get_docker_compose_cmd)

case "$1" in
    start)
        echo "🚀 Starting TTS server with Web UI..."
        $DOCKER_COMPOSE up -d --build
        echo "📡 TTS API server: http://localhost:8000"
        echo "🌐 Web UI: http://localhost:3000"
        echo "📖 API docs: http://localhost:8000/docs"
        ;;
    stop)
        echo "🛑 Stopping TTS server and Web UI..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "🔄 Restarting TTS server and Web UI..."
        $DOCKER_COMPOSE restart
        ;;
    logs)
        echo "Which logs would you like to see? (tts/ui/all)"
        read -r choice
        case $choice in
            tts)
                $DOCKER_COMPOSE logs -f openedai-speech
                ;;
            ui)
                $DOCKER_COMPOSE logs -f tts-webui
                ;;
            *)
                $DOCKER_COMPOSE logs -f
                ;;
        esac
        ;;
    build)
        echo "🔧 Building Web UI..."
        $DOCKER_COMPOSE build tts-webui
        ;;
    status)
        $DOCKER_COMPOSE ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|build|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start TTS server and Web UI"
        echo "  stop    - Stop TTS server and Web UI"
        echo "  restart - Restart services"
        echo "  logs    - View logs (interactive)"
        echo "  build   - Rebuild Web UI container"
        echo "  status  - Show container status"
        echo ""
        echo "Access points:"
        echo "  Web UI: http://localhost:3000"
        echo "  TTS API: http://localhost:8000"
        echo "  API Docs: http://localhost:8000/docs"
        ;;
esac
EOF

chmod +x manage_tts_ui.sh

echo "📝 Created management script with Web UI"

# Create README
cat > README.md << 'EOF'
# OpenedAI Speech TTS Server with Web UI

A complete TTS solution with PiperTTS backend and a beautiful web interface for easy text-to-speech generation.

## 🚀 Quick Start

1. Start the server and Web UI:
   ```bash
   ./manage_tts_ui.sh start
   ```

2. Open your browser and go to: **http://localhost:3000**

## 🌐 Access Points

- **Web UI**: http://localhost:3000 - Easy-to-use interface
- **TTS API**: http://localhost:8000 - Direct API access
- **API Docs**: http://localhost:8000/docs - Swagger documentation

## ✨ Features

### Web UI Features:
- 🎨 Beautiful, responsive design
- 🎵 Real-time audio generation
- 🔊 Built-in audio player
- 📥 Download generated audio files
- 📊 Server status monitoring
- 🎭 Multiple voice selection
- 📄 Multiple audio format support

### Available Voices:
- Alloy, Echo, Fable, Onyx, Nova, Shimmer

### Supported Formats:
- MP3, WAV, FLAC, Opus, AAC, PCM

## 🛠️ Management Commands

```bash
./manage_tts_ui.sh start     # Start both services
./manage_tts_ui.sh stop      # Stop all services
./manage_tts_ui.sh restart   # Restart services
./manage_tts_ui.sh logs      # View logs
./manage_tts_ui.sh build     # Rebuild Web UI
./manage_tts_ui.sh status    # Check status
```

## 🔧 Configuration

Voice mappings can be customized in `config/voice_to_speaker.yaml`

## 🎯 Usage Examples

### Web UI:
1. Enter your text in the textarea
2. Select voice and format
3. Click "Generate Speech"
4. Play or download the audio

### API:
```bash
curl -X POST "http://localhost:8000/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Hello from the API!",
    "voice": "alloy",
    "response_format": "mp3"
  }' \
  --output hello.mp3
```

## 🏗️ Architecture

- **OpenedAI Speech**: PiperTTS backend server (Port 8000)
- **Web UI**: Flask-based frontend (Port 3000)
- **Docker Compose**: Container orchestration
- **Volume Mounts**: Persistent voice and config storage

Perfect for local TTS generation with a user-friendly interface!
EOF

echo "📝 Created comprehensive README"

# Pull required images
echo "⬇️  Pulling Docker images..."
docker pull ghcr.io/matatonic/openedai-speech-min
docker pull python:3.11-slim

echo ""
echo "🎉 Setup complete with Web UI!"
echo ""
echo "📂 TTS server with Web UI installed in: $TTS_DIR"
echo "🚀 To start: cd $TTS_DIR && ./manage_tts_ui.sh start"
echo ""
echo "🌐 Web UI will be available at: http://localhost:3000"
echo "📡 TTS API at: http://localhost:8000"
echo "📖 API documentation at: http://localhost:8000/docs"