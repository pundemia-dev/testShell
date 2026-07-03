#!/usr/bin/env python3
"""
Minimal AI request client — stdlib only, starts instantly.
Usage: QS_AI_TOKEN=… python3 ai_client.py SOCKET_PATH
Reads one JSON request line from stdin (keeps the request out of argv and
shared files), sends it to the server, streams JSON lines to stdout.
"""
import asyncio, json, os, sys


async def main():
    if len(sys.argv) < 2:
        print(json.dumps({"type": "error", "message": "Usage: ai_client.py SOCKET_PATH"}), flush=True)
        return

    sock_path = sys.argv[1]
    token = os.environ.get("QS_AI_TOKEN", "")

    try:
        request = json.loads(sys.stdin.readline())
    except Exception as e:
        print(json.dumps({"type": "error", "message": f"Cannot read request: {e}"}), flush=True)
        return

    request["token"] = token

    try:
        reader, writer = await asyncio.open_unix_connection(sock_path)
    except (FileNotFoundError, ConnectionRefusedError):
        print(json.dumps({"type": "error", "message": "AI server not running"}), flush=True)
        return
    except Exception as e:
        print(json.dumps({"type": "error", "message": str(e)}), flush=True)
        return

    try:
        writer.write(json.dumps(request).encode() + b"\n")
        await writer.drain()

        async for line in reader:
            if line:
                sys.stdout.buffer.write(line)
                sys.stdout.buffer.flush()
    except Exception as e:
        print(json.dumps({"type": "error", "message": str(e)}), flush=True)
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


asyncio.run(main())
