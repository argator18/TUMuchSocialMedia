cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env

read -p "Enter your OPENAI_API_KEY: " OPENAI_API_KEY
read -p "Enter your API_BASE (e.g. http://localhost:8000): " API_BASE

echo >> .env
echo "OPENAI_API_KEY=$OPENAI_API_KEY" >> .env
echo "API_BASE=$API_BASE" >> .env

echo "Values saved to .env"
