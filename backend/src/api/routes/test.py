import re
import base64
import json
from fastapi import APIRouter, File, UploadFile, Form
from typing import Any, Dict
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import src.agent.agent as agent
import src.agent.supervisor as supervisor

router = APIRouter()


class UsageItem(BaseModel):
    packageName: str
    totalTimeForeground: int
    totalMinutes: int
    lastTimeUsed: Any

class BaseMessage(BaseModel):
    text: str
    usage: list[UsageItem]
    user_id: str
    
class OnboardInput(BaseModel):
    config: Dict[str, Any]


class SuperviseInput(BaseModel):
    text: list[dict] | Any # or list[ContextEvent]
    image: str | None = None
    

@router.post("/echo")
async def echo(msg: BaseMessage):
    agent_reply = await agent.ask_for_app_permission(
        user_id=msg.user_id,
        query=msg.text,
        app_usage=msg.usage
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )

@router.get("/todays_count")
async def todays_count(user_id: str):
    n = agent.get_request_number(user_id)
    response_count = {"daily_count": n}
    print(response_count)
    return response_count
    
@router.post("/onboard")
async def onboard(payload: OnboardInput):
    user_id = agent.add_user(payload.config)

    return JSONResponse(
        status_code=200,
        content={"user_id": user_id},
    )

    


@router.post("/voice")
async def voice(
    file: UploadFile = File(...),
    user_id: str = Form(...),
    usage: str = Form(None),  # JSON string, optional
):
    # ---- Read audio ----
    audio_bytes = await file.read()
    text = agent.transcribe_voice(audio_bytes)

    # ---- Parse usage JSON if provided ----
    usage_list = []
    if usage:
        try:
            parsed = json.loads(usage)
            usage_list = [UsageItem(**item) for item in parsed]
        except Exception as e:
            print("Usage parsing error:", e)

    # ---- Call your agent ----
    agent_reply = await agent.ask_for_app_permission(
        user_id=user_id,
        query=text,
        app_usage=usage_list
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )    

@router.post("/supervise")
async def supervise(payload: SuperviseInput):

    image_bytes = None

    # ---- Save the image if provided ----
    if payload.image:
        try:
            # decode base64
            image_bytes = base64.b64decode(payload.image)

            # generate file name
            file_name = f"img.png"

            # ensure directory exists
            import os
            os.makedirs("./supervise_images", exist_ok=True)

            # write file
            with open(file_name, "wb") as f:
                f.write(image_bytes)

            print("Saved screenshot to:", file_name)

        except Exception as e:
            print("Image save error:", e)

    # ---- Convert events to JSON string ----
    text_for_supervisor = json.dumps(payload.text)

    # ---- Call your supervisor logic ----
    agent_reply = await supervisor.check_goal_follow_through(
        "682596a5-7863-4419-9138-5f52c2779e61",
        text_for_supervisor,
        image_bytes           # still pass bytes if needed
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict()
    )