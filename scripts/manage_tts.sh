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
        echo "🚀 Starting TTS server..."
        $DOCKER_COMPOSE up -d
        echo "📡 Server starting at http://localhost:8000"
        echo "📖 API docs available at http://localhost:8000/docs"
        ;;
    stop)
        echo "🛑 Stopping TTS server..."
        $DOCKER_COMPOSE down
        ;;
    restart)
        echo "🔄 Restarting TTS server..."
        $DOCKER_COMPOSE restart
        ;;
    logs)
        $DOCKER_COMPOSE logs -f
        ;;
    test)
        ./test_tts.sh
        ;;
    status)
        $DOCKER_COMPOSE ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|test|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the TTS server"
        echo "  stop    - Stop the TTS server"
        echo "  restart - Restart the TTS server"
        echo "  logs    - View server logs"
        echo "  test    - Test TTS generation"
        echo "  status  - Show container status"
        ;;
esac

