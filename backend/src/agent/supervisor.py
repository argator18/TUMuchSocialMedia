import base64
from .helpers import *
from .prompts import *

async def check_goal_follow_through(
    user_id: str,
    handy_logs,
    screenshot_b64: str | None = None,
):
    """
    Check whether current app behavior matches the given GOAL.

    logs: list[dict] or list[str] – will be serialized into text.
    screenshot_b64: base64-encoded image string of the current screen (optional).
    """

    user_name = get_name(user_id)

    #user_pref, _, _ = get_user_preferences(user_id)

    # TODO users last request
    last_log = get_last_user_log(user_id)
    
    # Logs schön als Text
    if isinstance(handy_logs, str):
        handy_logs_str = handy_logs
    else:
        handy_logs_str = "\n".join([str(entry) for entry in handy_logs])

    context_text = f"""
    CONTEXT:
    - User name: {user_name}

    - most recent user query: {last_log}

    LOGS (most recent last):
    {handy_logs_str}
    """

    # ==============================
    #   Build multi-modal "input"
    # ==============================

    # System-Kontext: Gatekeeper + Goal Coach + Personality + User Prefs + Logs
    messages = [
        {
            "role": "system", 
            "content": GOAL_COACH_SYSTEM_PROMPT
        },
        {
            "role": "user", 
            "content": context_text
        },
        {
            "role": "user",
            "content": [
                { "type": "input_text", "text": "what's in this image?" },
                {
                    "type": "input_image",
                    "image_url": f"data:image/jpeg;base64,{screenshot_b64}",
                }
            ]
        }
    ]

    response = ask_with_image(messages)

    print(response)

    return response

