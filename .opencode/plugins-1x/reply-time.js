import { spawn } from "node:child_process";
import { join } from "node:path";

const TIMEOUT_MS = 5_000;

function runScript(script, text, cwd, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false;
    let child;
    let stdout = "";
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };
    const timer = setTimeout(() => {
      if (child?.pid) {
        try {
          process.kill(-child.pid, "SIGKILL");
        } catch {
          child.kill("SIGKILL");
        }
      }
      finish({ ok: false, reason: `reply-time-check did not finish within ${Math.round(timeoutMs / 1000)} s` });
    }, timeoutMs);
    try {
      child = spawn("bash", [script], {
        cwd,
        env: process.env,
        stdio: ["pipe", "pipe", "pipe"],
        detached: true,
      });
    } catch (error) {
      finish({ ok: false, reason: `could not start reply-time-check: ${error.message}` });
      return;
    }
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", () => {});
    child.on("error", (error) => finish({ ok: false, reason: `could not start reply-time-check: ${error.message}` }));
    child.on("close", (code) => {
      // The script always exits 0; a warning is what it writes on stdout.
      if (code === 0) finish({ ok: true, warning: stdout.trim() });
      else finish({ ok: false, reason: `reply-time-check exit ${code}` });
    });
    // The script may exit before reading stdin, so a write failure must not surface as an unhandled error.
    child.stdin.on("error", () => {});
    child.stdin.end(text);
  });
}

export const ReplyTimePlugin = async (input = {}, options = {}) => {
  // Deliberate: a headless builder sets WS_RUN_EVENTS for its own event plugin and sees no warning appended to the
  // result it returns, so the check runs in an orchestrator session only.
  if (process.env.WS_RUN_EVENTS) return {};
  const opts = options ?? {};
  const cwd = input.directory ?? process.cwd();
  const script = opts.script ?? join(cwd, "scripts", "reply-time-check.sh");
  const timeoutMs = Number.isFinite(opts.timeoutMs) ? opts.timeoutMs : TIMEOUT_MS;
  const warned = new Set();

  return {
    // Called when a text part finishes. The warning goes on as its own paragraph, at most once per message, and a
    // reply with no warning is left byte-for-byte unchanged.
    "experimental.text.complete": async (input, output) => {
      if (typeof output?.text !== "string") return;
      const key = input?.messageID || `${input?.sessionID ?? "unknown"}:${input?.partID ?? "unknown"}`;
      if (warned.has(key)) return;
      const result = await runScript(script, output.text, cwd, timeoutMs);
      if (!result.ok || !result.warning) return;
      warned.add(key);
      const text = output.text.trimEnd();
      output.text = text ? `${text}\n\n${result.warning}` : result.warning;
    },
  };
};
