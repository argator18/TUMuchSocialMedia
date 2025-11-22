pkill -f uvicorn
source venv/bin/activate
uvicorn src.main:backend_app --host 0.0.0.0 --port 8000 --reload