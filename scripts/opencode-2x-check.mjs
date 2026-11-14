import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { registerHooks } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Proves the 2.x plugins in .opencode/plugins/ load through the V2 default-definition shape, register the hooks
// they need, and write records the existing readers (scripts/opencode_run.py, scripts/check-result.sh) read.
// The scripts/selftest.sh copy passes the generated deny list; a direct run uses a small one with the same rules.
// `--live-guard` and `--live-reply` run the same plugins against a real 2.2.7 CLI; the default path never starts one.
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const liveIndex = process.argv.findIndex((arg) => arg === "--live-guard" || arg === "--live-reply" || arg === "--live-config" || arg === "--live-instructions");
const positional = process.argv.slice(2, liveIndex === -1 ? undefined : liveIndex);
const denyGuardPath = resolve(positional[0] ?? join(root, "scripts/opencode-plugins-2x/deny-guard.js"));
const runEventsPath = resolve(positional[1] ?? join(root, "scripts/opencode-plugins-2x/run-events.js"));
const replyLogPath = join(root, ".opencode/plugins/reply-log-2x.js");
const denyFile = positional[2] ? resolve(positional[2]) : join(mkdtempSync(join(tmpdir(), "cg-oc2-check-")), "deny.txt");
const temp = mkdtempSync(join(tmpdir(), "cg-oc2-check-"));

// The 2.2.7 binary resolves @opencode/plugin itself; a plain node run of the plugin files does not have that
// package, so the test points the bare import at the same identity `Plugin.define`.
const pluginStub = join(temp, "opencode-plugin.mjs");
writeFileSync(pluginStub, "export const Plugin = { define: (definition) => definition };\n");
const hooks = registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "@opencode/plugin") return { url: pathToFileURL(pluginStub).href, shortCircuit: true };
    return nextResolve(specifier, context);
  },
});

if (!positional[2]) {
  writeFileSync(
    denyFile,
    [
      "python3 -c*",
      "python3 -* -c*",
      "*/python -c*",
      "*/python3 -c*",
      "node -e*",
      "node --eval*",
      "*/node -e*",
      "bash -c*",
      "sh -c*",
      "*/bash -c*",
      "*/sh -c*",
    ].join("\n"),
  );
}

function withHookDomain() {
  const registered = {};
  return {
    registered,
    ctx: {
      options: { denyFile },
      tool: { hook: async (name, callback) => ((registered[name] = callback), { dispose() {} }) },
    },
  };
}

const { DenyGuardPlugin } = { DenyGuardPlugin: (await import(pathToFileURL(denyGuardPath).href)).default };
assert.equal(typeof DenyGuardPlugin, "object", "the deny guard default-exports a V2 definition object");
assert.equal(typeof DenyGuardPlugin.id, "string", "the deny guard has a stable id");
assert.equal(typeof DenyGuardPlugin.setup, "function", "the deny guard registers through setup");
const guard = withHookDomain();
await DenyGuardPlugin.setup(guard.ctx);
assert.equal(typeof guard.registered["execute.before"], "function", "the deny guard registers tool execute.before");
const runShell = async (tool, command) => guard.registered["execute.before"]({ tool, input: { command } });

const refused = [
  `python3 "-c" 'print(1)'`,
  `python3 '-c' 1`,
  `python3 -"c" 1`,
  `node "-e" 1`,
  `node '-e' 1`,
  `bash "-c" id`,
  `.venv/bin/python "-c" 1`,
  `echo ok && python3 "-c" 1`,
  `echo ok | bash "-c" id`,
  `FOO=1 python3 "-c" 1`,
  `(python3 "-c" 1)`,
  `echo "$(python3 "-c" 1)"`,
];
for (const command of refused) {
  await assert.rejects(runShell("shell", command), /prevents you from using/, `refused: ${command}`);
}
const passed = [
  `python3 -m unittest discover -s tests -p "test_*.py"`,
  `node scripts/serve.js -p 8080`,
  `node scripts/q.js "-e" x`,
  `git commit -m "deny (bash -c) and python3 -c; node -e"`,
  `grep "python3 -c" scripts/a.sh`,
  `echo 'a; bash -c b'`,
];
for (const command of passed) await runShell("shell", command);
await runShell("read", `python3 "-c" 1`);

