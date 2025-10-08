import json
import time

import pytest
import websockets

uri = "ws://localhost:8765/ws"


@pytest.mark.asyncio
async def test_connection():
    """Test de verbinding met de WebSocket server."""

    try:
        print("Connecting to WebSocket server...")
        async with websockets.connect(uri) as websocket:
            print("Connected successfully!")
            assert websocket.ping_timeout > 1  # check if connection is bellow 1 seconds
            assert (
                websocket.ping_interval > 1
            )  # check if connection is bellow 1 seconds
    except Exception as e:
        pytest.fail(f"Failed to connect to WebSocket server: {e}")


@pytest.mark.asyncio
async def test_send_receive():
    """Test het verzenden en ontvangen van berichten via WebSocket."""

    try:
        print("Connecting to WebSocket server...")
        t0 = time.time()
        async with websockets.connect(uri) as websocket:
            print("Connected successfully!")
            start_command = {
                "type": "start",
                "script": "sinus.m",
                "params": [
                    5,
                    0.5,
                    0,
                    0.1,
                    1,
                ],  # [amplitude, frequency, start_time, time_step, end_time]
            }

            await websocket.send(json.dumps(start_command))
            response = await websocket.recv()

            # stop_command = {"type": "stop"}

            # await websocket.send(json.dumps(stop_command))
            # response = await websocket.recv()

            t1 = time.time()
            latency = t1 - t0
            print(f"Response from server: {response}")
            assert response is not None
            assert latency < 1  # check if response time is bellow 1 seconds
    except Exception as e:
        pytest.fail(f"Failed to connect to WebSocket server: {e}")
