// Run by scripts/selftest.sh. Proves the per-line plugin layout the 2.x session needs:
// - no plugin file sits directly in .opencode/plugins/, the directory both lines auto-discover (a 1.x file there is
//   rejected on every 2.x start);
// - every file in .opencode/plugins-2x/ default-exports a 2.x definition ({ id, setup }, or Plugin.define's result)
//   and no file in .opencode/plugins-1x/ does;
// - `ws oc` writes each line's own plugin list into the config it hands OpenCode: the 2.x directory under `plugins`,
//   the three 1.x files as file URLs under `plugin`.
// `--live <opencode-bin>` also starts the installed 2.x CLI in a throwaway XDG prefix with that generated config and
// checks its log: the plugins-2x directory loads as one module and no plugin fails to load. It needs a real binary and
// starts a server, so the suite never runs it.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { registerHooks } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const pluginRoot = join(root, ".opencode");
const twoXDir = join(pluginRoot, "plugins-2x");
const oneXDir = join(pluginRoot, "plugins-1x");
// A fixed non-secret string, so a later grep can show it never reached a log or a tracked file.
const SESSION_PASSWORD = "session-password-fixture-2b7d";
const liveIndex = process.argv.indexOf("--live");
const evidenceIndex = process.argv.indexOf("--evidence");

// A plain node import of reply-log-2x.js has no @opencode/plugin package to resolve, so the test points the bare
// specifier at the same identity Plugin.define the binary provides.
const stubDir = mkdtempSync(join(tmpdir(), "cg-oc-config-plugin-"));
// Removed at exit rather than at the end of the imports below: an assertion that fires first would otherwise leave
// the tree behind, once per failing run.
process.on("exit", () => rmSync(stubDir, { recursive: true, force: true }));
const stub = join(stubDir, "opencode-plugin.mjs");
writeFileSync(stub, "export const Plugin = { define: (definition) => definition };\n");
const hooks = registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "@opencode/plugin") return { url: pathToFileURL(stub).href, shortCircuit: true };
    return nextResolve(specifier, context);
  },
});

const jsFiles = (dir) => (existsSync(dir) ? readdirSync(dir).filter((name) => name.endsWith(".js")).sort() : []);
const isDefinition = (value) => Boolean(value) && typeof value === "object" && typeof value.id === "string"
  && value.id !== "" && typeof value.setup === "function";

// The 2.x auto-discovery directory holds no plugin file: both lines scan it, and a 1.x file there fails to load.
if (existsSync(join(pluginRoot, "plugins"))) {
  assert.deepEqual(jsFiles(join(pluginRoot, "plugins")), [], ".opencode/plugins/ has no .js file directly in it");
}

// Each 2.x file is a 2.x definition, including index.js, which a configured directory is loaded as.
const twoX = jsFiles(twoXDir);
assert.deepEqual(twoX, ["cold-start-2x.js", "index.js", "reply-log-2x.js"],
  "the 2.x plugin directory holds the two plugins and the index.js that composes them, and nothing else");
for (const name of twoX) {
  const mod = await import(pathToFileURL(join(twoXDir, name)).href);
  assert.ok(isDefinition(mod.default), `${name} default-exports a 2.x definition with an id and setup`);
}

// index.js is the one module the directory loads, so it has to bring up both plugins: cold-start's session hooks and
// the reply log's event subscription, with the reply log's cleanup released.
const composed = (await import(pathToFileURL(join(twoXDir, "index.js")).href)).default;
const registered = [];
let subscribed = false;
const composeDir = mkdtempSync(join(tmpdir(), "cg-oc-config-compose-"));
delete process.env.WS_RUN_EVENTS;
delete process.env.WS_PROJECT;
const composeCtx = {
  options: { directory: composeDir, slug: "compose-fixture", script: join(composeDir, "none.sh"), settings: join(composeDir, "none.sh") },
  location: { directory: composeDir },
  session: { hook: async (name) => (registered.push(name), { dispose: async () => {} }) },
  event: { subscribe: () => { subscribed = true; return { async *[Symbol.asyncIterator]() { await new Promise(() => {}); } }; } },
};
const cleanup = await composed.setup(composeCtx);
assert.ok(registered.includes("context") && registered.includes("compaction"),
  "index.js registers cold-start-2x's session hooks");