function eventSource() {
  const queue = [];
  let ended = false;
  let wake = null;
  const notify = () => {
    if (wake) {
      const resolveWake = wake;
      wake = null;
      resolveWake();
    }
  };
  return {
    push(event) {
      queue.push(event);
      notify();
    },
    end() {
      ended = true;
      notify();
    },
    subscribe({ signal } = {}) {
      signal?.addEventListener("abort", () => this.end(), { once: true });
      return {
        async *[Symbol.asyncIterator]() {
          while (true) {
            if (queue.length) {
              yield queue.shift();
              continue;
            }
            if (ended) return;
            await new Promise((resolveWait) => (wake = resolveWait));
          }
        },
      };
    },
  };
}

const { RunEventsPlugin } = { RunEventsPlugin: (await import(pathToFileURL(runEventsPath).href)).default };
assert.equal(typeof RunEventsPlugin, "object", "run-events default-exports a V2 definition object");
assert.equal(typeof RunEventsPlugin.id, "string", "run-events has a stable id");
assert.equal(typeof RunEventsPlugin.setup, "function", "run-events registers through setup");
const eventsFile = join(temp, "run-events.jsonl");
const source = eventSource();
const cleanup = await RunEventsPlugin.setup({ options: { file: eventsFile }, event: source });
assert.equal(typeof cleanup, "function", "run-events returns its cleanup function");

source.push({
  type: "permission.asked",
  data: { id: "per_1", sessionID: "ses_1", action: "shell", resources: ["git push *"], metadata: { command: "git push origin" }, title: "shell" },
});
source.push({ type: "permission.replied", data: { sessionID: "ses_1", requestID: "per_1", reply: "reject" } });
source.push({
  type: "session.retry.scheduled",
  data: {
    sessionID: "ses_1",
    assistantMessageID: "msg_1",
    attempt: 1,
    at: 1700000000000,
    error: { type: "APIError", message: "Too Many Requests", status: 429, response: { body: "GoUsageLimitError" }, retryAfterMs: 60000 },
  },
});
source.push({
  type: "session.execution.failed",
  data: { sessionID: "ses_1", error: { type: "APIError", message: "usage limit", status: 429, response: { body: "GoUsageLimitError" } } },
});
source.push({ type: "session.tool.called", data: { sessionID: "ses_1", assistantMessageID: "msg_1", id: "call_1", input: { command: "echo hi" }, executed: false } });
source.push({
  type: "session.tool.success",
  data: { sessionID: "ses_1", assistantMessageID: "msg_1", id: "call_1", content: [{ type: "text", text: "hi" }], executed: true },
});
source.push({
  type: "session.tool.failed",
  data: { sessionID: "ses_1", assistantMessageID: "msg_1", id: "call_2", error: { type: "ToolError", message: "no" }, executed: true },
});
source.push({ type: "session.compaction.started", data: { sessionID: "ses_1", reason: "auto" } });
source.push({ type: "session.compaction.ended", data: { sessionID: "ses_1", reason: "auto", text: "summary" } });
source.push({ type: "session.compaction.failed", data: { sessionID: "ses_1", reason: "manual", error: { type: "CompactionError", message: "boom" } } });
source.push({ type: "session.idle", data: { sessionID: "ses_1" } });

