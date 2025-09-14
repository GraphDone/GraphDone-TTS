# 🔒 Security Guide

Security implementations and best practices for the PiperTTS Server.

## 🛡️ Implemented Security Measures

### 1. Rate Limiting
**Protects against**: DoS attacks, resource exhaustion, abuse

**Implementation**:
- **Web UI**: Flask-Limiter with memory backend
- **API Server**: SlowAPI with FastAPI integration

**Limits**:
```
Default: 200 requests/day, 50 requests/hour
/api/generate: 10 requests/minute
/api/generate-all: 2 requests/minute (resource-intensive)
/api/download: 30 requests/minute
API health/voices: 30/10 requests/minute respectively
```

### 2. Input Validation
**Protects against**: Injection attacks, malformed data, resource exhaustion

**Validation Rules**:
- **Maximum text length**: 1000 characters
- **Character whitelist**: Alphanumeric, spaces, basic punctuation, Unicode letters
- **Format validation**: Only 'wav' and 'mp3' allowed
- **Voice validation**: Against known voice list
- **Filename validation**: Secure filename handling with extension checking

### 3. Secure File Handling
**Protects against**: Path traversal, race conditions, disk exhaustion

**Security Measures**:
- Secure temporary file creation with random prefixes
- Path traversal protection with realpath validation
- Restricted file extensions (.wav, .mp3 only)
- Automatic cleanup mechanisms for temporary files
- Files created in controlled directories with proper permissions

### 4. Cache Management
**Protects against**: Disk exhaustion, storage DoS attacks

**Security Measures**:
- **Maximum cache size**: 10GB limit with automatic cleanup
- **LRU cleanup**: Oldest files removed first when limit reached
- **Automatic cleanup threshold**: 80% capacity triggers cleanup
- **Cache monitoring**: Real-time size and usage tracking via `/api/status`
- **Manual cleanup**: Administrative endpoint for cache management
- **Secure cache location**: Isolated `/tmp/tts_cache` directory

### 5. Authentication Framework
**Current Status**: Basic framework implemented
**Future Enhancement**: Ready for API key/token authentication

**Prepared Features**:
- SECRET_KEY configuration for session management
- CORS configuration with allowed origins
- Request validation infrastructure

### 6. Container Security
**Protects against**: Privilege escalation, container escape

**Implementations**:
- Non-root user (`tts:tts`) for container processes
- Minimal system packages installation
- Proper file ownership and permissions
- Read-only capabilities where possible
- Resource limits configuration

### 7. Error Handling
**Protects against**: Information disclosure

**Security Measures**:
- Generic error messages for client responses
- Detailed logging for debugging (server-side only)
- No stack trace exposure to clients
- Sanitized error responses

## 🚨 Security Audit Results

### ✅ **Fixed Critical Issues**

1. **Rate Limiting** - RESOLVED
   - Implemented on all endpoints
   - Different limits for different resource requirements
   - Memory-based storage for development, Redis-ready for production

2. **Input Validation** - RESOLVED
   - Text length limits (1000 chars)
   - Character whitelist with Unicode support
   - Format and voice validation
   - Secure filename handling

3. **File Security** - RESOLVED
   - Path traversal prevention
   - Secure temporary file creation
   - Automatic cleanup mechanisms
   - Proper file permissions

4. **Container Security** - RESOLVED
   - Non-root user implementation
   - Proper ownership and permissions
   - Minimal attack surface

### ⚠️ **Remaining Security Considerations**

1. **Authentication** - Framework ready, needs implementation
   - API keys or JWT tokens recommended for production
   - User management system for multi-user environments

2. **HTTPS/TLS** - Requires reverse proxy setup
   - Nginx or Traefik recommended
   - Let's Encrypt for SSL certificates

3. **Monitoring** - Basic health checks implemented
   - Security event logging recommended
   - Intrusion detection system integration

## 🔧 Production Security Setup

### Environment Variables