assert.equal(subscribed, true, "index.js starts reply-log-2x's event subscription");
assert.equal(typeof cleanup, "function", "index.js returns a cleanup");
cleanup();
rmSync(composeDir, { recursive: true, force: true });

// No 1.x file claims a 2.x definition: the loader would call its setup and the 1.x export would never run.
const oneX = jsFiles(oneXDir);
assert.deepEqual(oneX, ["cold-start.js", "reply-log.js", "reply-time.js"], "the 1.x plugin directory holds the three 1.x files");
for (const name of oneX) {
  const mod = await import(pathToFileURL(join(oneXDir, name)).href);
  assert.equal(isDefinition(mod.default), false, `${name} is a 1.x plugin, not a 2.x definition`);
  assert.equal(typeof mod.default, "undefined", `${name} exports no default, as the 1.x loader expects`);
}
hooks.deregister();

// The generated config for each line names exactly that line's plugins. It comes from `ws oc --print`, the launcher's
// own path, against a fixture project so the run never touches a real one.
const fixtureSlug = `oc-config-fixture-${process.pid}`;
const fixturePath = join(root, "projects", `${fixtureSlug}.conf`);
const home = mkdtempSync(join(tmpdir(), "cg-oc-config-home-"));
const runsDir = join(root, "runs", fixtureSlug);
const plansDir = join(root, "plans", fixtureSlug);
mkdirSync(join(home, ".config", "opencode"), { recursive: true });
writeFileSync(join(home, ".config", "opencode", "orchestrator.json"), JSON.stringify({
  $schema: "https://opencode.ai/config.json", share: "disabled",
  permission: { bash: { "*": "allow" }, edit: "allow" },
  mcp: { playwright: { type: "local", command: ["npx", "playwright"], enabled: false } },
}, null, 2));
writeFileSync(fixturePath, `PROJECT_PATH="${root}"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n`);

const launch = (line) => spawnSync(join(root, "bin", "ws"), ["oc", fixtureSlug, "--print"], {
  cwd: root,
  env: { ...process.env, HOME: home, WS_OPENCODE_LINE: line, WS_OC_PORT: "45996" },
  encoding: "utf8",
  timeout: 120000,
});

try {
  const two = launch("2");
  assert.equal(two.status, 0, `ws oc --print on 2.x exits 0: ${two.stderr}`);
  const twoConfigPath = join(runsDir, "oc.config.json");
  assert.ok(existsSync(twoConfigPath), "the 2.x launcher writes runs/<slug>/oc.config.json");
  assert.ok(two.stdout.includes(`OPENCODE_CONFIG=${twoConfigPath}`), "the 2.x launch line names that config");
  const twoConfig = JSON.parse(readFileSync(twoConfigPath, "utf8"));
  assert.deepEqual(twoConfig.plugins, [twoXDir], "the 2.x config names exactly the plugins-2x directory");
  assert.equal(twoConfig.plugin, undefined, "the 2.x config carries no 1.x plugin list");

  const one = launch("1");
  assert.equal(one.status, 0, `ws oc --print on 1.x exits 0: ${one.stderr}`);
  const oneConfigPath = join(runsDir, "oc.config.1x.json");
  assert.ok(existsSync(oneConfigPath), "the 1.x launcher writes runs/<slug>/oc.config.1x.json");
  assert.ok(one.stdout.includes(`OPENCODE_CONFIG=${oneConfigPath}`), "the 1.x launch line names that config");
  const oneConfig = JSON.parse(readFileSync(oneConfigPath, "utf8"));
  assert.deepEqual(oneConfig.plugin, oneX.map((name) => `file://${join(oneXDir, name)}`),
    "the 1.x config names each 1.x plugin as a file URL");
  assert.equal(oneConfig.plugins, undefined, "the 1.x config carries no 2.x plugin directory");
  assert.equal(oneConfig.share, "disabled", "the 1.x config keeps the orchestrator's own keys");
  // --evidence keeps the two generated configs for a run's record; the suite never passes it.
  if (evidenceIndex !== -1) {
    const dir = resolve(process.argv[evidenceIndex + 1] ?? "");
    mkdirSync(dir, { recursive: true });
    for (const [from, name] of [[twoConfigPath, "oc.config.json"], [oneConfigPath, "oc.config.1x.json"]]) {
      writeFileSync(join(dir, name), readFileSync(from, "utf8"));
    }
  }
} finally {
  rmSync(fixturePath, { force: true });
  rmSync(runsDir, { recursive: true, force: true });
  rmSync(plansDir, { recursive: true, force: true });
  rmSync(home, { recursive: true, force: true });
}