const expected = [
  "permission.asked",
  "permission.replied",
  "session.retry",
  "session.error",
  "tool.started",
  "tool.finished",
  "tool.finished",
  "session.compaction.started",
  "session.compaction.ended",
  "session.compaction.failed",
];
const deadline = Date.now() + 5000;
let lines = [];
while (Date.now() < deadline) {
  try {
    lines = readFileSync(eventsFile, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line));
  } catch {
    lines = [];
  }
  if (lines.length >= expected.length) break;
  await new Promise((resolveWait) => setTimeout(resolveWait, 20));
}
cleanup();
assert.deepEqual(lines.map((line) => line.event), expected, "one record per 2.x event and none for an unrelated event");
assert.equal(lines[0].tool, "shell");
assert.equal(lines[0].metadata.command, "git push origin");
assert.equal(lines[1].reply, "reject");
assert.equal(lines[2].message, "Too Many Requests");
assert.equal(lines[2].next, 1700000000000);
assert.equal(lines[2].limit, true);
assert.equal(lines[3].status, 429);
assert.equal(lines[3].response_body, "GoUsageLimitError");
assert.equal(lines[3].limit, true);
assert.deepEqual(lines[4].tool_input, { command: "echo hi" });
assert.equal(lines[5].status, "completed");
assert.equal(lines[6].status, "error");
assert.equal(lines[9].message, "boom");

const denials = JSON.parse(execFileSync("python3", ["-I", "scripts/opencode_run.py", "events-denials", eventsFile], { cwd: root, encoding: "utf8" }));
assert.deepEqual(denials, [{ tool_name: "shell", tool_input: { command: "git push origin" } }], "opencode_run reads the denied permission");
const limit = execFileSync("python3", ["-I", "scripts/opencode_run.py", "limit", eventsFile], { cwd: root, encoding: "utf8" }).trim();
assert.match(limit, /^usage limit\t\d+$/, "opencode_run reads the provider limit and its reset");

// The workspace names this package directory in a builder's and a review's config, because V2 loads a configured
// plugin path as one module: its index.js must register both hooks the launcher relies on.
const builderBundle = (await import(pathToFileURL(join(root, "scripts/opencode-plugins-2x/index.js")).href)).default;
assert.equal(typeof builderBundle, "object", "the builder plugin package default-exports a V2 definition object");
assert.equal(builderBundle.id, "cg.builder-plugins", "the builder package has a stable id");
assert.equal(typeof builderBundle.setup, "function", "the builder package registers through setup");
const bundleEvents = join(temp, "bundle-events.jsonl");
const bundle = withHookDomain();
bundle.ctx.options = { denyFile, file: bundleEvents };
const bundleSource = eventSource();
bundle.ctx.event = bundleSource;
const bundleCleanup = await builderBundle.setup(bundle.ctx);
assert.equal(typeof bundle.registered["execute.before"], "function", "the package registers the deny guard's tool hook");
assert.equal(typeof bundleCleanup, "function", "the package returns the run-events cleanup");
await assert.rejects(
  async () => bundle.registered["execute.before"]({ tool: "shell", input: { command: `python3 "-c" 1` } }),
  /prevents you from using/,
  "the package's deny guard refuses a quoted interpreter form",
);
const readBundleRecords = () => {
  try {
    return readFileSync(bundleEvents, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line));
  } catch {
    return [];
  }
};
bundleSource.push({
  type: "permission.asked",
  data: { id: "per_bundle", sessionID: "ses_bundle", action: "shell", resources: ["git push *"], metadata: { command: "git push origin" }, title: "shell" },
});
const bundleDeadline = Date.now() + 5000;
let bundleRecords = [];
while (Date.now() < bundleDeadline) {
  bundleRecords = readBundleRecords();
  if (bundleRecords.length) break;
  await new Promise((resolveWait) => setTimeout(resolveWait, 20));
}
assert.deepEqual(bundleRecords.map((record) => record.event), ["permission.asked"], "the package writes the event through run-events");
assert.equal(bundleRecords[0].request_id, "per_bundle");
assert.equal(bundleRecords[0].tool, "shell");
bundleCleanup();
await new Promise((resolveWait) => setTimeout(resolveWait, 50));
bundleSource.push({ type: "permission.asked", data: { id: "per_bundle_2", sessionID: "ses_bundle", action: "shell", resources: [] } });
await new Promise((resolveWait) => setTimeout(resolveWait, 100));
assert.deepEqual(readBundleRecords().map((record) => record.event), ["permission.asked"], "the package's cleanup stops further records");

