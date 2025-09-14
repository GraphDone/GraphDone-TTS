# 🚀 Deployment Guide

Complete guide for deploying PiperTTS Server in different environments.

## Deployment Options

### 1. Development Deployment (Multi-Container)

Best for development, testing, and customization.

```bash
# Clone repository
git clone <your-repo-url>
cd tts-server-ui

# Start with automatic voice download
docker compose up -d

# Or pre-download voices
./download_voices.sh
docker compose up -d
```

**Pros:**
- Easy to modify individual services
- Separate containers for debugging
- Hot-reload during development
- Easy to add custom voices

**Cons:**
- More complex setup
- Multiple containers to manage

---

### 2. Production Deployment (Single Container)

Best for production environments and simple deployments.

#### Option A: Pre-built Image
```bash
# Use the pre-built complete image (2.04GB with all voices)
docker run -d -p 8000:8000 -p 3000:3000 --name tts-server tts-server-complete:latest
```

#### Option B: Build Your Own
```bash
# Build complete package
./package_single.sh

# Run your built image
docker run -d -p 8000:8000 -p 3000:3000 --name tts-server tts-server-complete:latest
```

**Pros:**
- Single container to manage
- Includes all dependencies and voices
- Simpler deployment
- Good for Docker Swarm/Kubernetes

**Cons:**
- Larger image size
- Less flexibility for customization

---

### 3. Cloud Deployment

#### AWS ECS
```json
{
  "family": "tts-server",
  "taskDefinition": {
    "containerDefinitions": [
      {
        "name": "tts-server",
        "image": "tts-server-complete:latest",
        "portMappings": [
          {
            "containerPort": 3000,
            "hostPort": 3000,
            "protocol": "tcp"
          },
          {
            "containerPort": 8000,
            "hostPort": 8000,
            "protocol": "tcp"
          }
        ],
        "memory": 2048,
        "cpu": 1024
      }
    ]
  }
}
```

#### Docker Swarm
```bash
# Create service
docker service create \
  --name tts-server \
  --publish 3000:3000 \
  --publish 8000:8000 \
  --replicas 2 \
  tts-server-complete:latest
```

#### Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tts-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tts-server
  template:
    metadata:
      labels:
        app: tts-server
    spec:
      containers:
      - name: tts-server
        image: tts-server-complete:latest
        ports:
        - containerPort: 3000
        - containerPort: 8000
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: tts-server-service
spec:
  selector:
    app: tts-server
  ports:
  - name: web
    port: 3000
    targetPort: 3000
  - name: api
    port: 8000
    targetPort: 8000
  type: LoadBalancer
```

## Network Configuration

### Bridge Mode (Recommended)

Secure, isolated networking with port mapping:

```bash
# Multi-container
docker compose up -d

# Single container
docker run -d -p 8000:8000 -p 3000:3000 --name tts-server tts-server-complete:latest
```

**Pros:**
- Network isolation
- Port control
- Multiple deployments possible
- Works with firewalls

**Cons:**
- Requires port mapping
- Slightly more complex networking

### Host Mode (Simple)

Direct access to host network:

```bash
# Single container
docker run -d --network host --name tts-server tts-server-complete:latest

# Multi-container (docker-compose.single.yml)
# Edit file to uncomment network_mode: host
docker compose -f docker-compose.single.yml up -d
```

**Pros:**
- Simple networking
- No port mapping needed
- Best performance

**Cons:**
- Less secure
- Cannot run multiple instances
- Potential port conflicts

## Environment Configuration

### Environment Variables

```bash
# Web UI Configuration
TTS_API_URL=http://localhost:8000    # TTS server endpoint
MAX_WORKERS=8                        # Parallel processing workers
PYTHONUNBUFFERED=1                   # Python output buffering

# Server Configuration
VOICES_DIR=/app/voices               # Voice models directory
CONFIG_DIR=/app/config               # Configuration directory
```

### Custom Voices

To add custom voices to deployment:

1. **Multi-container setup:**
```bash
# Add voice files to voices/ directory
cp custom-voice.onnx voices/
cp custom-voice.onnx.json voices/

# Update configuration
echo "custom: custom-voice" >> config/voice_to_speaker.yaml

