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

