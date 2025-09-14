#!/bin/bash

echo "🐳 Installing Docker via snap..."
echo "================================"

# Install Docker using snap
echo "📦 Installing Docker with snap..."
sudo snap install docker

# Setup docker socket permissions
echo "🔧 Setting up Docker daemon..."
sudo systemctl start snap.docker.dockerd.service
sudo systemctl enable snap.docker.dockerd.service

# Add user to docker group (for snap docker)
echo "👤 Setting up user permissions..."
sudo addgroup --system docker 2>/dev/null || true
sudo adduser $USER docker

# Setup socket permissions
echo "🔐 Setting up socket permissions..."
sudo chmod 666 /var/run/docker.sock 2>/dev/null || true

echo "✅ Docker installation complete!"
echo "⚠️  You may need to run 'newgrp docker' or log out/in for group changes to take effect"

# Test Docker
echo "🧪 Testing Docker installation..."
sleep 5

if docker info &> /dev/null; then
    echo "✅ Docker is working correctly!"
else
    echo "⚠️  Docker may need group refresh. Try: newgrp docker"
fi

echo ""
echo "🚀 Now you can run: ./setup_tts.sh"