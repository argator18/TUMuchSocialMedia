import base64
from .helpers import *
from .prompts import *

async def check_goal_follow_through(
    user_id: str,
    logs,
    screenshot_b64: str | None = None,
):
    """
    Check whether current app behavior matches the given GOAL.

    logs: list[dict] or list[str] – will be serialized into text.
    screenshot_b64: base64-encoded image string of the current screen (optional).
    """

    user_name = get_name(user_id)

    user_pref, _, _ = get_user_preferences(user_id)

    # TODO users last request
    
    # Logs schön als Text
    if isinstance(logs, str):
        logs_text = logs
    else:
        logs_text = "\n".join([str(entry) for entry in logs])

    context_text = f"""
    CONTEXT:
    - User name: {user_name}

    LOGS (most recent last):
    {logs_text}
    """

    # ==============================
    #   Build multi-modal "input"
    # ==============================

    # System-Kontext: Gatekeeper + Goal Coach + Personality + User Prefs + Logs
    system_content = [
        {"type": "input_text", "text": GATEKEEPER_SYSTEM_PROMPT},
        {"type": "input_text", "text": GOAL_COACH_SYSTEM_PROMPT},
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

