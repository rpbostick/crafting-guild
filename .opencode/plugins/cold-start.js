import { spawn } from "node:child_process";
import { readdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const BRIEF_TIMEOUT_MS = 20_000;
const HEADER = "Session-start context from scripts/cold-start.sh --brief (run /cold-start to refresh it mid-session):";
const MEMORY_HEADER = "Standing memory from WS_MEMORY_DIR, read-only: the MEMORY.md index, then each feedback memory in full.";
const MEMORY_INDEX = "MEMORY.md";

function failureNote(reason) {
  return `Session-start context unavailable (${reason}); run /cold-start to load it.`;
}

function memoryFailureNote(reason) {
  return `Memory unavailable (${String(reason).split("\n")[0]}); this session has no standing memory.`;
}

// Only the type line and the body matter here, and a plugin carries no YAML dependency, so frontmatter is read by line.
function parseMemory(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(text);
  if (!match) return null;
  const type = /^\s*type:\s*["']?([\w-]+)["']?\s*$/m.exec(match[1])?.[1];
  return { type, body: text.slice(match[0].length).trim() };
}

function fitIndex(index, cap) {
  const lines = index.split("\n");
  const kept = [];
  let used = 0;
  for (const line of lines) {
    if (used + line.length + 1 > cap) break;
    kept.push(line);
    used += line.length + 1;
  }
  const note = kept.length < lines.length ? `${MEMORY_INDEX} cut to ${kept.length} of ${lines.length} lines by WS_MEMORY_CAP.` : null;
  return { text: kept.join("\n"), used, note };
}

async function readMemory(dir, cap) {
  const index = fitIndex((await readFile(join(dir, MEMORY_INDEX), "utf8")).trim(), cap);
  const names = (await readdir(dir)).filter((name) => name.endsWith(".md") && name !== MEMORY_INDEX).sort();
  const notes = index.note ? [index.note] : [];
  const bodies = [];
  const dropped = [];
  let used = index.used;
  for (const name of names) {
    let memory;
    try {
      memory = parseMemory(await readFile(join(dir, name), "utf8"));
    } catch (error) {
      notes.push(`${name} could not be read: ${error.code ?? error.message}.`);
      continue;
    }
    if (!memory) notes.push(`${name} has no frontmatter, so it was not loaded.`);
    else if (!memory.type) notes.push(`${name} has no type, so it was not loaded.`);
    if (memory?.type !== "feedback") continue;
    const block = `## ${name}\n${memory.body}`;
    if (used + block.length + 2 > cap) {
      dropped.push(name);
      continue;
    }
    bodies.push(block);
    used += block.length + 2;
  }
  if (dropped.length) notes.push(`WS_MEMORY_CAP (${cap} characters) dropped ${dropped.join(", ")}; read them from ${dir}.`);
  return [MEMORY_HEADER, index.text, ...bodies, ...notes].join("\n\n");
}

function runScript(name, script, args, cwd, timeoutMs) {
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
      finish({ ok: false, reason: `${name} did not finish within ${Math.round(timeoutMs / 1000)} s` });
    }, timeoutMs);
    try {
      child = spawn("bash", [script, ...args], {
        cwd,
        env: process.env,
        stdio: ["ignore", "pipe", "pipe"],
        detached: true,
      });
    } catch (error) {
      finish({ ok: false, reason: `could not start ${name}: ${error.message}` });
      return;
    }
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => finish({ ok: false, reason: `could not start ${name}: ${error.message}` }));
    child.on("close", (code, signal) => {
      if (code === 0 && stdout.trim()) {
        finish({ ok: true, text: stdout.trim() });
        return;
      }
      const detail = code === null ? `signal ${signal}` : `exit ${code}`;
      const first = stderr.trim().split("\n")[0];
      finish({ ok: false, reason: first ? `${name} ${detail}: ${first}` : `${name} ${detail}` });
    });
  });
}

