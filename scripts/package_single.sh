#!/bin/bash

echo "🏗️  Packaging TTS Server as Single Docker Image..."

# Stop existing containers if running
echo "Stopping any running containers..."
docker compose down >/dev/null 2>&1

# Download all voices if not present
if [ ! -d "voices" ] || [ "$(ls -A voices 2>/dev/null | wc -l)" -lt "10" ]; then
    echo "📥 Downloading voice models..."
    ./scripts/download_voices.sh
fi

# Build the single container image
echo "🔨 Building single Docker image with all voices..."
docker build -f docker/Dockerfile.single -t tts-server-complete:latest .

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "📦 Package Information:"
    echo "   Image: tts-server-complete:latest"
    echo "   Size: $(docker images tts-server-complete:latest --format 'table {{.Size}}' | tail -1)"
    echo ""
    echo "🚀 Usage Options:"
    echo ""
    echo "1. BRIDGE MODE (Recommended - Secure, isolated network):"
    echo "   docker run -d -p 8000:8000 -p 3000:3000 --name tts-server tts-server-complete:latest"
    echo ""
    echo "2. HOST MODE (Direct network access - less secure but simpler):"
    echo "   docker run -d --network host --name tts-server tts-server-complete:latest"
    echo ""
    echo "3. Docker Compose (Bridge mode):"
    echo "   docker compose -f docker-compose.single.yml up -d"
    echo ""
    echo "4. Docker Compose (Host mode):"
    echo "   Edit docker-compose.single.yml and uncomment 'network_mode: host', then:"
    echo "   docker compose -f docker-compose.single.yml up -d"
    echo ""
    echo "🌐 Access Points:"
    echo "   - Web UI: http://localhost:3000"
    echo "   - API: http://localhost:8000"
    echo "   - API Docs: http://localhost:8000/docs"
    echo ""
    echo "🎭 Available Voices:"
    echo "   $(cat config/voice_to_speaker.yaml | grep -E '^[a-z]' | wc -l) voices with multiple quality levels"
    echo "   - High Quality: ljspeech_high"
    echo "   - Medium Quality: amy_medium, lessac_medium, ryan_medium, etc."
    echo "   - Low Quality (Faster): amy_low, lessac_low, ryan_low, danny_low, etc."
    echo "   - International: French, German, Spanish, Italian"
    echo ""
else
    echo "❌ Build failed!"
    exit 1
fi