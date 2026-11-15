// Run by scripts/selftest.sh. Loads .opencode/plugins-2x/cold-start-2x.js with plain node, calls its setup with a fake
// ctx whose session.hook records the handlers, and drives the hooks with the 2.x event shapes (a `SessionContext`
// carrying `sessionID` and a writable `system` array), against a fixture memory directory and the real
// scripts/memory-settings.sh. No model and no OpenCode binary are involved.
// Usage: node cold-start-2x.test.mjs <plugin.js> <memory-settings.sh> <temp-dir>
import assert from "node:assert/strict";
import {
  chmodSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

delete process.env.WS_RUN_EVENTS;
delete process.env.WS_PROJECT;
const [pluginArg, settingsArg, tempRoot] = process.argv.slice(2);
// The plugin spawns the settings script with the session's directory as cwd, so both paths are made absolute here.
const pluginPath = resolve(pluginArg);
const settings = resolve(settingsArg);
const { default: plugin } = await import(pathToFileURL(pluginPath).href);

assert.equal(plugin.id, "cg.cold-start", "the plugin default-exports a 2.x definition with a stable id");
assert.equal(typeof plugin.setup, "function", "the definition registers through setup");

const work = mkdtempSync(join(tempRoot, "cold-start-2x-"));
const memoryDir = join(work, "memory");
mkdirSync(memoryDir);
const memoryFile = (name, text) => writeFileSync(join(memoryDir, name), text);
const memory = (type, body) => `---\nname: fixture\ndescription: a fixture\nmetadata:\n  type: ${type}\n---\n\n${body}\n`;

memoryFile("MEMORY.md", "- [Keep answers short](short.md) - index line\n");
memoryFile("short.md", memory("feedback", "FEEDBACK-BODY-SHORT\n**Why:** reasons"));
memoryFile("project.md", memory("project", "PROJECT-BODY-SECRET"));

const counter = join(work, "brief-runs.log");
writeFileSync(counter, "");
const coldStart = join(work, "cold-start-stand-in.sh");
writeFileSync(
  coldStart,
  `#!/usr/bin/env bash\necho run >> ${JSON.stringify(counter)}\nprintf 'BRIEF-RUN-%s\\n' "$(wc -l < ${JSON.stringify(counter)})"\n`,
);
chmodSync(coldStart, 0o755);

// A fake ctx in the 2.x shape: session.hook(name, callback) returns a registration the plugin ignores, and the
// callback later receives one mutable event.
const load = (overrides = {}) => {
  const handlers = {};
  const ctx = {
    options: { directory: work, script: overrides.script ?? coldStart, settings: overrides.settings ?? settings },
    location: { directory: work },
    session: {
      hook: async (name, callback) => {
        handlers[name] = callback;
        return { dispose: async () => {} };
      },
    },
  };
  return { ctx, handlers };
};
const setup = async (overrides) => {
  const { ctx, handlers } = load(overrides);
  await plugin.setup(ctx);
  return handlers;
};
const systemEvent = async (handlers, sessionID) => {
  const event = { sessionID, system: [] };
  await handlers.context(event);
  return event.system;
};

process.env.WS_MEMORY_DIR = memoryDir;
process.env.WS_MEMORY_CAP = "24000";

// Every request of a session gets the brief and the memory block as { type: "text", text } system parts.
const hooks = await setup();
const first = await systemEvent(hooks, "ses_one");
assert.equal(first.length, 2, "one part for the brief and one for the memory");
assert.deepEqual(first.map((part) => part.type), ["text", "text"], "each part is a text system part");
const text = first.map((part) => part.text).join("\n");
assert.match(text, /Session-start context from scripts\/cold-start\.sh --brief/, "the brief carries its header");
assert.match(text, /BRIEF-RUN-1/, "the brief's own output is present");
assert.match(text, /index line/, "the memory index is present");
assert.match(text, /FEEDBACK-BODY-SHORT/, "a feedback body is present");
assert.doesNotMatch(text, /PROJECT-BODY-SECRET/, "a project memory's body is absent");
assert.deepEqual(await systemEvent(hooks, "ses_one"), first, "the next request reuses the cached text");
assert.equal(readFileSync(counter, "utf8").split("\n").filter(Boolean).length, 1, "the brief ran once for the session");

// A compaction is the session's second start: the text is read again onto the compaction request's system parts, and
// the summary is left to the model.
const compaction = { sessionID: "ses_one", system: [], messages: [], result: undefined };
await hooks.compaction(compaction);
assert.equal(compaction.system.length, 2, "the compaction hook adds the brief and the memory");
assert.match(compaction.system[0].text, /BRIEF-RUN-2/, "the compaction hook runs cold start again");
assert.equal(compaction.result, undefined, "the compaction hook does not replace the model's summary");
assert.deepEqual(await systemEvent(hooks, "ses_one"), compaction.system, "requests after a compaction carry the fresh text");

// The first request of a session records its id in runs/<slug>/session.id, once; a later session replaces it.
process.env.WS_MEMORY_DIR = "";
process.env.WS_PROJECT = "fixture-slug";
const runs = join(work, "runs", "fixture-slug");
mkdirSync(runs, { recursive: true });
const recorder = await setup();
await systemEvent(recorder, "ses_rec1");
assert.equal(readFileSync(join(runs, "session.id"), "utf8"), "ses_rec1\n", "the session id is recorded");
writeFileSync(join(runs, "session.id"), "ses_overwritten\n");
await systemEvent(recorder, "ses_rec1");
assert.equal(readFileSync(join(runs, "session.id"), "utf8"), "ses_overwritten\n", "a later request does not write again");
await systemEvent(recorder, "ses_rec2");
assert.equal(readFileSync(join(runs, "session.id"), "utf8"), "ses_rec2\n", "a new session records its id");
assert.deepEqual(readdirSync(runs), ["session.id"], "no temp file is left");

// Without WS_PROJECT the slug comes from the first line of state/current.
process.env.WS_PROJECT = "";
mkdirSync(join(work, "state"), { recursive: true });
writeFileSync(join(work, "state", "current"), "state-slug\nsecond line\n");
mkdirSync(join(work, "runs", "state-slug"), { recursive: true });
await systemEvent(await setup(), "ses_state");
assert.equal(readFileSync(join(work, "runs", "state-slug", "session.id"), "utf8"), "ses_state\n", "the selected slug is recorded");

// A slug that would escape runs/ writes nothing; the session still gets its brief.
process.env.WS_PROJECT = "../../evil";
const before = readdirSync(work).sort();
const evil = await systemEvent(await setup(), "ses_evil");
assert.equal(evil.length, 1, "the brief still arrives with an unusable slug");
assert.equal(existsSync(join(tempRoot, "evil")), false, "no file is written outside runs/");
assert.equal(existsSync(join(work, "runs", "..", "evil")), false, "no file is written beside runs/");
assert.deepEqual(readdirSync(work).sort(), before, "the traversal slug writes nothing");
delete process.env.WS_PROJECT;

// A failing script becomes one line and the session goes on.
const broken = join(work, "cold-start-broken.sh");
writeFileSync(broken, "#!/usr/bin/env bash\necho 'brief broke' >&2\nexit 7\n");
chmodSync(broken, 0o755);
const failed = await systemEvent(await setup({ script: broken }), "ses_fail");
assert.equal(failed.length, 1, "a failure appends a note");
assert.equal(failed[0].text.includes("\n"), false, "the failure note is one line");
assert.match(failed[0].text, /Session-start context unavailable \(cold-start exit 7: brief broke\)/);

// A builder registers nothing at all.
process.env.WS_RUN_EVENTS = join(work, "builder.events.jsonl");
const builder = load();
assert.equal(await plugin.setup(builder.ctx), undefined, "a builder's run-events file keeps the plugin out");
assert.deepEqual(Object.keys(builder.handlers), [], "a builder gets no hooks");
assert.equal(existsSync(join(work, "builder.events.jsonl")), false, "a builder leaves no file");
delete process.env.WS_RUN_EVENTS;

console.log("cold-start 2.x plugin ok");