console.log(`plugin layout ok: ${twoX.length} 2.x definitions, ${oneX.length} 1.x plugins, each line's config naming its own`);

// A wake the session schedules has to authenticate to the service it started, and the service writes its password to
// its own state file: `ws oc` exports it for every client it starts, and a missing file exports nothing.
const sessionHome = mkdtempSync(join(tmpdir(), "cg-oc-config-session-"));
const stubBin = join(sessionHome, "bin");
mkdirSync(stubBin);
writeFileSync(join(stubBin, "opencode"),
  `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> ${JSON.stringify(join(sessionHome, "calls"))}\n`
  + `printf '%s' "\${OPENCODE_PASSWORD:-}" > ${JSON.stringify(join(sessionHome, "password"))}\nexit 0\n`, { mode: 0o755 });
mkdirSync(join(sessionHome, "state", "opencode"), { recursive: true });
writeFileSync(join(sessionHome, "state", "opencode", "service.json"),
  `{"url":"http://127.0.0.1:4096","password":"${SESSION_PASSWORD}","pid":4242}\n`, { mode: 0o600 });
mkdirSync(join(sessionHome, ".config", "opencode"), { recursive: true });
writeFileSync(join(sessionHome, ".config", "opencode", "orchestrator.json"), "{\"share\":\"disabled\"}\n");
const sessionSlug = `oc-config-session-${process.pid}`;
const sessionConf = join(root, "projects", `${sessionSlug}.conf`);
writeFileSync(sessionConf, `PROJECT_PATH="${root}"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n`);
const startSession = (stateHome) => {
  const env = { ...process.env, HOME: sessionHome, PATH: `${stubBin}:${process.env.PATH}`, WS_OPENCODE_LINE: "2", XDG_STATE_HOME: stateHome };
  delete env.OPENCODE_PASSWORD;
  delete env.OPENCODE_SERVER_PASSWORD;
  return spawnSync(join(root, "bin", "ws"), ["oc", sessionSlug, "--port", "45998"], { cwd: root, env, encoding: "utf8", timeout: 120000 });
};
try {
  rmSync(join(sessionHome, "password"), { force: true });
  const started = startSession(join(sessionHome, "state"));
  assert.equal(started.status, 0, `ws oc starts on 2.x: ${started.stderr}`);
  assert.equal(readFileSync(join(sessionHome, "password"), "utf8"), SESSION_PASSWORD,
    "the session exports the service's password so a wake it schedules carries it");
  assert.equal(started.stdout.includes(SESSION_PASSWORD) || started.stderr.includes(SESSION_PASSWORD), false,
    "the value is in no output the launcher prints");
  rmSync(join(sessionHome, "password"), { force: true });
  const noFile = startSession(join(sessionHome, "absent"));
  assert.equal(noFile.status, 0, `ws oc starts with no service file: ${noFile.stderr}`);
  assert.equal(readFileSync(join(sessionHome, "password"), "utf8"), "", "with no service file nothing is exported");
} finally {
  rmSync(sessionConf, { force: true });
  rmSync(join(root, "runs", sessionSlug), { recursive: true, force: true });
  rmSync(join(root, "plans", sessionSlug), { recursive: true, force: true });
  rmSync(sessionHome, { recursive: true, force: true });
}
console.log("the 2.x session exports the service password, and nothing when the service wrote none");

