"""Reading a builder's run log (runs/<slug>/<name>.jsonl), Claude's stream-json or OpenCode's events; used by audit.py
and bench.py."""
import json


def events(path):
    """Each JSON event of a run log. A line cut off mid-write (a killed run) is skipped."""
    with open(path, errors="replace") as fh:
        for line in fh:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if isinstance(event, dict):
                yield event


def context_tokens(usage):
    return sum(usage.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))


def step_usage(tokens):
    """An OpenCode step_finish's tokens in the shape of a Claude message's usage."""
    cache = tokens.get("cache") or {}
    return {"input_tokens": tokens.get("input"), "output_tokens": tokens.get("output"),
            "cache_read_input_tokens": cache.get("read"), "cache_creation_input_tokens": cache.get("write")}


def run_metrics(path):
    """Turns, context, tokens, cost, minutes and denied calls of one run.

    A message is logged once per content block, each copy with its usage, so context is counted once per message
    id (the last copy's). OpenCode logs one step_finish per model call, and each is one turn. Without a result event
    (a killed run) the totals come from the messages, and cost, minutes and denials are unknown (empty).
    """
    per_message, result = {}, None
    for event in events(path):
        if event.get("type") == "assistant":
            message = event.get("message") or {}
            if message.get("usage"):
                per_message[message.get("id") or f"anonymous-{len(per_message)}"] = message["usage"]
        elif event.get("type") == "step_finish":
            part = event.get("part") or {}
            if part.get("tokens"):
                per_message[part.get("id") or f"anonymous-{len(per_message)}"] = step_usage(part["tokens"])
        elif event.get("type") == "result":
            result = event
    contexts = [context_tokens(u) for u in per_message.values()]
    out = {
        "turns": len(per_message),
        "peak_context": max(contexts, default=0),
        "mean_context": round(sum(contexts) / len(contexts)) if contexts else 0,
        "output_tokens": sum(u.get("output_tokens") or 0 for u in per_message.values()),
        "cache_reads": sum(u.get("cache_read_input_tokens") or 0 for u in per_message.values()),
        "cost": "", "minutes": "", "denied": "",
    }
    if result is not None:
        usage = result.get("usage") or {}
        out["turns"] = result.get("num_turns", out["turns"])
        out["output_tokens"] = usage.get("output_tokens", out["output_tokens"])
        out["cache_reads"] = usage.get("cache_read_input_tokens", out["cache_reads"])
        if result.get("total_cost_usd") is not None:
            out["cost"] = round(result["total_cost_usd"], 4)
        if result.get("duration_ms") is not None:
            out["minutes"] = round(result["duration_ms"] / 60000, 1)
        out["denied"] = len(result.get("permission_denials") or [])
    return out
