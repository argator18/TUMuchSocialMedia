from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()

class Message(BaseModel):
    text: str

@router.post("/echo")
async def echo(msg: Message):
    return {"received": msg.text + "\t fabi du geile sau"}
