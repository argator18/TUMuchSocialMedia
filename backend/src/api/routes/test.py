from fastapi import APIRouter, File, UploadFile, Form
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import src.agent.agent as agent
import src.agent.supervisor as supervisor

router = APIRouter()

class Message(BaseModel):
    text: str


@router.post("/echo")
async def echo(msg: Message):
    agent_reply = await agent.ask_for_app_permission(
        "682596a5-7863-4419-9138-5f52c2779e61",
        msg.text,
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )
    

@router.post("/voice")
async def voice(
    audio: UploadFile = File(...),
    text: str | None = Form(None),
):
    audio_bytes = await audio.read()
    # TODO: pass audio_bytes to your speech-to-text or other processing

    # Fallback text if none is provided
    if text is None:
        text = "User sent a voice message."

    agent_reply = await agent.ask_for_app_permission(
        "682596a5-7863-4419-9138-5f52c2779e61",
        text,
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict(),
    )


@router.post("/supervise")
async def supervise(
    text: str = Form(...),
    image: UploadFile | None = File(None),
):
    # Receive image
    if image is not None:
        image_bytes = await image.read()
        supervisor.check_goal_follow_through(
            "682596a5-7863-4419-9138-5f52c2779e61",
            "Answering messages in 5 minutes",
            text,
            image_bytes
        )

    return JSONResponse(
        status_code=200,
        content=text.dict(),
    )
