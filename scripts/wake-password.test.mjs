// Run by scripts/selftest.sh. Drives the password resolution a wake and a session start share
// (scripts/oc-service-password.sh -> oc_service_password in scripts/lib.sh) against a fixture XDG_STATE_HOME, for
// the four cases it has to get right:
// - the 2.x service's file is found: the value goes to stdout and nowhere else;
// - the file is absent: no value, exit 1, one note naming the file, and no failure of the caller;
// - the file is malformed: no value, exit 1, one note;
// - the installed line is 1.x: today's behaviour, nothing read even when the file exists.
// A password already in the environment wins over the file. The value never reaches stderr, an argument or a file the
// test can see; the marker below is a fixed non-secret string so a later grep can prove it stayed out of every log.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const script = join(root, "scripts", "oc-service-password.sh");
const MARKER = "wake-password-fixture-9c1f";
const base = mkdtempSync(join(tmpdir(), "cg-wake-password-"));

const stateWith = (name, content) => {
  const state = join(base, `state-${name}`);
  mkdirSync(join(state, "opencode"), { recursive: true });
  if (content !== undefined) writeFileSync(join(state, "opencode", "service.json"), content, { mode: 0o600 });
  return state;
};

const run = (env, args = ["--note"]) => {
  const clean = { ...process.env };
  for (const key of ["OPENCODE_PASSWORD", "OPENCODE_SERVER_PASSWORD", "WS_OPENCODE_LINE", "XDG_STATE_HOME"]) delete clean[key];
  const out = spawnSync("bash", [script, ...args], { cwd: root, env: { ...clean, ...env }, encoding: "utf8", timeout: 60000 });
  assert.equal(out.error, undefined, "the script starts");
  assert.equal((out.stdout + out.stderr).includes(MARKER) && !out.stdout.includes(MARKER), false,
    "the value never reaches stderr");
  return out;
};

try {
  // Found: stdout only, exit 0, nothing on stderr.
  const found = stateWith("found", `{"url":"http://127.0.0.1:4096","password":"${MARKER}","pid":4242}\n`);
  const hit = run({ WS_OPENCODE_LINE: "2", XDG_STATE_HOME: found });
  assert.equal(hit.status, 0, "a found password exits 0");
  assert.equal(hit.stdout, `${MARKER}\n`, "the value is the script's whole stdout");
  assert.equal(hit.stderr, "", "nothing is written to stderr when the file reads");

  // Absent: no value, one note naming the file, and the same no-note silence a session start wants.
  const absent = stateWith("absent");
  const miss = run({ WS_OPENCODE_LINE: "2", XDG_STATE_HOME: absent });
  assert.equal(miss.status, 1, "an absent file exits 1 instead of printing a value");
  assert.equal(miss.stdout, "", "an absent file prints no value");
  assert.equal(miss.stderr.trim().split("\n").length, 1, "an absent file says so in one line");
  assert.match(miss.stderr, /service\.json/, "the note names the file it looked for");
  assert.equal(run({ WS_OPENCODE_LINE: "2", XDG_STATE_HOME: absent }, []).stderr, "",
    "without --note a caller that only wants the value gets no line");

  // Malformed: invalid JSON, and JSON whose password is not a non-empty string.
  for (const [name, content] of [
    ["notjson", `{"url":"http://127.0.0.1:4096","password":"${MARKER}"\n`],
    ["number", `{"password":42}\n`],
    ["empty", `{"password":""}\n`],
  ]) {
    const broken = run({ WS_OPENCODE_LINE: "2", XDG_STATE_HOME: stateWith(name, content) });
    assert.equal(broken.status, 1, `${name}: a malformed file exits 1`);
    assert.equal(broken.stdout, "", `${name}: a malformed file prints no value`);
    assert.equal(broken.stderr.trim().split("\n").length, 1, `${name}: a malformed file says so in one line`);
  }

  // 1.x: unchanged, nothing read even though the file is there.
  const legacy = run({ WS_OPENCODE_LINE: "1", XDG_STATE_HOME: found });
  assert.equal(legacy.status, 1, "the 1.x line resolves no password from the file");
  assert.equal(legacy.stdout, "", "the 1.x line prints no value");
  assert.equal(legacy.stderr, "", "the 1.x line stays silent");

  // A password already in either variable wins over the file.
  for (const key of ["OPENCODE_PASSWORD", "OPENCODE_SERVER_PASSWORD"]) {
    const set = run({ WS_OPENCODE_LINE: "2", XDG_STATE_HOME: found, [key]: "from-the-environment" });
    assert.equal(set.status, 1, `${key} already set: nothing is resolved from the file`);
    assert.equal(set.stdout, "", `${key} already set: no value is printed`);
    assert.equal((set.stdout + set.stderr).includes(MARKER), false, `${key} already set: the file's value stays unread`);
  }
} finally {
  rmSync(base, { recursive: true, force: true });
}

console.log("wake password resolution ok: found, absent, malformed and the 1.x line behave, and the value stays on stdout");