```bash
# Security Configuration
SECRET_KEY=your-secure-random-key-here
MAX_TEXT_LENGTH=1000
RATE_LIMIT_STORAGE=redis://redis:6379  # For production

# CORS Configuration
ALLOWED_ORIGINS=https://yourdomain.com,https://api.yourdomain.com
```

### Nginx Reverse Proxy (HTTPS)

```nginx
server {
    listen 443 ssl http2;
    server_name tts.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000";

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
    limit_req_zone $binary_remote_addr zone=web:10m rate=30r/m;

    location /api/ {
        limit_req zone=api burst=5 nodelay;
        proxy_pass http://localhost:8000/;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        limit_req zone=web burst=10 nodelay;
        proxy_pass http://localhost:3000;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Docker Security Configuration

```yaml
version: '3.8'
services:
  tts-server:
    image: tts-server-complete:latest
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETUID
      - SETGID
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=256m
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
```

### API Authentication (Recommended)

```python
# Example API key authentication
from functools import wraps
from flask import request, jsonify

def require_api_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        api_key = request.headers.get('X-API-Key')
        if not api_key or not validate_api_key(api_key):
            return jsonify({'error': 'Invalid or missing API key'}), 401
        return f(*args, **kwargs)
    return decorated_function

@app.route('/api/generate', methods=['POST'])
@require_api_key  # Add this decorator
@limiter.limit("10 per minute")
def generate_speech():
    # Your existing code
```

## 🔍 Security Monitoring

### Recommended Logs to Monitor

1. **Rate limit violations**
2. **Invalid input attempts**
3. **File access failures**
4. **Authentication failures** (when implemented)
5. **Unusual traffic patterns**

### Health Check Endpoints

```bash
# Server health
curl -f http://localhost:8000/health

# Service availability with cache status
curl -f http://localhost:3000/api/status

# Manual cache cleanup (cleanup to 80% of max size)
curl -X POST http://localhost:3000/api/cache/cleanup

# Custom cleanup percentage
curl -X POST -H "Content-Type: application/json" \
  -d '{"target_percent": 50}' \
  http://localhost:3000/api/cache/cleanup
```

## 🚫 Security Best Practices

### Deployment

1. **Never expose directly to internet** - Always use reverse proxy
2. **Use HTTPS** - Even for internal services
3. **Regular updates** - Keep dependencies current
4. **Backup security** - Encrypt backups
5. **Network isolation** - Use Docker networks or VPNs

### Configuration

1. **Environment variables** - Never hardcode secrets
2. **Minimal permissions** - Principle of least privilege
3. **Resource limits** - Prevent resource exhaustion
4. **Regular security scans** - Automated vulnerability checking

### Monitoring

1. **Log everything** - Security events, errors, access patterns
2. **Set up alerts** - Unusual activity, rate limit violations
3. **Regular audits** - Review logs and access patterns

## 🆘 Incident Response

### If Rate Limiting is Triggered

1. Check logs for source IP and patterns
2. Investigate if legitimate or attack
3. Adjust limits if needed for legitimate use
4. Block malicious IPs at network level if necessary

### If Input Validation Fails

1. Log the attempt with full details
2. Check for systematic attacks
3. Consider updating validation rules
4. Monitor for escalation attempts

### Container Security Issues

1. Immediately isolate affected containers
2. Review container logs
3. Check host system for compromise
4. Rebuild containers from clean images

## 📋 Security Checklist

### Pre-Production
- [ ] Rate limiting configured and tested
- [ ] Input validation covers all endpoints
- [ ] HTTPS/TLS configured
- [ ] Authentication system implemented
- [ ] Container security hardened
- [ ] Monitoring and alerting setup
- [ ] Backup and recovery tested
- [ ] Security scan completed

### Regular Maintenance
- [ ] Update dependencies monthly
- [ ] Review security logs weekly
- [ ] Test backup recovery quarterly
- [ ] Conduct security audits annually
- [ ] Update incident response procedures

---

**Note**: This security implementation provides a solid foundation but should be regularly reviewed and updated based on threat landscape changes and specific deployment requirements.