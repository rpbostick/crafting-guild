import { appendFileSync } from "node:fs";

const LIMIT = /usage limit|rate limit|too many requests|quota|limit reached|free limit/i;
const LIMIT_REASONS = new Set(["account_rate_limit", "free_tier_limit"]);

function permissionFields(permission = {}) {
  const patterns = permission.patterns ?? (permission.pattern ? [permission.pattern] : []);
  return {
    request_id: permission.id ?? permission.permissionID ?? "",
    session_id: permission.sessionID ?? "",
    tool: permission.permission ?? permission.type ?? permission.title ?? "",
    patterns,
    title: permission.title ?? "",
    metadata: permission.metadata ?? {},
  };
}

function errorFields(error = {}) {
  const data = error?.data ?? {};
  const message = data.message ?? data.responseBody ?? "";
  const responseBody = data.responseBody ?? "";
  return {
    error: error?.name ?? "",
    status: data.statusCode ?? null,
    message,
    response_headers: data.responseHeaders ?? {},
    response_body: responseBody,
    retryable: data.isRetryable ?? null,
    limit: data.statusCode === 429 || LIMIT.test(message) || responseBody.includes("GoUsageLimitError"),
  };
}

export const RunEventsPlugin = async (_input = {}, options = {}) => {
  const file = options.file ?? process.env.WS_RUN_EVENTS;
  if (!file) return {};

  const record = (event, fields) => {
    try {
      appendFileSync(file, `${JSON.stringify({ event, time: Date.now(), ...fields })}\n`);
    } catch (error) {
      // The run must still finish when the evidence file is unwritable; the reason goes to the run's own log.
      console.error(`run-events: cannot append to ${file}: ${error.message}`);
    }
  };

  return {
    event: async (input = {}) => {
      const event = input.event;
      if (!event || typeof event.type !== "string") return;
      const properties = event.properties ?? {};
      switch (event.type) {
        case "permission.asked":
        case "permission.updated":
          record("permission.asked", permissionFields(properties));
          break;
        case "permission.replied":
          record("permission.replied", {
            request_id: properties.requestID ?? properties.permissionID ?? "",
            session_id: properties.sessionID ?? "",
            reply: properties.reply ?? properties.response ?? "",
          });
          break;
        case "session.status": {
          const status = properties.status ?? {};
          if (status.type === "retry") {
            record("session.retry", {
              session_id: properties.sessionID ?? "",
              attempt: status.attempt ?? null,
              message: status.message ?? "",
              next: status.next ?? null,
              action: status.action ?? null,
              limit: LIMIT.test(status.message ?? "") || LIMIT_REASONS.has(status.action?.reason ?? ""),
            });
          }
          break;
        }
        case "session.error": {
          const error = errorFields(properties.error ?? {});
          record("session.error", { session_id: properties.sessionID ?? "", ...error });
          break;
        }
        case "message.part.updated": {
          const part = properties.part ?? {};
          if (part.type === "retry") {
            record("retry.part", {
              session_id: part.sessionID ?? "",
              attempt: part.attempt ?? null,
              ...errorFields(part.error ?? {}),
            });
          }
          break;
        }
        default:
          break;
      }
    },
    "permission.ask": async (permission = {}, output = {}) => {
      record("permission.ask", { ...permissionFields(permission), status: output.status ?? "" });
    },
  };
};
