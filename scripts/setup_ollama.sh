#!/bin/bash

set -e

echo "Setting up Ollama with Tailscale network access..."

# Check if ollama is already installed
if ! command -v ollama &> /dev/null; then
    echo "Ollama not found. Installing..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo "Ollama installed successfully."
else
    echo "Ollama is already installed."
fi

# Create systemd service override directory
sudo mkdir -p /etc/systemd/system/ollama.service.d/

# Create override configuration to bind to all interfaces (0.0.0.0)
echo "Configuring Ollama to be accessible from Tailscale network..."
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF

# Reload systemd and restart ollama service
echo "Reloading systemd and restarting Ollama service..."
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama

# Check service status
echo "Checking Ollama service status..."
sudo systemctl status ollama --no-pager

echo ""
echo "Setup complete! Ollama is now accessible from your Tailscale network."
echo "You can access it at: http://[your-tailscale-ip]:11434"
echo "To find your Tailscale IP, run: tailscale ip -4"