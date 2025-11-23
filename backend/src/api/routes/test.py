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
    minutesUsed: int

class BaseMessage(BaseModel):
    text: str
    usage: list[UsageItem]
    user_id: str
    
class OnboardInput(BaseModel):
    config: Dict[str, Any]


class SuperviseInput(BaseModel):
    text: list[dict]  # or list[ContextEvent]
    image: str | None = None
    

@router.post("/echo")
async def echo(msg: BaseMessage):
    agent_reply = await agent.ask_for_app_permission(
        user_id=msg.user_id,
        msg.text,
        app_usage=msg.usage
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )
    
    
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
):
    audio_bytes = await file.read()
    text = agent.transcribe_voice(audio_bytes)

    agent_reply = await agent.ask_for_app_permission(
        "682596a5-7863-4419-9138-5f52c2779e61",
        text,
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )
    

@router.post("/supervise")
async def supervise(payload: SuperviseInput):
    print("payload:", payload, flush=True)

    image_bytes = None
    if payload.image:
        b64 = payload.image
        image_bytes = base64.b64decode(b64)

    # convert the structured events into something your supervisor expects
    text_for_supervisor = json.dumps(payload.text)

    agent_reply = await supervisor.check_goal_follow_through(
        "682596a5-7863-4419-9138-5f52c2779e61",
        "Answering messages in 5 minutes",
        text_for_supervisor,
        image_bytes,
    )

    return JSONResponse(status_code=200, content=agent_reply.dict(),)

