#!/bin/bash

echo "📥 Downloading PiperTTS voices..."

# Create voices directory
mkdir -p voices

cd voices

# Download English voices
echo "🗣️  Downloading English voices..."

# US English voices - multiple quality levels
echo "Downloading US English voices..."

# Amy - low and medium
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx?download=true" -O en_US-amy-low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/low/en_US-amy-low.onnx.json?download=true" -O en_US-amy-low.onnx.json
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx?download=true" -O en_US-amy-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium/en_US-amy-medium.onnx.json?download=true" -O en_US-amy-medium.onnx.json

# Lessac - low and medium
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/low/en_US-lessac-low.onnx?download=true" -O en_US-lessac-low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/low/en_US-lessac-low.onnx.json?download=true" -O en_US-lessac-low.onnx.json
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx?download=true" -O en_US-lessac-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json?download=true" -O en_US-lessac-medium.onnx.json

# Ryan - low and medium
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/low/en_US-ryan-low.onnx?download=true" -O en_US-ryan-low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/low/en_US-ryan-low.onnx.json?download=true" -O en_US-ryan-low.onnx.json
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/medium/en_US-ryan-medium.onnx?download=true" -O en_US-ryan-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ryan/medium/en_US-ryan-medium.onnx.json?download=true" -O en_US-ryan-medium.onnx.json

# Danny - low only
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/danny/low/en_US-danny-low.onnx?download=true" -O en_US-danny-low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/danny/low/en_US-danny-low.onnx.json?download=true" -O en_US-danny-low.onnx.json

# Kathleen - low only
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/kathleen/low/en_US-kathleen-low.onnx?download=true" -O en_US-kathleen-low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/kathleen/low/en_US-kathleen-low.onnx.json?download=true" -O en_US-kathleen-low.onnx.json

# LJSpeech - high quality
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ljspeech/high/en_US-ljspeech-high.onnx?download=true" -O en_US-ljspeech-high.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/ljspeech/high/en_US-ljspeech-high.onnx.json?download=true" -O en_US-ljspeech-high.onnx.json

# GB English voices
echo "Downloading GB English voices..."
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/alan/medium/en_GB-alan-medium.onnx?download=true" -O en_GB-alan-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/alan/medium/en_GB-alan-medium.onnx.json?download=true" -O en_GB-alan-medium.onnx.json

wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx?download=true" -O en_GB-jenny_dioco-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_GB/jenny_dioco/medium/en_GB-jenny_dioco-medium.onnx.json?download=true" -O en_GB-jenny_dioco-medium.onnx.json

# Download some popular international voices
echo "🌍 Downloading international voices..."

# French
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx?download=true" -O fr_FR-siwis-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx.json?download=true" -O fr_FR-siwis-medium.onnx.json

# German
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx?download=true" -O de_DE-thorsten-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx.json?download=true" -O de_DE-thorsten-medium.onnx.json

# Spanish
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx?download=true" -O es_ES-davefx-medium.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json?download=true" -O es_ES-davefx-medium.onnx.json

# Italian
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/it/it_IT/riccardo_fasol/x_low/it_IT-riccardo_fasol-x_low.onnx?download=true" -O it_IT-riccardo_fasol-x_low.onnx
wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/it/it_IT/riccardo_fasol/x_low/it_IT-riccardo_fasol-x_low.onnx.json?download=true" -O it_IT-riccardo_fasol-x_low.onnx.json

cd ..

echo "✅ Downloaded PiperTTS voices:"
ls -la voices/*.onnx | wc -l
echo "voice files ready!"

# Update voice mapping to use actual PiperTTS voice files with quality options
cat > config/voice_to_speaker.yaml << 'EOF'
# PiperTTS Voice to Model Mapping with Quality Levels
# Format: "voice_name quality": model_file_path (without .onnx extension)

# English US Voices - Multiple Quality Options
amy_low: en_US-amy-low
amy_medium: en_US-amy-medium
lessac_low: en_US-lessac-low
lessac_medium: en_US-lessac-medium
ryan_low: en_US-ryan-low
ryan_medium: en_US-ryan-medium
danny_low: en_US-danny-low
kathleen_low: en_US-kathleen-low
ljspeech_high: en_US-ljspeech-high

# English GB Voices
alan_medium: en_GB-alan-medium
jenny_medium: en_GB-jenny_dioco-medium

# International Voices
siwis_medium: fr_FR-siwis-medium
thorsten_medium: de_DE-thorsten-medium
davefx_medium: es_ES-davefx-medium
riccardo_x_low: it_IT-riccardo_fasol-x_low

# Aliases for OpenAI compatibility (defaults to recommended quality)
alloy: en_US-lessac-medium
echo: en_US-danny-low
fable: en_GB-alan-medium
onyx: en_US-ryan-medium
nova: en_US-amy-medium
shimmer: en_US-ljspeech-high

# Default voice shortcuts (medium quality when available)
amy: en_US-amy-medium
lessac: en_US-lessac-medium
ryan: en_US-ryan-medium
danny: en_US-danny-low
kathleen: en_US-kathleen-low
ljspeech: en_US-ljspeech-high
alan: en_GB-alan-medium
jenny: en_GB-jenny_dioco-medium
siwis: fr_FR-siwis-medium
thorsten: de_DE-thorsten-medium
davefx: es_ES-davefx-medium
riccardo: it_IT-riccardo_fasol-x_low

EOF

echo "📝 Updated voice configuration with PiperTTS models"