import { spawn } from "node:child_process";
import { basename, join } from "node:path";

// The attention handler is the same script Claude Code's hooks call: this plugin only turns OpenCode's events into
// its waiting/resumed lines, so the two clients share one log, one config and one terminal title.
function projectName(directory) {
  return process.env.WS_PROJECT || basename(directory || process.cwd());
}

function field(properties, ...names) {
  for (const name of names) {
    if (properties?.[name]) return properties[name];
  }
  return "";
}

export const AttentionPlugin = async (input = {}, options = {}) => {
  // Deliberate: a headless builder has nobody watching it, and WS_RUN_EVENTS marks that run; no pop-up, no title,
  // nothing in the alert log.
  if (process.env.WS_RUN_EVENTS) return {};

  const directory = input.directory ?? process.cwd();
  const script = options.script ?? process.env.WS_ATTENTION_SCRIPT ?? join(directory, "scripts", "attention.sh");
  const project = projectName(directory);
  // Deliberate: a failed spawn must not fail OpenCode's event handler or interrupt the session; attention is a
  // convenience and the run has to survive without it.
  const run =
    options.run ??
    ((args) => {
      const child = spawn(script, args, { detached: true, stdio: "ignore", env: process.env });
      child.on("error", () => {});
      child.unref();
    });
  const notify = (agent, session, project, reason, event) =>
    run(["--agent", agent, "--session", session, "--project", project, "--reason", reason, "--event", event]);
  const waiting = (session, reason) => notify("opencode", session, project, reason, "waiting");
  const resumed = (session) => run(["--agent", "opencode", "--session", session, "--project", project, "--event", "resumed"]);

  return {
    event: async (input = {}) => {
      const event = input.event;
      if (!event || typeof event.type !== "string") return;
      const properties = event.properties ?? {};
      const session = field(properties, "sessionID", "session_id");
      switch (event.type) {
        case "session.idle":
          waiting(session, "idle");
          break;
        case "permission.asked":
          waiting(session, "permission");
          break;
        case "question.asked":
        case "question.v2.asked":
          waiting(session, "question");
          break;
        case "permission.replied":
        case "question.replied":
        case "question.rejected":
        case "question.v2.replied":
        case "question.v2.rejected":
          resumed(session);
          break;
        default:
          break;
      }
    },
    // OpenCode calls this just before it shows a permission prompt; when it is denied without a prompt, or the rule
    // allows it outright, nothing waits.
    "permission.ask": async (permission = {}, output = {}) => {
      if (output?.status === "deny" || output?.status === "allow") return;
      waiting(field(permission, "sessionID", "session_id"), "permission");
    },
    // The next user message is the answer to an idle session.
    "chat.message": async (input = {}) => {
      resumed(field(input, "sessionID", "session_id"));
    },
  };
};
