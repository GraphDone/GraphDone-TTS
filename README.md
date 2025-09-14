# GraphDone-TTS

A high-performance, production-ready text-to-speech server built with [Piper-TTS](https://github.com/rhasspy/piper), providing OpenAI-compatible API endpoints for GraphDone applications.

## 🚀 Features

- **OpenAI-Compatible API**: Drop-in replacement for OpenAI's TTS endpoints
- **High Performance**: Built with FastAPI and optimized for speed
- **Multiple Voices**: Support for 6+ voices with multiple quality levels
- **Web Interface**: Interactive UI for testing and configuration
- **Smart Caching**: Intelligent LRU+LFU cache system with 10GB limit
- **Docker Ready**: Single or multi-container deployment options
- **Format Support**: MP3, WAV, OPUS, AAC, FLAC, PCM output formats
- **Rate Limiting**: Built-in protection against abuse
- **Batch Processing**: Generate multiple voices in parallel

## 📁 Project Structure

```
GraphDone-TTS/
├── src/                      # Source code
│   ├── piper-server/        # FastAPI TTS server
│   └── webui/               # Flask web interface
├── docker/                   # Docker configurations
│   ├── Dockerfile.single    # Single container build
│   └── docker-compose.*.yml # Compose configurations
├── scripts/                  # Automation scripts
│   ├── setup_tts.sh         # Basic setup
│   ├── setup_tts_with_ui.sh # Full setup with UI
│   └── download_voices.sh   # Voice model downloader
├── config/                   # Configuration files
│   ├── voice_to_speaker.yaml
│   └── pre_process_map.yaml
├── voices/                   # ONNX voice models
├── tests/                    # Test files and scripts
├── docs/                     # Documentation
└── examples/                 # Usage examples
```

## 🔧 Installation

### Quick Start (Recommended)

```bash
# Clone the repository
git clone https://github.com/graphdone/GraphDone-TTS.git
cd GraphDone-TTS

# Just run start - it handles everything automatically!
./start
```

That's it! The `./start` script will:
- ✅ Install Docker if needed
- ✅ Download voice models
- ✅ Build containers
- ✅ Start all services
- ✅ Show you the URLs

### Management Commands

```bash
./start          # Start everything (auto-setup)
./start stop     # Stop all services
./start restart  # Restart services
./start logs     # View logs
./start status   # Check status
./start clean    # Clean up everything
```

## 📖 API Usage

### Generate Speech

```bash
curl -X POST "http://localhost:8000/v1/audio/speech" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tts-1",
    "input": "Hello, this is GraphDone TTS!",
    "voice": "nova",
    "response_format": "mp3"
  }' \
  --output speech.mp3
```

### Available Voices
- `alloy` - Neutral, professional
- `echo` - Warm, conversational
- `fable` - Expressive, narrative
- `onyx` - Deep, authoritative
- `nova` - Energetic, youthful
- `shimmer` - Gentle, soothing

### Supported Formats
- `mp3` - Default, compressed audio
- `wav` - Uncompressed, high quality
- `opus` - Efficient compression
- `aac` - Apple-compatible
- `flac` - Lossless compression
- `pcm` - Raw audio data

## 🖥️ Web Interface

Access the web UI at `http://localhost:3000`

Features:
- Test different voices and settings
- Batch generation for multiple voices
- Real-time audio playback
- Cache management dashboard
- API endpoint testing

## 🐳 Docker Deployment

### Build Custom Image

```bash
# Build complete image with all voices
./scripts/package_single.sh

# Run the container
docker run -d -p 8000:8000 -p 3000:3000 \
  --name graphdone-tts \
  tts-server-complete:latest
```

### Docker Compose Options

```bash
# Development (multi-container)
docker-compose -f docker/docker-compose.yml up

# Production (single container)
docker-compose -f docker/docker-compose.single.yml up
```

## ⚙️ Configuration

### Voice Configuration
Edit `config/voice_to_speaker.yaml` to customize voice mappings:

```yaml
nova:
  low: en_US-amy-low
  medium: en_US-amy-medium
  high: en_US-amy-medium
  x_low: en_US-amy-low
```

### Text Preprocessing
Customize text processing in `config/pre_process_map.yaml`:

```yaml
abbreviations:
  "Mr.": "Mister"
  "Dr.": "Doctor"
```

### Environment Variables

```bash
# Cache settings
CACHE_DIR=/app/output/cache
MAX_CACHE_SIZE_GB=10

# API configuration
TTS_API_URL=http://localhost:8000
SECRET_KEY=your-secret-key

# Performance
MAX_WORKERS=8
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
./start test

# Test specific component
./tests/test_tts.sh

# Manual API test
curl http://localhost:8000/health
```

## 📊 Performance

- **Response Time**: < 500ms for cached content
- **Generation Speed**: 2-5 seconds for new content
- **Concurrent Requests**: Handles 100+ simultaneous requests
- **Cache Hit Rate**: 70%+ in production
- **Memory Usage**: < 2GB under normal load

## 🔒 Security

- Input validation and sanitization
- Rate limiting on all endpoints
- Path traversal protection
- Non-root container execution
- Secure file handling

## 📚 Documentation

- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Security Guide](docs/SECURITY.md)
- [Development Guide](docs/DEVELOPMENT.md)

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

### Third-Party Licenses

- **Piper-TTS**: MIT License - [github.com/rhasspy/piper](https://github.com/rhasspy/piper)
- **OpenAI API Specification**: MIT License

## 🙏 Acknowledgments

- Built with [Piper-TTS](https://github.com/rhasspy/piper) - A fast, local neural text-to-speech system (MIT License)
- Piper-TTS models and voice synthesis technology by Michael Hansen
- OpenAI API compatibility for seamless integration
- GraphDone team for project support

## 📞 Support

For issues and questions:
- GitHub Issues: [GraphDone-TTS/issues](https://github.com/graphdone/GraphDone-TTS/issues)
- Documentation: [docs/](docs/)

---
Made with ❤️ by the GraphDone Team