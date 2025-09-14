#!/bin/bash

set -e

echo "🎙️  Setting up OpenEDAI Speech TTS Server with PiperTTS"
echo "=================================================="

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
TTS_DIR="$HOME/tts-server"
mkdir -p "$TTS_DIR"
cd "$TTS_DIR"

echo "📁 Created directory: $TTS_DIR"

# Create docker-compose.yml
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

EOF

echo "📝 Created docker-compose.yml"

# Create config directory and voice mapping
mkdir -p config voices
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

# Create simple test script
cat > test_tts.sh << 'EOF'
#!/bin/bash

echo "Testing TTS server..."

# Wait for server to be ready
echo "Waiting for server to start..."
sleep 10

# Test TTS generation
curl -X POST "http://localhost:8000/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Hello, this is a test of the TTS server!",
    "voice": "alloy",
    "response_format": "mp3"
  }' \
  --output test_output.mp3

if [ -f test_output.mp3 ]; then
    echo "✅ TTS test successful! Audio saved as test_output.mp3"
    echo "🎵 You can play it with: mpv test_output.mp3 or vlc test_output.mp3"
else
    echo "❌ TTS test failed"
fi

EOF

chmod +x test_tts.sh

echo "📝 Created test script"

# Create management script
cat > manage_tts.sh << 'EOF'
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
        echo "🚀 Starting TTS server..."
        $DOCKER_COMPOSE up -d
        echo "📡 Server starting at http://localhost:8000"
        echo "📖 API docs available at http://localhost:8000/docs"
        ;;
    stop)
        echo "🛑 Stopping TTS server..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "🔄 Restarting TTS server..."
        $DOCKER_COMPOSE restart
        ;;
    logs)
        $DOCKER_COMPOSE logs -f
        ;;
    test)
        ./test_tts.sh
        ;;
    status)
        $DOCKER_COMPOSE ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|test|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the TTS server"
        echo "  stop    - Stop the TTS server"
        echo "  restart - Restart the TTS server"
        echo "  logs    - View server logs"
        echo "  test    - Test TTS generation"
        echo "  status  - Show container status"
        ;;
esac

EOF

chmod +x manage_tts.sh

echo "📝 Created management script"

# Create README
cat > README.md << 'EOF'
# OpenEDAI Speech TTS Server

A local text-to-speech server using PiperTTS with OpenAI-compatible API.

## Quick Start

1. Start the server:
   ```bash
   ./manage_tts.sh start
   ```

2. Test the server:
   ```bash
   ./manage_tts.sh test
   ```

## Usage

### API Endpoint
- Server: http://localhost:8000
- Docs: http://localhost:8000/docs

### Example API Call
```bash
curl -X POST "http://localhost:8000/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Your text here",
    "voice": "alloy",
    "response_format": "mp3"
  }' \
  --output output.mp3
```

### Available Voices
- alloy, echo, fable, onyx, nova, shimmer

### Supported Formats
- mp3, opus, aac, flac, wav, pcm

## Management
- Start: `./manage_tts.sh start`
- Stop: `./manage_tts.sh stop`
- Logs: `./manage_tts.sh logs`
- Status: `./manage_tts.sh status`

EOF

echo "📝 Created README.md"

# Pull Docker image
echo "⬇️  Pulling Docker image..."
docker pull ghcr.io/matatonic/openedai-speech-min

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📂 TTS server installed in: $TTS_DIR"
echo "🚀 To start: cd $TTS_DIR && ./manage_tts.sh start"
echo "🧪 To test: cd $TTS_DIR && ./manage_tts.sh test"
echo "📖 View README: cd $TTS_DIR && cat README.md"
echo ""
echo "🌐 Server will be available at: http://localhost:8000"
echo "📚 API documentation at: http://localhost:8000/docs"