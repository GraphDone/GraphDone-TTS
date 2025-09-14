# 📋 API Documentation

Complete API reference for the PiperTTS Server.

## Base URL

- **Development**: `http://localhost:8000`
- **Production**: Adjust based on your deployment

## Authentication

Currently no authentication required. For production deployments, consider adding authentication middleware.

## Endpoints

### 1. Health Check

Check if the TTS server is running and healthy.

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "healthy",
  "service": "PiperTTS"
}
```

**Example:**
```bash
curl http://localhost:8000/health
```

---

### 2. List Available Voices

Get all available voices and their model mappings.

**Endpoint:** `GET /voices`

**Response:**
```json
{
  "amy_low": "en_US-amy-low",
  "amy_medium": "en_US-amy-medium",
  "lessac_low": "en_US-lessac-low",
  "lessac_medium": "en_US-lessac-medium",
  "ljspeech_high": "en_US-ljspeech-high",
  "alan_medium": "en_GB-alan-medium",
  "siwis_medium": "fr_FR-siwis-medium",
  "alloy": "en_US-lessac-medium"
}
```

**Example:**
```bash
curl http://localhost:8000/voices
```

---

### 3. Generate Speech

Generate speech audio from text using specified voice.

**Endpoint:** `POST /generate`

**Request Body:**
```json
{
  "text": "Hello, world!",
  "voice": "amy_medium",
  "format": "wav"
}
```

**Parameters:**
- `text` (required): Text to convert to speech
- `voice` (optional): Voice to use (default: "amy")
- `format` (optional): Output format - "wav" or "mp3" (default: "wav")

**Response:** Binary audio file

**Headers:**
- `Content-Type`: `audio/wav` or `audio/mp3`
- `Content-Disposition`: `attachment; filename="speech.wav"`
- `X-Requested-Format`: Original requested format

**Example:**
```bash
# Basic generation
curl -X POST "http://localhost:8000/generate" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world","voice":"amy_medium","format":"wav"}' \
  --output speech.wav

# High quality voice
curl -X POST "http://localhost:8000/generate" \
  -H "Content-Type: application/json" \
  -d '{"text":"Bonjour le monde","voice":"siwis_medium","format":"wav"}' \
  --output french.wav
```

**Error Responses:**

`400 Bad Request`:
```json
{
  "detail": "No text provided"
}
```

`400 Bad Request` (Invalid voice):
```json
{
  "detail": "Voice 'invalid_voice' not found. Available: ['amy_medium', 'lessac_medium', ...]"
}
```

`500 Internal Server Error`:
```json
{
  "detail": "PiperTTS error: [error message]"
}
```

---

### 4. Download with Format Conversion

Download a generated audio file with optional format conversion.

**Endpoint:** `GET /download/{filename}`

**Query Parameters:**
- `format` (optional): Target format for conversion - "wav" or "mp3"

**Response:** Binary audio file with requested format

**Example:**
```bash
# Download original WAV
curl "http://localhost:8000/download/speech.wav" --output audio.wav

# Convert to MP3 on download
curl "http://localhost:8000/download/speech.wav?format=mp3" --output audio.mp3
```

## Voice Quality Levels

### High Quality
- **Best audio quality**
- **Larger file sizes**
- **Slower generation**
- Available: `ljspeech_high`

### Medium Quality
- **Balanced performance**
- **Good audio quality**
- **Moderate generation speed**
- Available: `amy_medium`, `lessac_medium`, `ryan_medium`, etc.

### Low Quality
- **Fastest generation**
- **Smaller file sizes**
- **Good for development/testing**
- Available: `amy_low`, `lessac_low`, `danny_low`, etc.

## Format Optimization

### WAV (Recommended)
- **Fastest generation** - no conversion required
- **Best quality** - lossless format
- **Larger file sizes**
- **Direct output from PiperTTS**

### MP3
- **Smaller file sizes** - compressed format
- **Slower processing** - requires conversion
- **Good for web delivery**
- **128kbps encoding**

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200 OK` - Success
- `400 Bad Request` - Invalid parameters
- `404 Not Found` - File or endpoint not found
- `500 Internal Server Error` - Server/TTS engine error

Error responses include detailed messages in JSON format:
```json
{
  "detail": "Descriptive error message"
}
```

## Rate Limiting

Currently no rate limiting implemented. For production use, consider implementing rate limiting based on your requirements.

## Caching

The server implements intelligent caching:
- **Case-insensitive** text matching
- **Space-normalized** caching keys
- **Automatic cache reuse** for identical requests
- **CRC-based filenames** for uniqueness

## Interactive Documentation

Access live API documentation:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

Both provide interactive testing capabilities and detailed schema information.