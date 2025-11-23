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
    message = [
        {
            "role": "system", 
            "content": SUPER
        },
        {
            "role": "system", 
            "content": context_text
        },
        {
            "role": "user",
            "content": [
                { "type": "input_text", "text": "what's in this image?" },
                {
                    "type": "input_image",
                    "image_url": f"data:image/jpeg;base64,{base64_image}",
                }
            ]
        }
    ]

    

    if user_pref:
        system_content.append({"type": "input_text", "text": user_pref})

    system_content.append({"type": "input_text", "text": context_text})

    # User-Nachricht: Aufgabe + optional Screenshot als Bild
    user_content = [
        {
            "type": "input_text",
            "text": (
                "Evaluate whether my current behavior matches the GOAL, "
                "using the LOGS and the current SCREEN. "
                "Respond ONLY with the required JSON structure."
            ),
        }
    ]

    if screenshot_b64 is not None:
        user_content.append(
            {
                "type": "input_image",
                "image_url": {
                    "url": f"data:image/png;base64,{screenshot_b64}"
                },
            }
        )

    vision_input = [
        {
            "role": "system",
            "content": system_content,
        },
        {
            "role": "user",
            "content": user_content,
        },
    ]

    # ==============================
    #   Call GPT-5.1 mit Vision
    # ==============================

    response = client.responses.parse(
        model="gpt-5-nano",                 # <--- hier dein Vision-Modell
        input=vision_input,
        text_format=GoalFeedbackFormat,  # Pydantic Schema
    )

    return response.output_parsed