const { ReplyLogPlugin } = { ReplyLogPlugin: (await import(pathToFileURL(replyLogPath).href)).default };
assert.equal(typeof ReplyLogPlugin, "object", "reply-log default-exports a V2 definition object");
assert.equal(typeof ReplyLogPlugin.id, "string", "reply-log has a stable id");
assert.equal(typeof ReplyLogPlugin.setup, "function", "reply-log registers through setup");
const replyRoot = join(temp, "reply");
const replySource = eventSource();
delete process.env.WS_RUN_EVENTS;
const replyCleanup = await ReplyLogPlugin.setup({
  options: { directory: replyRoot, slug: "demo", timeZone: "UTC", now: () => new Date("2026-11-09T11:40:00Z") },
  location: { directory: replyRoot },
  event: replySource,
});
assert.equal(typeof replyCleanup, "function", "reply-log returns its cleanup function");
replySource.push({ type: "session.text.ended", data: { sessionID: "ses_1", assistantMessageID: "msg_1", ordinal: 0, text: "merged at 11:40" } });
replySource.push({ type: "session.text.ended", data: { sessionID: "ses_1", assistantMessageID: "msg_1", ordinal: 0, text: "merged at 11:40" } });
replySource.push({ type: "session.text.ended", data: { sessionID: "ses_1", assistantMessageID: "msg_1", ordinal: 1, text: "second part" } });
replySource.push({ type: "session.execution.succeeded", data: { sessionID: "ses_1" } });
const replyFile = join(replyRoot, "runs", "demo", "replies.md");
const replyDeadline = Date.now() + 5000;
while (Date.now() < replyDeadline && !existsSync(replyFile)) await new Promise((resolveWait) => setTimeout(resolveWait, 20));
replyCleanup();
const savedReply = readFileSync(replyFile, "utf8");
assert.equal(savedReply, "## 2026-11-09 11:40 UTC\n\nmerged at 11:40\n\nsecond part\n\n", "one dated entry with each completed text part once");
assert.equal(savedReply.includes("━━"), false, "the visible banner is not in the saved entry");
process.env.WS_RUN_EVENTS = join(temp, "builder.events");
const skipped = await ReplyLogPlugin.setup({ options: { directory: replyRoot }, event: eventSource() });
assert.equal(skipped, undefined, "a builder's run-events file gives the reply log no subscription");
delete process.env.WS_RUN_EVENTS;

const crossingRoot = join(temp, "crossing");
const crossingTimes = [new Date("2026-11-09T23:59:00Z"), new Date("2026-11-10T00:01:00Z")];
const crossingSource = eventSource();
const crossingCleanup = await ReplyLogPlugin.setup({
  options: { directory: crossingRoot, slug: "demo", timeZone: "UTC", now: () => crossingTimes.shift() },
  location: { directory: crossingRoot },
  event: crossingSource,
});
crossingSource.push({ type: "session.text.ended", data: { sessionID: "ses_1", assistantMessageID: "msg_1", ordinal: 0, text: "before midnight" } });
crossingSource.push({ type: "session.execution.succeeded", data: { sessionID: "ses_1" } });
crossingSource.push({ type: "session.text.ended", data: { sessionID: "ses_2", assistantMessageID: "msg_2", ordinal: 0, text: "after midnight" } });
crossingSource.push({ type: "session.execution.succeeded", data: { sessionID: "ses_2" } });
const crossingFile = join(crossingRoot, "runs", "demo", "replies.md");
const crossingDeadline = Date.now() + 5000;
while (Date.now() < crossingDeadline) {
  if (existsSync(crossingFile) && readFileSync(crossingFile, "utf8").includes("2026-11-10")) break;
  await new Promise((resolveWait) => setTimeout(resolveWait, 20));
}
crossingCleanup();
assert.equal(
  readFileSync(crossingFile, "utf8"),
  "## 2026-11-09 23:59 UTC\n\nbefore midnight\n\n## 2026-11-10 00:01 UTC\n\nafter midnight\n\n",
  "two replies across midnight keep their own local date",
);

