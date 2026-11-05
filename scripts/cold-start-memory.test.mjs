// Run by scripts/selftest.sh. Calls the cold-start plugin's hook functions directly with the shapes OpenCode 1.19.1
// passes, against a fixture memory directory and the real scripts/memory-settings.sh, so no model is involved.
// Usage: node cold-start-memory.test.mjs <plugin.js> <memory-settings.sh> <temp-dir>
import assert from "node:assert/strict";
import { appendFileSync, chmodSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

delete process.env.WS_RUN_EVENTS;
const [pluginPath, settings, tempRoot] = process.argv.slice(2);
const { ColdStartPlugin } = await import(pathToFileURL(pluginPath).href);

const work = mkdtempSync(join(tempRoot, "memory-"));
const memoryDir = join(work, "memory");
mkdirSync(memoryDir);
const memoryFile = (name, text) => writeFileSync(join(memoryDir, name), text);
const memory = (type, body) => `---\nname: fixture\ndescription: a fixture\nmetadata:\n  type: ${type}\n---\n\n${body}\n`;

memoryFile("MEMORY.md", "- [Keep answers short](short.md) - index line\n- [A project](project.md) - another\n");
memoryFile("short.md", memory("feedback", "FEEDBACK-BODY-SHORT\n**Why:** reasons"));
memoryFile("flat.md", "---\nname: flat\ntype: feedback\n---\nFEEDBACK-BODY-FLAT\n");
memoryFile("project.md", memory("project", "PROJECT-BODY-SECRET"));
memoryFile("user.md", memory("user", "USER-BODY-SECRET"));
memoryFile("loose.md", "LOOSE-BODY-NO-FRONTMATTER\n");

const counter = join(work, "brief-runs.log");
writeFileSync(counter, "");
const coldStart = join(work, "cold-start-stand-in.sh");
writeFileSync(
  coldStart,
  `#!/usr/bin/env bash\necho run >> ${JSON.stringify(counter)}\nprintf 'BRIEF-RUN-%s\\n' "$(wc -l < ${JSON.stringify(counter)})"\n`,
);
chmodSync(coldStart, 0o755);

const load = (env) => {
  process.env.WS_MEMORY_DIR = env.dir;
  process.env.WS_MEMORY_CAP = String(env.cap ?? 24000);
  return ColdStartPlugin({ directory: work }, { script: coldStart, settings });
};
const systemText = async (hooks, sessionID) => {
  const output = { system: [] };
  await hooks["experimental.chat.system.transform"]({ sessionID, model: {} }, output);
  return output.system;
};
const compacted = async (hooks, sessionID) => {
  const output = { context: [] };
  await hooks["experimental.session.compacting"]({ sessionID }, output);
  return output.context;
};

// The index and every feedback body reach the system text; other memory types and files without a type do not.
const hooks = await load({ dir: memoryDir });
const first = await systemText(hooks, "ses_one");
assert.equal(first.length, 2, "one block for the brief and one for the memory");
const text = first.join("\n");
assert.match(text, /index line/, "the index is present");
assert.match(text, /FEEDBACK-BODY-SHORT/, "a feedback body is present");
assert.match(text, /FEEDBACK-BODY-FLAT/, "a top-level type: feedback counts");
assert.doesNotMatch(text, /name: fixture/, "the frontmatter is left out");
assert.doesNotMatch(text, /PROJECT-BODY-SECRET/, "a project memory's body is absent");
assert.doesNotMatch(text, /USER-BODY-SECRET/, "a user memory's body is absent");
assert.doesNotMatch(text, /LOOSE-BODY-NO-FRONTMATTER/, "a file without frontmatter is not loaded");
assert.match(text, /loose\.md has no frontmatter/, "a file without frontmatter is named");

// Once per session: a later request reuses the text, even when a memory changed; another session reads it again.
memoryFile("later.md", memory("feedback", "FEEDBACK-BODY-LATER"));
assert.deepEqual(await systemText(hooks, "ses_one"), first, "the next request reuses the text");
assert.equal(readFileSync(counter, "utf8").split("\n").filter(Boolean).length, 1, "the brief ran once");
assert.match((await systemText(hooks, "ses_two")).join("\n"), /FEEDBACK-BODY-LATER/, "a new session reads the directory");

// Compaction adds a fresh brief and the memory to the summary's context, and the session then carries the fresh text.
const context = await compacted(hooks, "ses_one");
assert.equal(context.length, 2, "the compaction hook adds the brief and the memory");
assert.match(context[0], /BRIEF-RUN-3/, "the compaction hook runs cold start again");
assert.match(context[1], /FEEDBACK-BODY-LATER/, "the compaction hook reads the memory again");
assert.deepEqual(await systemText(hooks, "ses_one"), context, "requests after compaction carry the fresh text");

// An empty WS_MEMORY_DIR loads nothing: the compaction context is the brief alone.
const empty = await load({ dir: "" });
assert.equal((await systemText(empty, "ses_empty")).length, 1, "no memory block without a directory");
const emptyContext = await compacted(empty, "ses_empty");
assert.equal(emptyContext.length, 1, "compaction adds no memory without a directory");
assert.match(emptyContext[0], /BRIEF-RUN/);

// The cap keeps the index and what fits, and the text names what it dropped.
memoryFile("big.md", memory("feedback", `FEEDBACK-BODY-BIG ${"x".repeat(2000)}`));
const capped = (await systemText(await load({ dir: memoryDir, cap: 900 }), "ses_cap")).join("\n");
assert.match(capped, /index line/, "the index stays under the cap");
assert.doesNotMatch(capped, /FEEDBACK-BODY-BIG/, "the body over the cap is dropped");
assert.match(capped, /FEEDBACK-BODY-SHORT/, "a smaller body after the dropped one still fits");
assert.match(capped, /WS_MEMORY_CAP \(900 characters\) dropped big\.md/, "the drop is printed by name");
// The cap bounds the index and the bodies; the header and the closing drop note come on top of it.
const memoryBlock = (await systemText(await load({ dir: memoryDir, cap: 900 }), "ses_cap2"))[1];
const counted = memoryBlock.split("\n\n").slice(1, -1).join("\n\n");
assert.ok(counted.length <= 900, `the index and bodies fit the cap (${counted.length})`);

// An index larger than the cap is cut at a line, with a note.
appendFileSync(join(memoryDir, "MEMORY.md"), `${"- a long index line\n".repeat(100)}`);
const cut = (await systemText(await load({ dir: memoryDir, cap: 400 }), "ses_cut"))[1];
assert.match(cut, /MEMORY\.md cut to \d+ of 102 lines/, "the cut is printed");
assert.match(cut, /dropped .*short\.md/, "no room is left for the bodies");

// A directory that does not exist, or a relative one, or a bad cap, says so in one line; the session goes on.
const missing = await systemText(await load({ dir: join(work, "absent") }), "ses_missing");
assert.equal(missing.length, 2);
assert.equal(missing[1].includes("\n"), false, "the memory failure is one line");
assert.match(missing[1], /Memory unavailable .*absent/);
const relative = await systemText(await load({ dir: "some/dir" }), "ses_relative");
assert.match(relative[1], /Memory unavailable .*not an absolute path/);
const badCap = await systemText(await load({ dir: memoryDir, cap: "lots" }), "ses_badcap");
assert.match(badCap[1], /Memory unavailable .*WS_MEMORY_CAP/);

// A settings script with no cap line fails loud: a missing cap must not switch the cap off.
const noCap = join(work, "settings-no-cap.sh");
writeFileSync(noCap, `#!/usr/bin/env bash\necho "WS_MEMORY_DIR=${memoryDir}"\n`);
process.env.WS_MEMORY_DIR = memoryDir;
const uncapped = await ColdStartPlugin({ directory: work }, { script: coldStart, settings: noCap });
assert.match((await systemText(uncapped, "ses_nocap"))[1], /Memory unavailable .*WS_MEMORY_CAP/);

// A builder never loads it.
process.env.WS_MEMORY_DIR = memoryDir;
process.env.WS_RUN_EVENTS = join(work, "builder.events.jsonl");
assert.deepEqual(await ColdStartPlugin({ directory: work }, { script: coldStart, settings }), {}, "a builder gets no hooks");

console.log("cold-start memory ok");
