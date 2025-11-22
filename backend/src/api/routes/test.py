from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import src.agent.agent as agent

router = APIRouter()

class Message(BaseModel):
    text: str

@router.post("/echo")
async def echo(msg: Message):
    agent_reply = await agent.ask_for_app_permission(
        "682596a5-7863-4419-9138-5f52c2779e61",
        msg.text
    )

    return JSONResponse(
        status_code=200,
        content=agent_reply.dict()
    )