export const ColdStartPlugin = async (input = {}, options = {}) => {
  // Deliberate: a headless builder sets WS_RUN_EVENTS for its own event plugin; --pure cannot load that plugin,
  // so the builder runs without it and this guard keeps the session brief and the memory out of the builder's prompt.
  if (process.env.WS_RUN_EVENTS) return {};
  const opts = options ?? {};
  const cwd = input.directory ?? process.cwd();
  const script = opts.script ?? join(cwd, "scripts", "cold-start.sh");
  const settings = opts.settings ?? join(cwd, "scripts", "memory-settings.sh");
  const timeoutMs = Number.isFinite(opts.timeoutMs) ? opts.timeoutMs : BRIEF_TIMEOUT_MS;
  const contexts = new Map();

  const readBrief = async () => {
    const result = await runScript("cold-start", script, ["--brief"], cwd, timeoutMs);
    return result.ok ? `${HEADER}\n${result.text}` : failureNote(result.reason);
  };

  // config.sh and config.local.sh are shell, so a script reads them; a session started without `ws oc` gets the same value.
  const readMemoryBlock = async () => {
    const result = await runScript("memory-settings", settings, [], cwd, timeoutMs);
    if (!result.ok) return memoryFailureNote(result.reason);
    const dir = /^WS_MEMORY_DIR=(.*)$/m.exec(result.text)?.[1];
    const cap = Number(/^WS_MEMORY_CAP=(.*)$/m.exec(result.text)?.[1]);
    if (!dir) return null;
    if (!Number.isFinite(cap)) return memoryFailureNote("the settings script printed no number for WS_MEMORY_CAP");
    try {
      return await readMemory(dir, cap);
    } catch (error) {
      return memoryFailureNote(error.message);
    }
  };

  // `ws wake current` and `ws bg run --wake current` read runs/<slug>/session.id, since a session cannot otherwise
  // name its own id. A missing project or runs directory skips it: the session must start whatever this does.
  const recorded = new Set();
  const recordSession = async (sessionID) => {
    if (recorded.has(sessionID) || sessionID === "unknown") return;
    recorded.add(sessionID);
    const slug = process.env.WS_PROJECT;
    if (!slug) return;
    const dir = join(cwd, "runs", slug);
    const temp = join(dir, `.session.id.${process.pid}`);
    try {
      await writeFile(temp, `${sessionID}\n`);
      await rename(temp, join(dir, "session.id"));
    } catch {
      await rm(temp, { force: true }).catch(() => {});
    }
  };

  const contextFor = (sessionID) => {
    let context = contexts.get(sessionID);
    if (context === undefined) {
      context = Promise.all([readBrief(), readMemoryBlock()]).then((blocks) => blocks.filter(Boolean));
      contexts.set(sessionID, context);
    }
    return context;
  };

  return {
    // OpenCode calls this for every model request; the context is read once per session and the cached text is
    // appended on each request, because each request gets a fresh system prompt.
    "experimental.chat.system.transform": async (input, output) => {
      const sessionID = input?.sessionID || "unknown";
      await recordSession(sessionID);
      try {
        if (Array.isArray(output?.system)) output.system.push(...(await contextFor(sessionID)));
      } catch (error) {
        const note = failureNote(`the plugin failed: ${error.message}`);
        if (Array.isArray(output?.system)) output.system.push(note);
      }
    },
    // A compaction replaces the session's history, so it is the session's second start: the context is read again,
    // goes into the summary, and replaces the cached text the following requests append.
    "experimental.session.compacting": async (input, output) => {
      const sessionID = input?.sessionID || "unknown";
      contexts.delete(sessionID);
      try {
        if (Array.isArray(output?.context)) output.context.push(...(await contextFor(sessionID)));
      } catch (error) {
        const note = failureNote(`the plugin failed: ${error.message}`);
        if (Array.isArray(output?.context)) output.context.push(note);
      }
    },
  };
};
