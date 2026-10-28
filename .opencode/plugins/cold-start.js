import { spawn } from "node:child_process";
import { join } from "node:path";

const BRIEF_TIMEOUT_MS = 20_000;
const HEADER = "Session-start context from scripts/cold-start.sh --brief (run /cold-start to refresh it mid-session):";

function failureNote(reason) {
  return `Session-start context unavailable (${reason}); run /cold-start to load it.`;
}

function readBrief(script, cwd, timeoutMs) {
  return new Promise((resolve) => {
    let settled = false;
    let child;
    let stdout = "";
    let stderr = "";
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
      finish({ ok: false, reason: `cold-start did not finish within ${Math.round(timeoutMs / 1000)} s` });
    }, timeoutMs);
    try {
      child = spawn("bash", [script, "--brief"], {
        cwd,
        env: process.env,
        stdio: ["ignore", "pipe", "pipe"],
        detached: true,
      });
    } catch (error) {
      finish({ ok: false, reason: `could not start cold-start: ${error.message}` });
      return;
    }
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => finish({ ok: false, reason: `could not start cold-start: ${error.message}` }));
    child.on("close", (code, signal) => {
      if (code === 0 && stdout.trim()) {
        finish({ ok: true, text: stdout.trim() });
        return;
      }
      const detail = code === null ? `signal ${signal}` : `exit ${code}`;
      const first = stderr.trim().split("\n")[0];
      finish({ ok: false, reason: first ? `cold-start ${detail}: ${first}` : `cold-start ${detail}` });
    });
  });
}

export const ColdStartPlugin = async (input = {}, options = {}) => {
  // Deliberate: a headless builder sets WS_RUN_EVENTS for its own event plugin; --pure cannot load that plugin,
  // so the builder runs without it and this guard keeps the session brief out of the builder's prompt.
  if (process.env.WS_RUN_EVENTS) return {};
  const opts = options ?? {};
  const cwd = input.directory ?? process.cwd();
  const script = opts.script ?? join(cwd, "scripts", "cold-start.sh");
  const timeoutMs = Number.isFinite(opts.timeoutMs) ? opts.timeoutMs : BRIEF_TIMEOUT_MS;
  const briefs = new Map();

  const briefFor = (sessionID) => {
    let brief = briefs.get(sessionID);
    if (brief === undefined) {
      brief = readBrief(script, cwd, timeoutMs).then((result) =>
        result.ok ? `${HEADER}\n${result.text}` : failureNote(result.reason),
      );
      briefs.set(sessionID, brief);
    }
    return brief;
  };

  return {
    // OpenCode calls this for every model request; the brief runs once per session and the cached text is
    // appended on each request, because each request gets a fresh system prompt.
    "experimental.chat.system.transform": async (input, output) => {
      const sessionID = input?.sessionID || "unknown";
      try {
        if (Array.isArray(output?.system)) output.system.push(await briefFor(sessionID));
      } catch (error) {
        const note = failureNote(`the plugin failed: ${error.message}`);
        if (Array.isArray(output?.system)) output.system.push(note);
      }
    },
  };
};
