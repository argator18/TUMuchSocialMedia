#%%  
import os
import asyncio

from .helpers import *
from .prompts import *

def parse_usage(usage_list, tracked_apps):
    """
    usage_list: list of dicts from Android (packageName, totalTimeForeground, lastTimeUsed)
    tracked_apps: list of lowercase app names you care about,
                  e.g. ["instagram", "tiktok", "youtube"]
    """

    tracked_apps = [a.lower() for a in tracked_apps]



    # STEP 1 — Filter packages
    filtered = []
    for item in usage_list:
        pkg = item.packageName.lower()

        # keep package if one of your app names appears in the packageName
        for app in tracked_apps:
            if app in pkg:
                filtered.append(
                    {"app": app, "minutes": item.totalMinutes}
                )

    lines = []
    for item in filtered:
        app = item["app"]
        minutes = item.get("minutes", 0)

        lines.append(
            f"App: {app} - used time: {minutes} min"
        )

    # STEP 3 — Final output
    if not lines:
        return "No usage found for tracked apps."

    return "\n".join(lines)


# ==================================
#           Agents
# ==================================

# %%
async def analyzer_user_behaviour(user_id: str, past_day: int):
    pass

async def ask_for_app_permission(user_id: str, query: str, app_usage):

    # for testing
    #user_preferences = "The user asking is Tim. He is very ambitionate and in his exam period and want you to be very strict with him"
    user_name = get_name(user_id)
    user_pref, user_fav_personality, apps = get_user_preferences(user_id)

    PERSONALITY_PROMPT = PERSONALITY_MAP[user_fav_personality]

    parsed_usage = parse_usage(app_usage, apps)
    # TODO add a database for this

    user_log = get_user_log(user_id, time_delay=24)

    time = datetime.now().strftime("%H:%M")

    # TODO add here user app usage statistics
    context = f"""
    CONTEXT:

    current time: {time}

    The users name is: {user_name}

    The user has the following history of asking for allowance for the day:     

    {user_log} 

    The user has the following app usage times for today for the apps in his preferences

    {parsed_usage}

    """

    print(user_pref)
    print(context)

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

    answer = send_simple_query(messages, response_schema=BouncerAnswerFormat)

    update_log(user_id, query, answer.dict())

    return answer


# %%
def main():
    mikey = "682596a5-7863-4419-9138-5f52c2779e61" 
    #donatello = "ab7b6c53-f4b0-4238-ac64-da383193425d"
    #query = "I just scrolled for 10 minuts and would like some more"
    query = input("Type the query: ")

    answer = asyncio.run(ask_for_app_permission(mikey, query, []))
    print(answer)

if __name__ == "__main__":
    main()


# %%