// The 2.x config shape: a `permissions` array of {action, resource, effect} whose action names are shell/edit/
// subagent. The 1.x `permission` object is not what a 2.x process reads, so a builder or review config must not carry
// it. A refused edit/write is a deny rule for the edit action; a subagent is a deny rule for `subagent`.
function configFor(...args) {
  return JSON.parse(execFileSync("python3", ["-I", "scripts/opencode_run.py", "config", ...args], { cwd: root, encoding: "utf8" }));
}
const rule = (rules, action, resource) => rules.find((r) => r.action === action && r.resource === resource);
const builder2 = configFor("--line", "2", "Bash(git status)");
assert.equal(Array.isArray(builder2.permissions), true, "a 2.x builder config carries a permissions array");
assert.equal(builder2.permission, undefined, "a 2.x builder config does not carry the 1.x permission object");
assert.deepEqual(builder2.permissions[0], { action: "*", resource: "*", effect: "deny" }, "the catch-all deny comes first");
assert.deepEqual(rule(builder2.permissions, "shell", "git status"), { action: "shell", resource: "git status", effect: "allow" }, "a Bash grant becomes a shell allow");
assert.equal(rule(builder2.permissions, "shell", "*").effect, "deny", "unlisted shell commands are denied");
assert.equal(rule(builder2.permissions, "edit", "*").effect, "deny", "a builder without an Edit grant refuses edits");
assert.equal(rule(builder2.permissions, "subagent", "*").effect, "deny", "the task tool is denied as subagent");
assert.equal(rule(builder2.permissions, "webfetch", "*").effect, "deny", "webfetch is denied without a grant");
assert.equal(rule(builder2.permissions, "websearch", "*").effect, "deny", "websearch is denied without a grant");
const writer2 = configFor("--line", "2", "Edit(*)", "WebFetch", "WebSearch");
assert.equal(rule(writer2.permissions, "edit", "*").effect, "allow", "an Edit grant allows the edit action");
assert.equal(rule(writer2.permissions, "webfetch", "*").effect, "allow", "a WebFetch grant allows webfetch");
assert.equal(rule(writer2.permissions, "websearch", "*").effect, "allow", "a WebSearch grant allows websearch");
const review2 = configFor("--read-only", "--line", "2", "--directory", "/tmp/branch");
assert.equal(Array.isArray(review2.permissions), true, "a 2.x review config carries a permissions array");
assert.equal(rule(review2.permissions, "edit", "*").effect, "deny", "a review refuses edits");
assert.equal(rule(review2.permissions, "shell", "git status *").effect, "allow", "a review keeps its read-only git grants");
assert.equal(rule(review2.permissions, "shell", "*--output*").effect, "deny", "a review refuses a shell redirect");
assert.equal(rule(review2.permissions, "external_directory", "/tmp/branch/**").effect, "allow", "a review may read the branch as an external directory");
const builder1 = configFor("Bash(git status)");
assert.equal(builder1.permissions, undefined, "a 1.x builder config keeps its permission object");
assert.equal(builder1.permission["*"], "deny", "a 1.x builder config still denies unlisted tools");

