import os

import httpx
import uvicorn
from fastapi import FastAPI, Request

app = FastAPI()

BOT_TOKEN = os.getenv("BOT_TOKEN")
CHAT_ID = os.getenv("CHAT_ID")


async def send_telegram(text: str):
    if not BOT_TOKEN or not CHAT_ID:
        print("Missing Telegram Credentials!")
        return

    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": CHAT_ID,
        "text": text,
        "parse_mode": "HTML",
    }

    async with httpx.AsyncClient() as client:
        await client.post(url, json=payload)


@app.get("/health")
async def health_check():
    """Route targeted by keep-alive pings."""
    return {"status": "ok"}


@app.post("/webhook")
async def receive_alert(request: Request):
    data = await request.json()

    symbol = data.get("symbol", "UNKNOWN")
    action = data.get("action", "ALERT")
    price = data.get("price", 0.0)

    formatted_msg = (
        f"🌊 <b>{action.upper()} Alert</b>\n"
        f"<b>Asset:</b> {symbol}\n"
        f"<b>Price:</b> {price}\n"
        f"<b>Status:</b> Webhook processed."
    )

    await send_telegram(formatted_msg)
    return {"status": "success"}


if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
