#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "httpx",
#     "g4f>=7.7.1",
#     "curl-cffi>=0.15.0",
# ]
# ///
"""
pShell AI backend.  Listens on a Unix socket, validates session token,
streams responses as newline-delimited JSON:
  {"type":"delta",  "text":"…"}
  {"type":"done",   "inputTokens":N, "outputTokens":M}
  {"type":"error",  "message":"…"}
  {"type":"models", "models":[…]}     (for discovery actions)
"""
import asyncio, json, os, signal, sys
from pathlib import Path

import httpx

SESSION_TOKEN = os.environ.get("QS_AI_TOKEN", "")
SOCKET_PATH   = os.environ.get("QS_AI_SOCKET", "/tmp/quickshell-ai.sock")

# ── Provider helpers ─────────────────────────────────────────────────────────

async def stream_openai(endpoint: str, api_key: str, payload: dict):
    headers = {"Content-Type": "application/json",
               "Authorization": f"Bearer {api_key}"}
    payload = {**payload, "stream": True}
    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream("POST", endpoint, headers=headers, json=payload) as r:
            if r.status_code != 200:
                body = await r.aread()
                yield {"type": "error", "message": f"HTTP {r.status_code}: {body.decode()[:300]}"}
                return
            in_think = False
            in_tokens = out_tokens = -1
            async for line in r.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data = line[6:].strip()
                if data == "[DONE]":
                    break
                try:
                    obj = json.loads(data)
                    if "error" in obj:
                        yield {"type": "error", "message": obj["error"].get("message", str(obj["error"]))}
                        return
                    delta = obj.get("choices", [{}])[0].get("delta", {})
                    reasoning = delta.get("reasoning") or delta.get("reasoning_content") or ""
                    text      = delta.get("content") or ""
                    if reasoning:
                        if not in_think:
                            in_think = True
                            yield {"type": "delta", "text": "\n\n<think>\n\n"}
                        yield {"type": "delta", "text": reasoning}
                    if text:
                        if in_think:
                            in_think = False
                            yield {"type": "delta", "text": "\n\n</think>\n\n"}
                        yield {"type": "delta", "text": text}
                    if obj.get("usage"):
                        u = obj["usage"]
                        in_tokens  = u.get("prompt_tokens", -1)
                        out_tokens = u.get("completion_tokens", -1)
                except Exception:
                    pass
            # Most providers never send `usage` in the stream — always emit
            # `done` so the client isn't left waiting for a terminator.
            yield {"type": "done", "inputTokens": in_tokens, "outputTokens": out_tokens}


async def stream_anthropic(api_key: str, payload: dict):
    messages = payload.get("messages", [])
    system   = next((m["content"] for m in messages if m["role"] == "system"), None)
    body = {
        "model":      payload["model"],
        "max_tokens": payload.get("maxTokens", 8192),
        "messages":   [m for m in messages if m["role"] != "system"],
        "stream":     True,
    }
    if system:
        body["system"] = system
    headers = {"x-api-key": api_key, "anthropic-version": "2023-06-01",
                "content-type": "application/json"}
    async with httpx.AsyncClient(timeout=120.0) as client:
        async with client.stream("POST", "https://api.anthropic.com/v1/messages",
                                  headers=headers, json=body) as r:
            if r.status_code != 200:
                b = await r.aread()
                yield {"type": "error", "message": f"HTTP {r.status_code}: {b.decode()[:300]}"}
                return
            in_tokens = out_tokens = -1
            async for line in r.aiter_lines():
                if not line.startswith("data: "):
                    continue
                try:
                    obj = json.loads(line[6:])
                    t = obj.get("type", "")
                    if t == "content_block_delta":
                        text = obj.get("delta", {}).get("text", "")
                        if text:
                            yield {"type": "delta", "text": text}
                    elif t == "message_start":
                        u = obj.get("message", {}).get("usage", {})
                        in_tokens = u.get("input_tokens", -1)
                    elif t == "message_delta":
                        u = obj.get("usage", {})
                        out_tokens = u.get("output_tokens", -1)
                    elif t == "message_stop":
                        break
                except Exception:
                    pass
    yield {"type": "done", "inputTokens": in_tokens, "outputTokens": out_tokens}