const legacyGuard = await import(pathToFileURL(join(root, "scripts/opencode-plugins/deny-guard.js")).href);
assert.equal(typeof legacyGuard.DenyGuardPlugin, "function", "the 1.x deny guard still exports its plugin function");
const legacyGuardHooks = await legacyGuard.DenyGuardPlugin({}, { denyFile });
assert.equal(typeof legacyGuardHooks["tool.execute.before"], "function", "the 1.x deny guard still registers its hook");
const legacyEvents = await import(pathToFileURL(join(root, "scripts/opencode-plugins/run-events.js")).href);
assert.equal(typeof legacyEvents.RunEventsPlugin, "function", "the 1.x run-events plugin still exports its plugin function");
const legacyEventHooks = await legacyEvents.RunEventsPlugin({}, { file: join(temp, "legacy-events.jsonl") });
assert.equal(typeof legacyEventHooks.event, "function", "the 1.x run-events plugin still registers its event hook");
delete process.env.WS_RUN_EVENTS;

hooks.deregister();
console.log("opencode 2.x plugins load, register hooks and write records the tool reads ok; the 1.x plugins still export their hooks");

const mode = process.argv.find((arg) => arg === "--live-guard" || arg === "--live-reply" || arg === "--live-config" || arg === "--live-instructions");
if (mode === "--live-config") liveConfig(process.argv.slice(process.argv.indexOf(mode) + 1));
else if (mode === "--live-instructions") liveInstructions(process.argv.slice(process.argv.indexOf(mode) + 1));
else if (mode) live(mode, process.argv.slice(process.argv.indexOf(mode) + 1));

function liveInstructions(args) {
  // The project's own `instructions` key overrides a custom config's, so `ws oc` also exports the per-session config
  // inline. An inline config is applied after the project config, so the lesson is in the effective list.
  const [bin, cwd, lesson] = args;
  if (!bin || !cwd || !lesson) throw new Error("--live-instructions needs <bin> <cwd> <lessonFile>");
  const inline = JSON.stringify({
    $schema: "https://opencode.ai/config.json",
    share: "disabled",
    instructions: [resolve(lesson)],
    permissions: [{ action: "*", resource: "*", effect: "deny" }],
  });
  const run = spawnSync(bin, ["debug", "config", "--standalone"], {
    cwd, env: { ...process.env, OPENCODE_CONFIG_CONTENT: inline }, encoding: "utf8", timeout: 60000 });
  assert.equal(run.status, 0, "--live-instructions debug config exits cleanly");
  const sources = JSON.parse(run.stdout);
  const last = sources[sources.length - 1];
  assert.equal(last.type, "document", "the inline config is a document source");
  assert.equal(last.path, undefined, "the inline config has no path and is applied last");
  assert.ok((last.info.instructions || []).includes(resolve(lesson)), "the effective instruction list has the 2.x lesson");
  console.log(`live instructions: the inline source is last and its ${last.info.instructions.length} instructions include the 2.x lesson`);
}

function liveConfig(args) {
  // Proves on a real 2.x CLI that the generated 2.x config refuses an edit and a subagent. A denied tool is hidden
  // from the session, so the proof is either a refused tool call recorded by run-events or the model reporting the
  // tool unavailable.
  const [bin, cwd, model, pluginDir, events, kind] = args;
  if (!bin || !cwd || !model || !pluginDir || !events || !kind) throw new Error("--live-config needs <bin> <cwd> <model> <pluginDir> <eventsFile> edit|subagent");
  const config = JSON.parse(execFileSync("python3", ["-I", "scripts/opencode_run.py", "config", "--line", "2"], { cwd: root, encoding: "utf8" }));
  config.plugins = [resolve(pluginDir)];
  const env = { ...process.env, WS_PROJECT: "oc2-probe", PWD: cwd, WS_RUN_EVENTS: events,
    OPENCODE_CONFIG_CONTENT: JSON.stringify(config) };
  delete env.WS_RUN_DENY;
  const prompt = kind === "edit"
    ? "Use the write tool to create the file /tmp/oc2-refused-edit.txt with the text hello. Then reply with DONE."
    : "Use the task tool to start a subagent that replies hello. Then reply with DONE.";
  const run = spawnSync(bin, ["run", "--standalone", "--print-logs", "--format", "json", "--auto", "-m", model, prompt],
    { cwd, env, encoding: "utf8", timeout: 180000 });
  process.stdout.write(run.stdout ?? "");
  process.stderr.write(run.stderr ?? "");
  assert.equal(run.status, 0, `--live-config ${kind} exits cleanly`);
  const records = existsSync(events)
    ? readFileSync(events, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line))
    : [];
  const started = records.filter((record) => record.event === "tool.started");
  const refused = records.find((record) => record.event === "tool.finished" && record.status === "error"
    && /permission|prevents you from using|denied|not allowed/i.test(`${record.message ?? ""} ${record.response_body ?? ""}`));
  if (started.length > 0) {
    assert.ok(refused, `the 2.x config refused the ${kind} call`);
    console.log(`live config ${kind}: ${records.length} records, refused ${refused.tool ?? "the tool"}`);
    return;
  }
  // A denied tool is hidden from the session on 2.x, so the model cannot even attempt it: its own reply says so.
  const said = (run.stdout ?? "").split("\n").filter((line) => line.startsWith("{"))
    .map((line) => { try { const ev = JSON.parse(line); return ev.type === "text" ? ev.part.text : ""; } catch { return ""; } })
    .join(" ");
  assert.match(said, new RegExp(`no (write|edit|task)|can't do (that|this)|don't have|not available|tool set`, "i"),
    `the 2.x config hid the ${kind} tool and the model said so`);
  console.log(`live config ${kind}: the tool is not in the session (${records.length} records); the model reported it unavailable`);
}

