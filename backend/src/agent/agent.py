#%%  
import os
from dotenv import load_dotenv
import uuid
import asyncio

load_dotenv(dotenv_path="/home/andy/apps/hackatum/TUMuchSocialMedia/.env")

from helpers import *
from prompts import *

# ==================================
#           Agents
# ==================================

# %%

async def ask_for_app_permission(user_id, query: str):

    # for testing
    user_preferences = "The user asking is Tim. He is very ambitionate and in his exam period and want you to be very strict with him"
    user_name = get_name(user_id)
    user_pref, user_fav_personality = get_user_preferences(user_id)

    PERSONALITY_PROMPT = PERSONALITY_MAP[user_fav_personality]

    context = f"""
    CONTEXT:

    The users name is: {user_name}

    
    """

    messages = [
        {
            "role": "system",
            "content": GATEKEEPER_SYSTEM_PROMPT
        },
        {
            "role": "system",
            "content": PERSONALITY_PROMPT
        },
        {
            "role": "system",
            "content": user_pref
        },
        {
            "role": "system",
            "content": context
        },
        {
            "role": "user",
            "content": query
        }
    ]

    anwser = send_simple_query(messages, response_schema=BouncerAnswerFormat)

    return anwser


# %%


if __name__ == "__main__":

    u_id = "682596a5-7863-4419-9138-5f52c2779e61" 
    query = "I just quickly want to open insta to follow a colleague"

    answer = asyncio.run(ask_for_app_permission(u_id, query))
    print(answer)

# %%
