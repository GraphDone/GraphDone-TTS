# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Single Entry Point
```bash
# Development environment
./start dev

# Production environment
./start prod

# Run comprehensive tests
./start test

# Build containers
./start build

# View logs
./start logs

# Stop services
./start stop

# Clean up everything
./start clean
```

### Advanced Options
```bash
# Production with host networking
./start prod --host

# Build without cache
./start build --no-cache

# Custom ports
./start dev --port 8080 --api-port 9000

# Use custom volume
./start prod --volume my_tts_cache
```

### Docker Deployment Options
```bash
# Bridge mode (secure, isolated)
docker run -d -p 8000:8000 -p 3000:3000 --name tts-server tts-server-complete:latest

# Host mode (direct network access)
docker run -d --network host --name tts-server tts-server-complete:latest

# With persistent cache volume
docker run -d -p 8000:8000 -p 3000:3000 -v tts_cache:/app/output --name tts-server tts-server-complete:latest
```

### Testing System

The `./start test` command runs comprehensive end-to-end tests:

#### Test Categories
- **Service Health Checks**: Verify API and Web UI are responding
- **API Endpoint Tests**: Test all REST endpoints with validation
- **Web UI Tests**: Test frontend functionality and integration
- **Cache Tests**: Verify caching, access tracking, and cleanup
- **Batch Generation**: Test parallel processing capabilities
- **Performance Tests**: Concurrent requests and response times

#### Test Configuration
Tests are configured in `test_config.yaml` with customizable:
- Service ports and timeouts
- Test data (texts, voices, formats)
- Performance benchmarks
- Expected behaviors

#### Manual Testing
```bash
# Test individual components
curl http://localhost:8000/health
curl http://localhost:3000/api/status

# Generate speech
curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world","voice":"amy_medium","format":"wav"}'
```

## Architecture Overview

### Two-Service Architecture
- **`piper-server/`**: FastAPI backend with direct PiperTTS integration
- **`webui/`**: Flask frontend with React-style web interface

### Core Components

#### API Server (`piper-server/piper_server.py`)
- **FastAPI application** with automatic OpenAPI docs at `/docs`
- **Direct PiperTTS integration** via subprocess calls to `piper` binary
- **SlowAPI rate limiting** with endpoint-specific limits
- **Pydantic validation** for request payloads with security constraints
- **CORS middleware** configured for web UI communication
- **File serving** with WAV generation and optional MP3 conversion

#### Web UI (`webui/app.py`)
- **Flask application** with modern tabbed interface
- **Parallel processing** using ThreadPoolExecutor (up to 8 workers)
- **Smart caching system** with 10GB limit and LRU+LFU cleanup
- **Flask-Limiter rate limiting** with memory backend
- **Batch generation** endpoint for multiple voices simultaneously
- **Cache access tracking** with JSON-based analytics

### Intelligent Caching System

The cache system implements a sophisticated cleanup algorithm:

1. **Access Tracking**: JSON log stores frequency, recency, and creation time
2. **Smart Priority Scoring**: `(days_since_access × 2) + days_old - (access_count × 0.5)`
3. **Automatic Cleanup**: Triggered at 80% of 10GB limit
4. **Persistent Storage**: Uses Docker volume `/app/output` or local `./output/cache`

### Voice Management

Voice configuration is centralized in `config/voice_to_speaker.yaml`:
- **Quality levels**: `low`, `medium`, `high`, `x_low` variants
- **Multi-language support**: EN-US, EN-GB, FR, DE, ES, IT, etc.
- **Model mapping**: Voice names map to ONNX model files in `voices/`

### Security Implementation

Comprehensive security measures implemented:
- **Rate limiting** on all endpoints with service-appropriate limits
- **Input validation** with 1000-char limit and character whitelisting
- **Path traversal protection** using realpath validation
- **Container security** with non-root `tts:tts` user
- **Secure file handling** with random prefixes and cleanup

### Format Strategy

Optimized for performance:
1. **WAV-first generation**: All TTS generates WAV files
2. **On-demand MP3 conversion**: Only converts during download if requested
3. **FFmpeg integration**: Handles format conversion with 128k bitrate
4. **Cache efficiency**: Stores WAV, converts to MP3 on-the-fly

## Configuration

### Environment Variables
```bash
# Cache configuration
CACHE_DIR=/app/output/cache          # Docker: persistent volume
CACHE_DIR=./output/cache             # Local: git-ignored directory

# Service communication
TTS_API_URL=http://piper-tts:8000    # Container networking
TTS_API_URL=http://localhost:8000    # Local development

# Performance tuning
MAX_WORKERS=8                        # Parallel processing threads

# Security (production)
SECRET_KEY=your-secure-random-key
```

### File Structure
```
├── start                      # Main entry point script
├── scripts/                   # All automation scripts
│   ├── start_dev.sh          # Start development environment
│   ├── start_prod.sh         # Start production environment
│   ├── run_tests.sh          # Comprehensive test suite
│   ├── build.sh              # Build containers
│   ├── stop.sh               # Stop all services
│   ├── clean.sh              # Cleanup containers/volumes
│   └── logs.sh               # View service logs
├── piper-server/             # FastAPI TTS service
│   ├── piper_server.py       # Main server implementation
│   └── requirements.txt      # Python dependencies
├── webui/                    # Flask web interface
│   ├── app.py               # Main Flask app with caching
│   └── templates/           # Single-page HTML interface
├── config/                   # Voice and preprocessing config
│   ├── voice_to_speaker.yaml # Voice to model mapping
│   └── pre_process_map.yaml  # Text preprocessing rules
├── voices/                   # ONNX model files and JSON configs
├── docs/                     # Security and deployment documentation
├── test_config.yaml          # Test configuration and benchmarks
└── output/                   # Local cache directory (git-ignored)
```

### Docker Configuration

- **Dockerfile.single**: Complete single-container build with supervisor
- **docker-compose.yml**: Multi-container development setup
- **Volume mounting**: `/app/output` for persistent cache storage
- **Network options**: Bridge mode (secure) or host mode (simple)

## Development Notes

### Adding New Voices
1. Place `.onnx` model file in `voices/` directory
2. Add corresponding `.onnx.json` config file
3. Update `config/voice_to_speaker.yaml` with voice mapping
4. Include quality level suffix (`_low`, `_medium`, `_high`)

### Cache Management
The system automatically manages cache size but provides manual controls:
- Access patterns tracked in `.access_log.json`
- Cleanup removes least-used + oldest files first
- Manual cleanup available via `/api/cache/cleanup` endpoint

### Security Considerations
- All user input validated with character whitelisting
- File operations use secure temporary files with random prefixes
- Rate limiting prevents abuse with service-appropriate limits
- Container runs as non-root user with minimal permissions