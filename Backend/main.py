import asyncio
import json
from contextlib import asynccontextmanager
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import uvicorn
import pycrc


# ── Connection Manager ──────────────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    def has_clients(self) -> bool:
        return len(self.active_connections) > 0

    async def broadcast(self, message: str):
        for connection in list(self.active_connections):
            try:
                await connection.send_text(message)
            except Exception:
                pass


# ── Modbus TCP Connection (persistent) ─────────────────────────────────────
class ModbusConnection:
    """Maintains a single persistent TCP socket to the Modbus device."""

    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port
        self._reader: Optional[asyncio.StreamReader] = None
        self._writer: Optional[asyncio.StreamWriter] = None
        self._lock = asyncio.Lock()

    async def _ensure_connected(self):
        if self._writer is not None and not self._writer.is_closing():
            return
        self._reader, self._writer = await asyncio.wait_for(
            asyncio.open_connection(self.host, self.port), timeout=3.0
        )

    async def transaction(self, cmd: bytearray) -> Optional[bytearray]:
        """Send cmd, return response. Reconnects automatically on failure."""
        async with self._lock:
            for attempt in range(2):
                try:
                    await self._ensure_connected()
                    self._writer.write(cmd)
                    await self._writer.drain()
                    resp = await asyncio.wait_for(self._reader.read(1024), timeout=2.0)
                    return bytearray(resp)
                except Exception as e:
                    # Force reconnect on next attempt
                    self._reader = None
                    self._writer = None
                    if attempt == 1:
                        raise e
            return None

    async def close(self):
        if self._writer:
            self._writer.close()
            try:
                await self._writer.wait_closed()
            except Exception:
                pass


# ── Globals ─────────────────────────────────────────────────────────────────
MODBUS_IP = "127.0.0.1"
MODBUS_PORT = 4196
DEVICE_ADDRESS = 0x01

manager = ConnectionManager()
modbus = ModbusConnection(MODBUS_IP, MODBUS_PORT)
relays_state: List[bool] = [False] * 8


# ── Helpers ─────────────────────────────────────────────────────────────────
def make_cmd(func: int, subaddr: int, value: int) -> bytearray:
    cmd = [0] * 8
    cmd[0] = DEVICE_ADDRESS
    cmd[1] = func
    cmd[2] = 0x00
    cmd[3] = subaddr
    cmd[4] = (value >> 8) & 0xFF
    cmd[5] = value & 0xFF
    crc = pycrc.ModbusCRC(cmd[0:6])
    cmd[6] = crc & 0xFF
    cmd[7] = crc >> 8
    return bytearray(cmd)


async def broadcast_log(kind: str, hex_str: str = "", description: str = ""):
    if not manager.has_clients():
        return  # No one listening — skip the broadcast overhead
    now = datetime.now().strftime("%H:%M:%S")
    entry = {"time": now, "kind": kind, "hex": hex_str, "description": description}
    await manager.broadcast(json.dumps({"type": "log", "entry": entry}))


async def modbus_transaction(
    cmd: bytearray, tx_description: str = ""
) -> Optional[bytearray]:
    tx_hex = " ".join(f"{b:02X}" for b in cmd)
    await broadcast_log("TX", tx_hex, tx_description)
    try:
        resp = await modbus.transaction(cmd)
        rx_hex = " ".join(f"{b:02X}" for b in resp)
        await broadcast_log("RX", rx_hex)
        return resp
    except Exception as e:
        await broadcast_log("ERROR", "", str(e))
        return None


# ── Background Poller ───────────────────────────────────────────────────────
async def read_and_push_state() -> bool:
    """Read coils silently and push state to clients only if it changed. Returns True on success."""
    global relays_state
    cmd = make_cmd(0x01, 0x00, 0x08)
    try:
        resp = await modbus.transaction(cmd)
    except Exception:
        return False
    if resp and len(resp) >= 4:
        status = resp[3]
        new_state = [(status & (1 << i)) != 0 for i in range(8)]
        if new_state != relays_state:
            relays_state = new_state
            await manager.broadcast(json.dumps({"type": "state", "data": relays_state}))
        return True
    return False


async def poll_modbus():
    """Background poller: silent read every second. Only broadcasts on actual state change.
    No TX/RX log spam — the console is only for user-initiated commands."""
    while True:
        await asyncio.sleep(1)
        await read_and_push_state()


# ── Lifespan ─────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(_: FastAPI):
    task = asyncio.create_task(poll_modbus())
    yield
    task.cancel()
    await modbus.close()


app = FastAPI(lifespan=lifespan)


# ── WebSocket Endpoint ───────────────────────────────────────────────────────
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    await websocket.send_text(json.dumps({"type": "state", "data": relays_state}))
    try:
        while True:
            data = await websocket.receive_text()
            cmd_data = json.loads(data)

            if cmd_data.get("command") == "write":
                relay_idx = int(cmd_data.get("relay", 0))
                value_str = cmd_data.get("value", "").lower()
                is_on = value_str == "on"
                value = 0xFF00 if is_on else 0x0000
                cmd = make_cmd(0x05, relay_idx, value)
                description = f"Write Single Coil — Relay {relay_idx + 1} {'ON' if is_on else 'OFF'}"

                resp = await modbus_transaction(cmd, description)
                if resp:
                    await broadcast_log(
                        "INFO",
                        "",
                        f"Relay {relay_idx + 1} switched to {'ON' if is_on else 'OFF'}",
                    )
                    # Immediately read back state so clients confirm/correct
                    await read_and_push_state()

    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        print(f"[Backend] WebSocket error: {e}")
        manager.disconnect(websocket)


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8192, ws="wsproto")
