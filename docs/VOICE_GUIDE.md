# 🎭 Voice Guide

Complete guide to available voices, quality levels, and language support.

## Voice Quality Levels

### 🌟 High Quality
- **Best audio quality** with natural pronunciation
- **Larger model sizes** (50-200MB per voice)
- **Slower generation** (2-5 seconds)
- **Best for production content**

### ⚖️ Medium Quality
- **Balanced performance** and quality
- **Moderate model sizes** (20-50MB per voice)
- **Good generation speed** (1-3 seconds)
- **Recommended for most use cases**

### ⚡ Low Quality
- **Fastest generation** (0.5-1.5 seconds)
- **Smallest model sizes** (10-30MB per voice)
- **Good for development/testing**
- **Acceptable quality for many applications**

---

## Available Voices by Language

### 🇺🇸 US English

#### High Quality
- **`ljspeech_high`** - Female, clear articulation, professional quality
  - Model: `en_US-ljspeech-high`
  - Best for: Audiobooks, presentations, professional content

#### Medium Quality
- **`amy_medium`** - Female, warm and friendly
  - Model: `en_US-amy-medium`
  - Best for: General purpose, customer service

- **`lessac_medium`** - Female, professional tone
  - Model: `en_US-lessac-medium`
  - Best for: Business applications, announcements

- **`ryan_medium`** - Male, clear and confident
  - Model: `en_US-ryan-medium`
  - Best for: Narration, educational content

#### Low Quality (Fast)
- **`amy_low`** - Female, quick generation
  - Model: `en_US-amy-low`
  - Best for: Testing, development

- **`lessac_low`** - Female, rapid synthesis
  - Model: `en_US-lessac-low`
  - Best for: Prototyping, bulk generation

- **`ryan_low`** - Male, fast processing
  - Model: `en_US-ryan-low`
  - Best for: Development, demos

- **`danny_low`** - Male, casual tone
  - Model: `en_US-danny-low`
  - Best for: Informal content, games

- **`kathleen_low`** - Female, conversational
  - Model: `en_US-kathleen-low`
  - Best for: Chatbots, interactive apps

---

### 🇬🇧 British English

#### Medium Quality
- **`alan_medium`** - Male, refined British accent
  - Model: `en_GB-alan-medium`
  - Best for: Formal content, educational material

- **`jenny_medium`** - Female, pleasant British accent
  - Model: `en_GB-jenny_dioco-medium`
  - Best for: General purpose, customer service

---

### 🇫🇷 French

#### Medium Quality
- **`siwis_medium`** - Female, native French pronunciation
  - Model: `fr_FR-siwis-medium`
  - Best for: French content, language learning

---

### 🇩🇪 German

#### Medium Quality
- **`thorsten_medium`** - Male, clear German pronunciation
  - Model: `de_DE-thorsten-medium`
  - Best for: German content, business applications

---

### 🇪🇸 Spanish

#### Medium Quality
- **`davefx_medium`** - Male, native Spanish pronunciation
  - Model: `es_ES-davefx-medium`
  - Best for: Spanish content, international applications

---

### 🇮🇹 Italian

#### X-Low Quality (Fast)
- **`riccardo_x_low`** - Male, Italian pronunciation
  - Model: `it_IT-riccardo_fasol-x_low`
  - Best for: Italian content, quick generation

---

## OpenAI Compatible Aliases

For compatibility with OpenAI TTS API, these aliases are available:

- **`alloy`** → `lessac_medium` (US Female)
- **`echo`** → `danny_low` (US Male)
- **`fable`** → `alan_medium` (GB Male)
- **`onyx`** → `ryan_medium` (US Male)
- **`nova`** → `amy_medium` (US Female)
- **`shimmer`** → `ljspeech_high` (US Female, High Quality)

---

## Voice Selection Guidelines

### For Different Use Cases

#### 🎙️ **Podcasts & Audiobooks**
- **Recommended**: `ljspeech_high`, `ryan_medium`, `alan_medium`
- **Quality**: High or Medium
- **Reason**: Natural flow, clear articulation

