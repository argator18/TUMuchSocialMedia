# helper funcitons
import os
import pandas as pd
import pickle as pkl
import openai
from pydantic import BaseModel
from pathlib import Path
from datetime import datetime, timedelta

client = openai.OpenAI()


class BouncerAnswerFormat(BaseModel):
    allow: bool
    time: int
    reply: str

class GoalFeedbackFormat(BaseModel):
    # Is the user currently acting in line with the stated goal?
    on_track: bool

    # Short textual verdict, e.g. "You are still on track", "You drifted off into explore-feed"
    verdict: str

    # 1–100 score of how well current behavior matches the goal
    score: int

    # Short, actionable feedback (1–3 sentences)
    feedback: str

    # Optional suggestion for the *next* concrete action (e.g. "close app", "go back to DMs", etc.)
    next_step: str


# ===================================================================
# Helper Funciton Simulating a Dtabase with .pkl's Funcionalities
# ===================================================================

# Directory of THIS file: backend/src/agent/helpers.py 
# -> should result in the path of agent folder independant form machine and executing script
BASE_DIR = Path(__file__).resolve().parent

# load local .pkl's simulating database
preferences_path = BASE_DIR / "user_preferences.pkl"
users_path = BASE_DIR / "users.pkl"
log_path = BASE_DIR / "log.pkl"

preferences_df = pd.read_pickle(preferences_path)
users_df = pd.read_pickle(users_path)
log_df = pd.read_pickle(log_path)

# getter >>>>>>>>>>>>>>>>>>>>>>>>>>

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

def get_user_log(user_id: str, time_delay: int):
    # the previous user requests and answers from the user to the agent
    # All request during the last *time_delay** hours (should be positve int)

    # Convert negative or 0 time_delay to valid values
    if time_delay <= 0:
        raise ValueError("time_delay must be a positive integer")

    # Compute time window
    cutoff = datetime.now() - timedelta(hours=time_delay)

    # Filter logs
    filtered_df = log_df[
        (log_df['user_id'] == user_id) &
        (log_df['date_time'] >= cutoff)
    ].sort_values(by="date_time")

    if filtered_df.empty:
        return f"Empty log - The user has not asked for anything in the last {time_delay} hours"
    else:
        return filtered_df.to_csv(index=False)





# setter >>>>>>>>>>>>>>>>>>
def update_log(user_id, query, answer):
    global log_df
    # Create timestamp (seconds only)
    date_time = datetime.now().replace(microsecond=0)

    # Create a new row as a DataFrame for safe concatenation
    new_entry = pd.DataFrame([{
        "user_id": user_id,
        "query": query,
        "answer": answer,
        "date_time": date_time,
    }])

    # Append using concat (recommended; .append() is deprecated)
    log_df = pd.concat([log_df, new_entry], ignore_index=True)

    log_df.to_pickle(log_path)

def add_user():
    pass

def update_user_preferences():
    pass

def delete_user_logs(user_id):
    global log_df
    
    # Keep only rows where user_id does NOT match
    log_df = log_df[log_df['user_id'] != user_id].reset_index(drop=True)

    log_df.to_pickle(log_path)


# ===================================================================
# openai Stuff
# ===================================================================


def send_simple_query(messages, response_schema):
    response = client.responses.parse(
        model="gpt-5.1-mini",   
        input=messages,
        response_format=response_schema,  
    )
    return response.output_parsed

