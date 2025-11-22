# helper funcitons
import os
import pandas as pd
import pickle as pkl
import openai
from pydantic import BaseModel
from pathlib import Path

client = openai.OpenAI()


class BouncerAnswerFormat(BaseModel):
    allow: bool
    time: int
    reply: str

# ===================================================================
# Helper Funciton Simulating a Dtabase with .pkl's Funcionalities
# ===================================================================

# Directory of THIS file: backend/src/agent/helpers.py 
# -> should result in the path of agent folder independant form machine and executing script
BASE_DIR = Path(__file__).resolve().parent

# load local .pkl's simulating database
preferences_path = BASE_DIR / "user_preferences.pkl"
users_path = BASE_DIR / "users.pkl"

preferences_df = pd.read_pickle(preferences_path)
users_df = pd.read_pickle(users_path)

# getter

def get_user_preferences(user_id):
    # Filter entries for this user
    user_entries = preferences_df[preferences_df["user_id"] == user_id]
    
    if user_entries.empty:
        return None  # or raise an error
    
    # Make sure date_time column is datetime
    if not pd.api.types.is_datetime64_any_dtype(user_entries["date_time"]):
        user_entries = user_entries.copy()
        user_entries["date_time"] = pd.to_datetime(user_entries["date_time"])
    
    # Sort descending (newest first)
    user_entries = user_entries.sort_values("date_time", ascending=False)
    
    latest = user_entries.iloc[0]
    
    # Return a tuple (preference, preferred_personality)
    return latest["preference"], latest["preferred_personality"]

def get_name(id):
    # Filter entries for this user
    user_entry = users_df[users_df["id"] == id].iloc[0]

    return user_entry["name"]


# setter

def add_user():
    pass

def update_user_preferences():
    pass


# ===================================================================
# openai Stuff
# ===================================================================

def send_simple_query(messages, response_schema):
    # simple message asking for allowance to use an app
    response = client.responses.parse(
        model="gpt-5-nano",
        input=messages,
        text_format=response_schema
    )

    return response.output_parsed