#### 💼 **Business Applications**
- **Recommended**: `lessac_medium`, `ryan_medium`, `alan_medium`
- **Quality**: Medium
- **Reason**: Professional tone, clear communication

#### 🎮 **Games & Interactive Apps**
- **Recommended**: `danny_low`, `kathleen_low`, `amy_low`
- **Quality**: Low (for speed)
- **Reason**: Fast generation for dynamic content

#### 🤖 **Chatbots & Voice Assistants**
- **Recommended**: `amy_medium`, `lessac_medium`, `jenny_medium`
- **Quality**: Medium
- **Reason**: Friendly, conversational tone

#### 📚 **Educational Content**
- **Recommended**: `ryan_medium`, `alan_medium`, `ljspeech_high`
- **Quality**: Medium to High
- **Reason**: Clear pronunciation, good for learning

#### 🌍 **Multilingual Applications**
- **Available Languages**: English, French, German, Spanish, Italian
- **Recommendation**: Use native language voices for best pronunciation

---

## Technical Specifications

### Audio Format Details
- **Sample Rate**: 22,050 Hz (standard)
- **Bit Depth**: 16-bit
- **Channels**: Mono
- **Output Formats**: WAV (native), MP3 (converted)

### Model Information
- **Engine**: PiperTTS with ONNX runtime
- **Neural Architecture**: VITS (Variational Inference Text-to-Speech)
- **Phonemization**: Language-specific phoneme mapping
- **Training Data**: High-quality speech datasets

---

## Performance Comparison

| Voice Quality | Generation Time | File Size (10s audio) | Model Size | Use Case |
|---------------|----------------|----------------------|------------|----------|
| High | 2-5 seconds | ~350KB (WAV) | 50-200MB | Production |
| Medium | 1-3 seconds | ~350KB (WAV) | 20-50MB | General use |
| Low | 0.5-1.5 seconds | ~350KB (WAV) | 10-30MB | Development |

*Note: File sizes for WAV format are consistent as they depend on audio length, not model quality. Quality affects generation time and audio fidelity.*

---

## Adding Custom Voices

### Requirements
1. **ONNX model file** (`.onnx`)
2. **Configuration file** (`.onnx.json`)
3. **Compatible with PiperTTS**

### Installation Steps

1. **Add voice files:**
```bash
# Copy to voices directory
cp custom-voice.onnx voices/
cp custom-voice.onnx.json voices/
```

2. **Update configuration:**
```yaml
# Add to config/voice_to_speaker.yaml
custom_voice: custom-voice
```

3. **Restart services:**
```bash
docker compose restart
```

### Voice Sources
- **Hugging Face**: [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices)
- **Community Models**: Check PiperTTS community for additional voices
- **Custom Training**: Train your own with PiperTTS training tools

---

## Troubleshooting Voice Issues

### Voice Not Found Error
```bash
# Check available voices
curl http://localhost:8000/voices

# Verify voice files exist
docker exec tts-server ls -la /app/voices/

# Check configuration
docker exec tts-server cat /app/config/voice_to_speaker.yaml
```

### Poor Audio Quality
1. **Try higher quality version** of the same voice
2. **Check model file integrity** (re-download if corrupted)
3. **Verify JSON configuration** matches ONNX model

### Slow Generation
1. **Use lower quality voices** for faster generation
2. **Enable caching** for repeated text
3. **Use WAV format** to avoid conversion overhead

### Foreign Language Issues
1. **Use native language voices** for best pronunciation
2. **Check text encoding** (UTF-8 recommended)
3. **Verify phoneme mapping** in model configuration

---

## Voice Licensing

All included voices are based on open-source models:
- **License**: Various open-source licenses (check individual model sources)
- **Commercial Use**: Generally permitted (verify specific license)
- **Attribution**: Check model documentation for attribution requirements

**Important**: Always verify licensing terms for your specific use case, especially for commercial applications.