# Restart
docker compose restart
```

2. **Single container setup:**
```bash
# Create volume mount
docker run -d \
  -p 8000:8000 -p 3000:3000 \
  -v $(pwd)/custom-voices:/app/voices \
  -v $(pwd)/custom-config:/app/config \
  --name tts-server tts-server-complete:latest
```

## Performance Tuning

### Resource Requirements

**Minimum Requirements:**
- CPU: 2 cores
- RAM: 2GB
- Storage: 3GB (with all voices)
- Network: 100 Mbps

**Recommended for Production:**
- CPU: 4+ cores
- RAM: 4GB+
- Storage: 5GB+ (with caching)
- Network: 1 Gbps

### Optimization Settings

```bash
# Increase parallel workers (adjust based on CPU cores)
export MAX_WORKERS=16

# Optimize for CPU-bound tasks
docker run --cpus="4.0" --memory="4g" ...

# Use faster storage for voice models
docker run -v /path/to/ssd:/app/voices ...
```

### Caching Strategy

The system includes built-in caching:
- **Location**: `/tmp/tts_cache` (inside container)
- **Persistence**: Mount volume for persistent cache
```bash
docker run -v tts-cache:/tmp/tts_cache tts-server-complete:latest
```

## Security Considerations

### Basic Security

```bash
# Run as non-root user (for custom builds)
USER 1000:1000

# Read-only file system (except cache)
docker run --read-only --tmpfs /tmp tts-server-complete:latest

# Drop capabilities
docker run --cap-drop=ALL --cap-add=CHOWN tts-server-complete:latest
```

### Reverse Proxy Setup

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name tts.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Traefik Configuration:**
```yaml
version: '3.7'
services:
  tts-server:
    image: tts-server-complete:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.tts-ui.rule=Host(`tts.yourdomain.com`)"
      - "traefik.http.routers.tts-ui.service=tts-ui"
      - "traefik.http.services.tts-ui.loadbalancer.server.port=3000"
      - "traefik.http.routers.tts-api.rule=Host(`tts.yourdomain.com`) && PathPrefix(`/api`)"
      - "traefik.http.routers.tts-api.service=tts-api"
      - "traefik.http.services.tts-api.loadbalancer.server.port=8000"
```

## Monitoring and Logging

### Health Checks

```bash
# Docker health check
docker run --health-cmd="curl -f http://localhost:8000/health || exit 1" \
           --health-interval=30s \
           --health-timeout=10s \
           --health-retries=3 \
           tts-server-complete:latest
```

### Logging

```bash
# View logs
docker compose logs -f

# Single container logs
docker logs -f tts-server

# Export logs
docker logs tts-server > tts-server.log 2>&1
```

### Metrics Collection

For Prometheus monitoring, consider adding:
- Request count metrics
- Response time metrics
- Voice generation success/failure rates
- Cache hit/miss ratios

## Backup and Recovery

### Backup Strategy

```bash
# Backup voice models and configuration
tar -czf tts-backup.tar.gz voices/ config/

# Backup Docker volumes
docker run --rm -v tts-cache:/data -v $(pwd):/backup alpine \
  tar -czf /backup/cache-backup.tar.gz -C /data .
```

### Disaster Recovery

```bash
# Restore from backup
tar -xzf tts-backup.tar.gz

# Restore Docker volume
docker run --rm -v tts-cache:/data -v $(pwd):/backup alpine \
  tar -xzf /backup/cache-backup.tar.gz -C /data
```

## Troubleshooting

### Common Issues

1. **Container fails to start**
   ```bash
   # Check logs
   docker logs tts-server

   # Verify port availability
   netstat -tlnp | grep :3000
   netstat -tlnp | grep :8000
   ```

2. **Out of memory errors**
   ```bash
   # Increase container memory
   docker run -m 4g tts-server-complete:latest
   ```

3. **Voice generation failures**
   ```bash
   # Check voice model files
   docker exec tts-server ls -la /app/voices/

   # Verify configuration
   docker exec tts-server cat /app/config/voice_to_speaker.yaml
   ```

4. **Performance issues**
   ```bash
   # Monitor resource usage
   docker stats

   # Increase worker count
   docker run -e MAX_WORKERS=16 tts-server-complete:latest
   ```

### Getting Help

1. Check logs first: `docker logs tts-server`
2. Verify configuration files exist and are valid
3. Test API endpoints directly: `curl http://localhost:8000/health`
4. Check available voices: `curl http://localhost:8000/voices`