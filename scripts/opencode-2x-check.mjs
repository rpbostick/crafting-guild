import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// Proves the two 2.x plugins in .opencode/plugins/ load through the V2 default-definition shape, register the
// hooks they need, and write records the existing readers (scripts/opencode_run.py, scripts/check-result.sh) read.
// The scripts/selftest.sh copy passes the generated deny list; a direct run uses a small one with the same rules.
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const denyGuardPath = resolve(process.argv[2] ?? join(root, ".opencode/plugins/deny-guard-2x.js"));
const runEventsPath = resolve(process.argv[3] ?? join(root, ".opencode/plugins/run-events-2x.js"));
const denyFile = process.argv[4] ? resolve(process.argv[4]) : join(mkdtempSync(join(tmpdir(), "cg-oc2-check-")), "deny.txt");
const temp = mkdtempSync(join(tmpdir(), "cg-oc2-check-"));

if (!process.argv[4]) {
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
  const hooks = {};
  return {
    hooks,
    ctx: {
      options: { denyFile },
      tool: { hook: async (name, callback) => ((hooks[name] = callback), { dispose() {} }) },
    },
  };
}

const { DenyGuardPlugin } = { DenyGuardPlugin: (await import(pathToFileURL(denyGuardPath).href)).default };
assert.equal(typeof DenyGuardPlugin, "object", "the deny guard default-exports a V2 definition object");
assert.equal(typeof DenyGuardPlugin.id, "string", "the deny guard has a stable id");
assert.equal(typeof DenyGuardPlugin.setup, "function", "the deny guard registers through setup");
const guard = withHookDomain();
await DenyGuardPlugin.setup(guard.ctx);
assert.equal(typeof guard.hooks["execute.before"], "function", "the deny guard registers tool execute.before");
const runShell = async (tool, command) => guard.hooks["execute.before"]({ tool, input: { command } });

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

const legacyGuard = await import(pathToFileURL(join(root, "scripts/opencode-plugins/deny-guard.js")).href);
assert.equal(typeof legacyGuard.DenyGuardPlugin, "function", "the 1.x deny guard still exports its plugin function");
const legacyGuardHooks = await legacyGuard.DenyGuardPlugin({}, { denyFile });
assert.equal(typeof legacyGuardHooks["tool.execute.before"], "function", "the 1.x deny guard still registers its hook");
const legacyEvents = await import(pathToFileURL(join(root, "scripts/opencode-plugins/run-events.js")).href);
assert.equal(typeof legacyEvents.RunEventsPlugin, "function", "the 1.x run-events plugin still exports its plugin function");
const legacyEventHooks = await legacyEvents.RunEventsPlugin({}, { file: join(temp, "legacy-events.jsonl") });
assert.equal(typeof legacyEventHooks.event, "function", "the 1.x run-events plugin still registers its event hook");

console.log("opencode 2.x plugins load, register hooks and write records the tool reads ok; the 1.x plugins still export their hooks");