async def stream_g4f(model_name: str, messages: list):
    # Uses the modern client API: the legacy g4f.ChatCompletion path is broken
    # in g4f 7.x ("'str' object has no attribute 'working'").
    try:
        from g4f.client import AsyncClient
        client = AsyncClient()
        # With stream=True this returns an async generator (not awaitable).
        response = client.chat.completions.create(
            messages=messages,
            model=model_name,
            stream=True,
        )
        async for chunk in response:
            try:
                delta = chunk.choices[0].delta.content
            except (AttributeError, IndexError):
                delta = None
            if delta:
                yield {"type": "delta", "text": delta}
        yield {"type": "done", "inputTokens": -1, "outputTokens": -1}
    except Exception as e:
        yield {"type": "error", "message": str(e)}


async def get_ollama_models() -> list[str]:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get("http://localhost:11434/api/tags")
            if r.status_code == 200:
                return [m["name"] for m in r.json().get("models", [])]
    except Exception:
        pass
    return []


def _g4f_free_map() -> dict[str, list]:
    """model name -> keyless candidate provider classes (text models only).

    ModelUtils.convert is keyed by the REAL model names g4f accepts
    (e.g. "o4-mini-high"); dir(g4f.models) would give the python attribute
    names ("o4_mini_high"), which g4f rejects. Model.best_provider.providers
    holds provider NAMES (strings) in g4f 7.x — resolve them through the
    provider map to read the class attributes (working / needs_auth).
    """
    import g4f.models as gm
    import g4f.Provider as gp
    from g4f.models import ModelUtils

    mapping = getattr(gp, "__map__", None) or gp.ProviderUtils.convert

    # Text chat only — image/audio/video models can't be rendered here.
    non_text = tuple(t for t in (
        getattr(gm, "ImageModel", None),
        getattr(gm, "AudioModel", None),
        getattr(gm, "VideoModel", None),
    ) if t is not None)

    out: dict[str, list] = {}
    for name, model in ModelUtils.convert.items():
        if non_text and isinstance(model, non_text):
            continue
        bp = model.best_provider
        if bp is None:
            continue
        provs = getattr(bp, "providers", None) or [bp]
        keyless = []
        for p in provs:
            if isinstance(p, str):
                p = mapping.get(p)
            if p is not None and getattr(p, "working", False) \
                    and not getattr(p, "needs_auth", False):
                keyless.append(p)
        if keyless:
            out[name] = keyless
    return out


def get_g4f_models() -> list[str]:
    """Fast attribute-based list (optimistic; some providers lie)."""
    try:
        names = sorted(_g4f_free_map().keys())
        if names:
            return names
    except Exception:
        pass
    return ["gpt-4", "gpt-4o-mini", "gemini-pro", "llama-3-70b"]


# Providers verified alive this session ({name: bool}); probed once.
_g4f_alive: dict[str, bool] | None = None

PROBE_TIMEOUT = 20.0


async def _probe_provider(cls) -> bool:
    """One tiny real request through a single provider. The class attributes
    (needs_auth etc.) are unreliable — e.g. HuggingFace claims keyless but
    raises MissingAuthError at call time — so only a live answer counts."""
    try:
        from g4f.client import AsyncClient
        model = getattr(cls, "default_model", "") \
            or (getattr(cls, "models", None) or [""])[0]
        client = AsyncClient(provider=cls)
        response = client.chat.completions.create(
            messages=[{"role": "user", "content": "Hi"}],
            model=model,
            stream=True,
        )

        async def read_first():
            async for chunk in response:
                try:
                    if chunk.choices[0].delta.content:
                        return True
                except (AttributeError, IndexError):
                    pass
            return False

        return bool(await asyncio.wait_for(read_first(), timeout=PROBE_TIMEOUT))
    except Exception:
        return False


async def get_g4f_models_live() -> list[str]:
    """Models with at least one provider that actually answered a probe.

    Providers driving a browser (use_nodriver) are NOT probed — a probe could
    pop a Chrome window on the user's desktop — and are kept optimistically
    (OpenaiChat serves fine in practice). Results are cached per server run.
    """
    global _g4f_alive
    try:
        free_map = _g4f_free_map()

        classes = {}
        for provs in free_map.values():
            for p in provs:
                classes[p.__name__] = p

        if _g4f_alive is None:
            probed: dict[str, bool] = {}
            names, tasks = [], []
            for name, cls in classes.items():
                if getattr(cls, "use_nodriver", False):
                    probed[name] = True   # optimistic, unprobeable
                    continue
                names.append(name)
                tasks.append(_probe_provider(cls))
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for name, res in zip(names, results):
                probed[name] = res is True
            _g4f_alive = probed

        alive = _g4f_alive
        return sorted(n for n, provs in free_map.items()
                      if any(alive.get(p.__name__, False) for p in provs))
    except Exception:
        return []


