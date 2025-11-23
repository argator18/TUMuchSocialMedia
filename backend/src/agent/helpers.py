# %% helper funcitons
import os
import pandas as pd
import pickle as pkl
import openai
import uuid
import io
import json

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

# getter >>>>>>>>>>>>>>>>>>>>>>>>>>

def get_user_preferences(user_id):

    preferences_df = pd.read_pickle(preferences_path)

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
    return latest["preference"], latest["preferred_personality"], latest['selected_apps']

def get_name(id):
    users_df = pd.read_pickle(users_path)
    # Filter entries for this user
    user_entry = users_df[users_df["id"] == id].iloc[0]

    return user_entry["name"]

def get_user_log(user_id: str, time_delay: int):
    log_df = pd.read_pickle(log_path)
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

def get_last_user_log(user_id):
    log_df = pd.read_pickle(log_path)
    # Filter logs
    filtered_df = log_df[
        (log_df['user_id'] == user_id)
    ].sort_values(by="date_time", ascending=False)

    if filtered_df.empty:
        return f"Empty log - The user has not asked for anything in the last {time_delay} hours"
    else:
        return str(filtered_df.iloc[0].to_json(index=False))

def get_request_number(user_id):
    log_df = pd.read_pickle(log_path)
    # Ensure your column is datetime type
    log_df['date_time'] = pd.to_datetime(log_df['date_time'])

    # Today's date
    today = datetime.today().date()

    filtered_df = log_df[
        (log_df['user_id'] == user_id) &
        (log_df['date_time'].dt.date == today)
    ]

    return filtered_df.shape[0]




# setter >>>>>>>>>>>>>>>>>>
def update_log(user_id, query, answer):
    log_df = pd.read_pickle(log_path)    # Create timestamp (seconds only)

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

def format_time_factors_to_str(factors):
    times = [
        "In the morning hours after waking up",
        "During work hours",
        "After work and in the evening",
        "During the late evening before sleep"
    ]

    timing_pref_statements = []

    for i, factor in enumerate(factors):
        time = times[i]

        match factor:
            case 0 | 1 | 2 | 3:
                # Factor too low → skip
                continue

            case 4 | 5 | 6:
                timing_pref_statements.append(
                    f"{time}: The user wants to reduce their usage during this period."
                )

            case 7 | 8:
                timing_pref_statements.append(
                    f"{time}: The user should only use the apps for a good or meaningful reason."
                )

            case 9 | 10:
                timing_pref_statements.append(
                    f"{time}: Usage should generally not be allowed at this time. Only Emergencies"
                )

            case _:
                # Ignore invalid values
                continue

    if timing_pref_statements:
        "\n".join(["Additionally the user has whishes for these specific times:"] + timing_pref_statements)
    else:
        return ""

    return timing_pref_statements


def add_user(onboarding_config):
    preferences_df = pd.read_pickle(preferences_path)
    users_df = pd.read_pickle(users_path)

    # create a new row in users and user_preferences
    id = str(uuid.uuid4())
    name = onboarding_config['name']
    surname = onboarding_config['surname']
    date_time = datetime.now().replace(microsecond=0)

    # define the new row
    new_user = pd.DataFrame([{
        'id': id, 
        'name': name, 
        'surname': surname, 
        'joined': date_time
    }])

    # Append using concat adn save(recommended; .append() is deprecated)
    users_df = pd.concat([users_df, new_user], ignore_index=True)
    users_df.to_pickle(users_path)

    # Now the preferences:
    apps_list = onboarding_config['apps']
    apps = str(apps_list).strip("[]")
    morning_factor = onboarding_config['morning_factor']
    worktime_factor = onboarding_config['worktime_factor']
    evening_factor = onboarding_config['evening_factor']
    before_bed_factor = onboarding_config['before_bed_factor']
        
    factors = [morning_factor, worktime_factor,evening_factor, before_bed_factor]

    timing_preference = format_time_factors_to_str(factors)


    preference = f"""
    The user want to restrict his usage on the following app: {apps}

    His longterm goal is to achieve a constant combined screentime of these apps at around 2 hours.

    {timing_preference}


    """

    personality = "chill"

    new_preference = pd.DataFrame([{
        "date_time": date_time,
        "user_id": id,
        "preference": preference,
        "preferred_personality": personality,
        "selected_apps": apps_list
    }])

    # append to the pkl
    preferences_df = pd.concat([preferences_df, new_preference], ignore_index=True)
    preferences_df.to_pickle(preferences_path)

    return id

def update_user_preferences():
    pass

def delete_user_logs(user_id):
    log_df = pd.read_pickle(log_path)
    
    # Keep only rows where user_id does NOT match
    log_df = log_df[log_df['user_id'] != user_id].reset_index(drop=True)

    log_df.to_pickle(log_path)


# ===================================================================
# openai Stuff
# ===================================================================


def send_simple_query(messages, response_schema):
    
    response = client.responses.parse(
        model="gpt-5.1",   
        input=messages,
        text_format=response_schema, 
    )

    return response.output_parsed



def transcribe_voice(audio_bytes: bytes):
    audio_buffer = io.BytesIO(audio_bytes)
    audio_buffer.name = "audio.m4a"   # Whisper requires a filename

    transcript = client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_buffer,
        language="en"
    )

    return transcript.text

def ask_with_image(messages):
    response = client.responses.create(
        model="gpt-4o",
        input=messages,
    )

    return json.loads(response.output[0].content[0].text)

    # %%