function live(which, args) {
  const [bin, cwd, model, deny, events, pluginDir] = args;
  if (!bin || !cwd || !model) throw new Error(`${which} needs <bin> <cwd> <model> ${which === "--live-guard" ? "<denyFile> <eventsFile> [<pluginDir>]" : ""}`);
  const env = { ...process.env, WS_PROJECT: "oc2-probe", PWD: cwd };
  delete env.WS_RUN_EVENTS;
  delete env.WS_RUN_DENY;
  if (which === "--live-guard") {
    if (!deny || !events) throw new Error("--live-guard needs <denyFile> <eventsFile>");
    env.WS_RUN_DENY = deny;
    env.WS_RUN_EVENTS = events;
    // Without a plugin package in the config the plugins load only from a discovered `.opencode/plugins`; naming
    // the workspace's package here proves they load in a project whose checkout has none.
    if (pluginDir) {
      env.OPENCODE_CONFIG_CONTENT = JSON.stringify({
        $schema: "https://opencode.ai/config.json",
        share: "disabled",
        autoupdate: false,
        permission: { "*": "allow" },
        plugins: [resolve(pluginDir)],
      });
    }
  }
  const prompt = which === "--live-guard"
    ? `Use the shell tool to run exactly this command: python3 "-c" 'print(1)'. Then reply with DONE.`
    : "Reply with exactly: live reply";
  const run = spawnSync(bin, ["run", "--standalone", "--print-logs", "--format", "json", "--auto", "-m", model, prompt], { cwd, env, encoding: "utf8", timeout: 120000 });
  process.stdout.write(run.stdout ?? "");
  process.stderr.write(run.stderr ?? "");
  assert.equal(run.status, 0, `${which} exits cleanly`);
  if (which === "--live-guard") {
    const records = readFileSync(events, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line));
    const failed = records.find((record) => record.event === "tool.finished" && record.status === "error");
    assert.ok(failed, "run-events records the refused tool call");
    assert.match(`${failed.message ?? ""} ${failed.response_body ?? ""}`, /prevents you from using/, "the deny guard refused the call");
    assert.ok(records.some((record) => record.event === "tool.started"), "run-events records the tool start");
    console.log(`live deny guard: ${records.length} records, refused ${failed.tool ?? "a tool"}`);
  } else {
    const saved = readFileSync(join(cwd, "runs", "oc2-probe", "replies.md"), "utf8");
    assert.match(saved, /live reply/, "reply-log saved the real completed text");
    console.log("live reply log: saved the reply");
  }
}
