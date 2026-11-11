// Run by scripts/selftest.sh. Calls the reply-log plugin's hook with the shapes OpenCode passes, against a
// throwaway workspace, so no session or model is involved.
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const pluginPath = new URL("../.opencode/plugins/reply-log.js", import.meta.url);

test("the reply-log plugin writes one banner and one dated entry per reply", async () => {
  delete process.env.WS_RUN_EVENTS;
  delete process.env.WS_PROJECT;
  process.env.WS_TZ = "UTC";
  const tempRoot = mkdtempSync(join(tmpdir(), "reply-log-"));
  try {
    const { ReplyLogPlugin } = await import(pluginPath.href);
    assert.equal(typeof ReplyLogPlugin, "function", "the plugin exports ReplyLogPlugin");

    mkdirSync(join(tempRoot, "state"), { recursive: true });
    writeFileSync(join(tempRoot, "state", "current"), "demo\n");
    const clock = (iso) => () => new Date(iso);
    const hooks = await ReplyLogPlugin({ directory: tempRoot }, { now: clock("2026-11-09T11:40:00Z") });
    const complete = hooks["experimental.text.complete"];
    assert.equal(typeof complete, "function", "the plugin registers the text-complete hook");

    const output = { text: "merged at 11:40" };
    await complete({ sessionID: "s1", messageID: "m1", partID: "p1" }, output);
    assert.equal(output.text, "━━ 11:40 ━━\n\nmerged at 11:40", "the banner is on the reply");
    const saved = readFileSync(join(tempRoot, "runs", "demo", "replies.md"), "utf8");
    assert.equal(saved, "## 2026-11-09 11:40 UTC\n\nmerged at 11:40\n\n", "the entry is dated and holds the reply");
    assert.equal(saved.includes("━━"), false, "the banner is not written into the entry");

    await complete({ sessionID: "s1", messageID: "m1", partID: "p2" }, output);
    assert.equal(readFileSync(join(tempRoot, "runs", "demo", "replies.md"), "utf8"), saved, "one entry per message");

    process.env.WS_PROJECT = "pinned";
    const pinned = await ReplyLogPlugin({ directory: tempRoot }, { now: clock("2026-11-09T11:41:00Z") });
    const pinnedOut = { text: "second" };
    await pinned["experimental.text.complete"]({ messageID: "m2" }, pinnedOut);
    assert.equal(readFileSync(join(tempRoot, "runs", "pinned", "replies.md"), "utf8"),
      "## 2026-11-09 11:41 UTC\n\nsecond\n\n", "WS_PROJECT names the project");
    delete process.env.WS_PROJECT;

    const empty = await ReplyLogPlugin({ directory: tempRoot }, { now: clock("2026-11-09T11:42:00Z") });
    const emptyOut = { text: "   " };
    await empty["experimental.text.complete"]({ messageID: "m3" }, emptyOut);
    assert.equal(emptyOut.text, "   ", "an empty reply is left unchanged");

    process.env.WS_RUN_EVENTS = join(tempRoot, "builder.events.jsonl");
    const skipped = await ReplyLogPlugin({ directory: tempRoot }, { now: clock("2026-11-09T11:43:00Z") });
    assert.deepEqual(skipped, {}, "a builder's run-events file gives the plugin no hooks");
  } finally {
    rmSync(tempRoot, { recursive: true, force: true });
  }
});