# ── Request dispatcher ────────────────────────────────────────────────────────

async def dispatch(request: dict):
    action = request.get("action", "chat")

    if action == "models_ollama":
        models = await get_ollama_models()
        yield {"type": "models", "models": models}
        yield {"type": "done"}
        return

    if action == "models_g4f":
        # Two-stage: the fast attribute-based list immediately, then the
        # probe-verified list once live checks finish (the client applies
        # every `models` line it receives, so the picker just refines).
        yield {"type": "models", "models": get_g4f_models()}
        live = await get_g4f_models_live()
        if live:
            yield {"type": "models", "models": live}
        yield {"type": "done"}
        return

    fmt      = request.get("format", "openai")
    model    = request.get("model", "")
    messages = request.get("messages", [])
    api_key  = request.get("apiKey", "")
    endpoint = request.get("endpoint", "")

    if fmt == "anthropic":
        gen = stream_anthropic(api_key, {
            "model": model, "messages": messages,
            "maxTokens": request.get("maxTokens", 8192),
        })
    elif fmt == "g4f":
        gen = stream_g4f(model, messages)
    else:
        payload = {
            "model":       model,
            "messages":    messages,
            "temperature": request.get("temperature", 0.7),
        }
        if request.get("maxTokens"):
            payload["max_tokens"] = request["maxTokens"]
        gen = stream_openai(endpoint, api_key, payload)

    async for chunk in gen:
        yield chunk


# ── Socket server ─────────────────────────────────────────────────────────────

async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    try:
        raw = await reader.readline()
        if not raw:
            return
        request = json.loads(raw.decode("utf-8"))

        if request.get("token") != SESSION_TOKEN:
            writer.write(json.dumps({"type": "error", "message": "Unauthorized"}).encode() + b"\n")
            await writer.drain()
            return

        async for chunk in dispatch(request):
            writer.write(json.dumps(chunk).encode() + b"\n")
            await writer.drain()

    except Exception as e:
        try:
            writer.write(json.dumps({"type": "error", "message": str(e)}).encode() + b"\n")
            await writer.drain()
        except Exception:
            pass
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def watch_parent():
    """Exit when the parent (quickshell) dies — otherwise a shell restart
    leaves an orphaned server running forever with a stale token."""
    parent = os.getppid()
    while True:
        await asyncio.sleep(5)
        if os.getppid() != parent:
            os._exit(0)


def sweep_stale_sockets():
    """Remove leftover sockets of dead servers (a hard-killed server — e.g.
    on quickshell reload — never reaches its unlink)."""
    import socket as s
    for p in Path(SOCKET_PATH).parent.glob("quickshell-ai-*.sock"):
        if str(p) == SOCKET_PATH:
            continue
        try:
            c = s.socket(s.AF_UNIX)
            c.settimeout(0.2)
            c.connect(str(p))
            c.close()          # alive — leave it
        except OSError:
            try:
                p.unlink()
            except OSError:
                pass


async def main():
    if not SESSION_TOKEN:
        print("Error: QS_AI_TOKEN not set", file=sys.stderr, flush=True)
        sys.exit(1)

    sock = Path(SOCKET_PATH)
    sock.parent.mkdir(parents=True, exist_ok=True)
    if sock.exists():
        sock.unlink()
    sweep_stale_sockets()

    server = await asyncio.start_unix_server(handle_client, path=SOCKET_PATH)
    os.chmod(SOCKET_PATH, 0o600)

    print(f"ready:{SOCKET_PATH}", flush=True)

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, server.close)

    asyncio.ensure_future(watch_parent())

    try:
        async with server:
            await server.serve_forever()
    except asyncio.CancelledError:
        pass
    finally:
        if sock.exists():
            sock.unlink()


asyncio.run(main())