if (liveIndex !== -1) live(process.argv[liveIndex + 1] ?? "opencode");

// Start the installed 2.x CLI in a throwaway prefix with the generated 2.x config: a plugin that does not load on
// this line shows up in its log as "failed to load plugin", which is the failure this layout removes.
function live(bin) {
  const base = mkdtempSync(join(tmpdir(), "cg-oc-config-live-"));
  const project = join(base, "project");
  mkdirSync(project);
  for (const key of ["data", "config", "state", "cache", "home"]) mkdirSync(join(base, key));
  const slug = `oc-config-live-${process.pid}`;
  const confPath = join(root, "projects", `${slug}.conf`);
  writeFileSync(confPath, `PROJECT_PATH="${root}"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\n`);
  const runs = join(root, "runs", slug);
  try {
    const print = spawnSync(join(root, "bin", "ws"), ["oc", slug, "--print"], {
      cwd: root, env: { ...process.env, HOME: join(base, "home"), WS_OPENCODE_LINE: "2", WS_OC_PORT: "45997" },
      encoding: "utf8", timeout: 120000,
    });
    assert.equal(print.status, 0, `ws oc --print on 2.x exits 0: ${print.stderr}`);
    const config = join(runs, "oc.config.json");
    const env = { ...process.env };
    for (const key of ["OPENCODE_CONFIG_CONTENT", "OPENCODE_PASSWORD", "OPENCODE_SERVER_PASSWORD"]) delete env[key];
    Object.assign(env, {
      OPENCODE_CONFIG: config, PWD: project,
      HOME: join(base, "home"), XDG_DATA_HOME: join(base, "data"), XDG_CONFIG_HOME: join(base, "config"),
      XDG_STATE_HOME: join(base, "state"), XDG_CACHE_HOME: join(base, "cache"),
    });
    // `run --standalone` loads the config's plugins before it needs a model; the reply is beside the point.
    spawnSync(bin, ["run", "--standalone", "--print-logs", "--format", "json", "reply with ok"], {
      cwd: project, env, encoding: "utf8", timeout: 180000,
    });
    const logDir = join(base, "data", "opencode", "log");
    const text = existsSync(logDir) ? readdirSync(logDir).map((file) => readFileSync(join(logDir, file), "utf8")).join("\n") : "";
    const failed = text.split("\n").filter((line) => line.includes("failed to load plugin"));
    assert.deepEqual(failed, [], "the 2.x log has no failed to load plugin line");
    const loading = text.split("\n").filter((line) => line.includes('msg="loading plugin"'));
    console.log(`live 2.x log: ${loading.length} loading line(s), ${failed.length} failed line(s)`);
    console.log(loading.map((line) => line.replace(/^timestamp=\S+ /, "")).join("\n"));
    // --evidence keeps the log's plugin and version lines: the throwaway prefix dies with this run.
    if (evidenceIndex !== -1) {
      const dir = resolve(process.argv[evidenceIndex + 1] ?? "");
      mkdirSync(dir, { recursive: true });
      const excerpt = text.split("\n").filter((line) => /plugin|version=[0-9]/.test(line) && !/watcher/.test(line));
      writeFileSync(join(dir, "server-log-plugins.log"), `${excerpt.join("\n")}\n`);
    }
    assert.ok(loading.some((line) => line.includes(`id=${twoXDir}`) && line.includes(`entrypoint=file://${join(twoXDir, "index.js")}`)),
      "the 2.x session loads the plugins-2x directory as one module");
  } finally {
    rmSync(confPath, { force: true });
    rmSync(runs, { recursive: true, force: true });
    rmSync(join(root, "plans", slug), { recursive: true, force: true });
    rmSync(base, { recursive: true, force: true });
  }
}
