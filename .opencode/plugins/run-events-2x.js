import { appendFileSync } from "node:fs";

const LIMIT = /usage limit|rate limit|too many requests|quota|limit reached|free limit/i;

// 2.x publishes events as `{ type, data }`, and its names differ from 1.x. The records below keep the field names
// scripts/opencode_run.py and scripts/check-result.sh read, so a 2.x run's denials and provider limits land in the
// same checks a 1.x run's do.
function permissionAsked(data = {}) {
  return {
    request_id: data.id ?? "",
    session_id: data.sessionID ?? "",
    tool: data.action ?? "",
    patterns: Array.isArray(data.resources) ? data.resources : data.resources ? [data.resources] : [],
    title: data.action ?? "",
    metadata: data.metadata ?? {},
  };
}

function errorFields(error = {}) {
  const message = error.message ?? "";
  const body = error.response?.body ?? "";
  return {
    error: error.type ?? "",
    status: error.status ?? null,
    message,
    response_headers: {},
    response_body: body,
    retryable: null,
    limit: error.status === 429 || LIMIT.test(message) || body.includes("GoUsageLimitError"),
  };
}

function toolFields(data = {}) {
  return {
    session_id: data.sessionID ?? "",
    message_id: data.assistantMessageID ?? "",
    tool_call_id: data.id ?? "",
    tool_input: data.input ?? {},
  };
}

export default {
  id: "cg.run-events",
  async setup(ctx) {
    const file = ctx.options?.file ?? process.env.WS_RUN_EVENTS;
    if (!file) return;

    const record = (event, fields) => {
      try {
        appendFileSync(file, `${JSON.stringify({ event, time: Date.now(), ...fields })}\n`);
      } catch (error) {
        // The run must still finish when the evidence file is unwritable; the reason goes to the run's own log.
        console.error(`run-events: cannot append to ${file}: ${error.message}`);
      }
    };

    const controller = new AbortController();

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const data = event.data ?? {};
          switch (event.type) {
            case "permission.asked":
              record("permission.asked", permissionAsked(data));
              break;
            case "permission.replied":
              record("permission.replied", {
                request_id: data.requestID ?? "",
                session_id: data.sessionID ?? "",
                reply: data.reply ?? "",
              });
              break;
            case "session.retry.scheduled": {
              const error = data.error ?? {};
              const message = error.message ?? "";
              record("session.retry", {
                session_id: data.sessionID ?? "",
                attempt: data.attempt ?? null,
                message,
                next: data.at ?? null,
                status: error.status ?? null,
                action: null,
                response_headers: {},
                limit: error.status === 429 || LIMIT.test(message) || (error.response?.body ?? "").includes("GoUsageLimitError"),
              });
              break;
            }
            case "session.execution.failed":
              record("session.error", { session_id: data.sessionID ?? "", ...errorFields(data.error ?? {}) });
              break;
            case "session.tool.called":
              record("tool.started", toolFields(data));
              break;
            case "session.tool.success":
              record("tool.finished", { ...toolFields(data), status: "completed" });
              break;
            case "session.tool.failed":
              record("tool.finished", {
                ...toolFields(data),
                ...errorFields(data.error ?? {}),
                status: "error",
              });
              break;
            case "session.compaction.started":
              record("session.compaction.started", { session_id: data.sessionID ?? "", reason: data.reason ?? "" });
              break;
            case "session.compaction.ended":
              record("session.compaction.ended", { session_id: data.sessionID ?? "", reason: data.reason ?? "" });
              break;
            case "session.compaction.failed":
              record("session.compaction.failed", {
                session_id: data.sessionID ?? "",
                reason: data.reason ?? "",
                ...errorFields(data.error ?? {}),
              });
              break;
            default:
              break;
          }
        }
      } catch (error) {
        if (error.name !== "AbortError") console.error(`run-events: event stream failed: ${error.message}`);
      }
    })();

    return () => controller.abort();
  },
};
