import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { readdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

// The 2.x port of cold-start.js. OpenCode 2.x default-exports `{ id, setup }` and offers the same context as
// `ctx.session.hook("context")` and `ctx.session.hook("compaction")`; the 1.x `experimental.*` hooks do not fire.
// Types (@opencode/plugin 2.2.7 `dist/promise/session.d.ts`): both events are a `SessionContext`, which carries the
// session id as a `readonly sessionID` and the request's writable system parts as `system: Array<SystemPart>`, where
// `SystemPart` is `{ type: "text", text }` (@opencode/ai `dist/schema/messages.d.ts`). `SessionCompaction` adds
// `result?: SessionCompactionResult`; its own comment says setting it "use[s] this compaction and skip[s] the model
// request", so it replaces the summary instead of adding to it. The brief therefore goes onto `event.system` in both
// hooks and never into `event.result`.
const BRIEF_TIMEOUT_MS = 20_000;
const HEADER = "Session-start context from scripts/cold-start.sh --brief (run /cold-start to refresh it mid-session):";
const MEMORY_HEADER = "Standing memory from WS_MEMORY_DIR, read-only: the MEMORY.md index, then each feedback memory in full.";
const MEMORY_INDEX = "MEMORY.md";
const SLUG = /^[A-Za-z0-9._-]+$/;

// The one shape a 2.x system list takes: SystemPart is `{ type: "text", text }`, not the 1.x `string[]`.
function textPart(text) {
  return { type: "text", text };
}

function failureNote(reason) {
  return `Session-start context unavailable (${reason}); run /cold-start to load it.`;
}

function memoryFailureNote(reason) {
  return `Memory unavailable (${String(reason).split("\n")[0]}); this session has no standing memory.`;
}

// A slug becomes a path component under runs/, so it is read the way reply-log-2x.js reads it and then checked.
function readSlug(directory, pinned) {
  if (pinned) return String(pinned).trim();
  const fromEnv = (process.env.WS_PROJECT ?? "").trim();
  if (fromEnv) return fromEnv;
  try {
    return readFileSync(join(directory, "state", "current"), "utf8").split("\n")[0].trim();
  } catch {
    return "";
  }
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

export default {
  id: "cg.cold-start",
  async setup(ctx) {
    // Deliberate: a headless builder sets WS_RUN_EVENTS for its own event plugin and must not receive the
    // orchestrator's brief or memory, so the plugin registers nothing there.
    if (process.env.WS_RUN_EVENTS) return;
    const options = ctx?.options ?? {};
    const directory = options.directory ?? ctx?.location?.directory ?? process.cwd();
    const script = options.script ?? join(directory, "scripts", "cold-start.sh");
    const settings = options.settings ?? join(directory, "scripts", "memory-settings.sh");
    const timeoutMs = Number.isFinite(options.timeoutMs) ? options.timeoutMs : BRIEF_TIMEOUT_MS;
    const slug = readSlug(directory, options.slug);
    // A bad slug costs the session only the session.id record: a broken selection must not also cost it the brief.
    if (slug && !SLUG.test(slug)) {
      console.error(`cold-start: project '${slug}' is not a usable slug; the session id was not recorded`);
    }
    const usableSlug = slug && SLUG.test(slug) ? slug : "";
    const contexts = new Map();

    const readBrief = async () => {
      const result = await runScript("cold-start", script, ["--brief"], directory, timeoutMs);
      return result.ok ? `${HEADER}\n${result.text}` : failureNote(result.reason);
    };

    // config.sh and config.local.sh are shell, so a script reads them; a session started without `ws oc` gets the same value.
    const readMemoryBlock = async () => {
      const result = await runScript("memory-settings", settings, [], directory, timeoutMs);
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
      if (!usableSlug || recorded.has(sessionID) || sessionID === "unknown") return;
      recorded.add(sessionID);
      const dir = join(directory, "runs", usableSlug);
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

    // OpenCode calls the context hook for every primary request; the text is read once per session and the cached
    // text is appended on each request, because each request gets a fresh system list.
    await ctx.session.hook("context", async (event) => {
      const sessionID = event?.sessionID || "unknown";
      await recordSession(sessionID);
      try {
        if (Array.isArray(event?.system)) event.system.push(...(await contextFor(sessionID)).map(textPart));
      } catch (error) {
        const note = failureNote(`the plugin failed: ${error.message}`);
        if (Array.isArray(event?.system)) event.system.push(textPart(note));
      }
    });

    // A compaction replaces the session's history, so it is the session's second start: the context is read again and
    // goes onto the compaction request's own system parts, which is the one place this hook can add text. Setting
    // `event.result` would replace the model's summary and skip the request, so it is left alone.
    await ctx.session.hook("compaction", async (event) => {
      const sessionID = event?.sessionID || "unknown";
      await recordSession(sessionID);
      contexts.delete(sessionID);
      try {
        if (Array.isArray(event?.system)) event.system.push(...(await contextFor(sessionID)).map(textPart));
      } catch (error) {
        const note = failureNote(`the plugin failed: ${error.message}`);
        if (Array.isArray(event?.system)) event.system.push(textPart(note));
      }
    });
  },
};
