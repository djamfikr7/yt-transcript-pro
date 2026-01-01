#!/bin/bash
PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "🔄 Restarting LingoForge System..."

#1. Cleanup old processes (Backend only, Frontend is managed by npm)
echo "🧹 Cleaning up old backend processes..."
pkill -f "python3 main.py" 2>/dev/null

#2. Install new dependencies
echo "📦 Installing new dependencies (langdetect, polyglot)..."
cd "$PROJECT_DIR/backend" || exit
if [ -f "venv/bin/activate" ]; then
    . venv/bin/activate
fi
pip install -q langdetect polyglot 2>&1 | grep -E "(Successfully|ERROR|error)" || echo "   Dependencies already installed or no updates needed"

#3. Start Backend
echo "🚀 Starting Backend..."
cd "$PROJECT_DIR/backend" || exit
if [ -f "venv/bin/python" ]; then
    nohup ./venv/bin/python main.py > "$PROJECT_DIR/backend.log" 2>&1 &
else
    nohup python3 main.py > "$PROJECT_DIR/backend.log" 2>&1 &
fi
BACKEND_PID=$!
echo "   ✅ Backend started (PID: $BACKEND_PID)"

#4. Open Browser (Backend serves the built frontend)
echo "🌐 Opening LingoForge Studio..."
(sleep 3 && xdg-open http://localhost:8000) &

echo "=================================================="
echo "✅ SYSTEM RELAUNCHED SUCCESSFULLY"
echo "   Backend Logs: $PROJECT_DIR/backend.log"
echo "   Frontend Logs: $PROJECT_DIR/frontend.log"
echo "=================================================="
