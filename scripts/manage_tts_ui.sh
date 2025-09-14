#!/bin/bash

# Function to detect docker-compose command
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"  # fallback
    fi
}

DOCKER_COMPOSE=$(get_docker_compose_cmd)

case "$1" in
    start)
        echo "🚀 Starting TTS server with Web UI..."
        $DOCKER_COMPOSE up -d --build
        echo "📡 TTS API server: http://localhost:8000"
        echo "🌐 Web UI: http://localhost:3000"
        echo "📖 API docs: http://localhost:8000/docs"
        ;;
    stop)
        echo "🛑 Stopping TTS server and Web UI..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "🔄 Restarting TTS server and Web UI..."
        $DOCKER_COMPOSE restart
        ;;
    logs)
        echo "Which logs would you like to see? (tts/ui/all)"
        read -r choice
        case $choice in
            tts)
                $DOCKER_COMPOSE logs -f openedai-speech
                ;;
            ui)
                $DOCKER_COMPOSE logs -f tts-webui
                ;;
            *)
                $DOCKER_COMPOSE logs -f
                ;;
        esac
        ;;
    build)
        echo "🔧 Building Web UI..."
        $DOCKER_COMPOSE build tts-webui
        ;;
    status)
        $DOCKER_COMPOSE ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|build|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start TTS server and Web UI"
        echo "  stop    - Stop TTS server and Web UI"
        echo "  restart - Restart services"
        echo "  logs    - View logs (interactive)"
        echo "  build   - Rebuild Web UI container"
        echo "  status  - Show container status"
        echo ""
        echo "Access points:"
        echo "  Web UI: http://localhost:3000"
        echo "  TTS API: http://localhost:8000"
        echo "  API Docs: http://localhost:8000/docs"
        ;;
esac
