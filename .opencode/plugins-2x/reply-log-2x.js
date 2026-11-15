import { appendFileSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { Plugin } from "@opencode/plugin";

// 2.x has no `experimental.text.complete`; `session.text.ended` carries the completed text but is read-only, so
// this port saves the reply and its dated entry and cannot put the `━━ HH:MM ━━` banner on the visible reply.
function readSlug(directory, pinned) {
  if (pinned) return pinned.trim();
  const fromEnv = (process.env.WS_PROJECT ?? "").trim();
  if (fromEnv) return fromEnv;
  try {
    return readFileSync(join(directory, "state", "current"), "utf8").split("\n")[0].trim();
  } catch {
    return "";
  }
}

function stamp(when, timeZone) {
  const parts = { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" };
  const zoneParts = { timeZoneName: "short" };
  if (timeZone) {
    parts.timeZone = timeZone;
    zoneParts.timeZone = timeZone;
  }
  const fields = new Intl.DateTimeFormat("en-CA", parts).formatToParts(when);
  const field = (type) => fields.find((part) => part.type === type)?.value ?? "";
  const zone = new Intl.DateTimeFormat("en-US", zoneParts).formatToParts(when).find((part) => part.type === "timeZoneName")?.value ?? "";
  return { date: `${field("year")}-${field("month")}-${field("day")}`, time: `${field("hour")}:${field("minute")}`, zone };
}

function localStamp(when, timeZone) {
  if (!timeZone) return stamp(when, "");
  try {
    return stamp(when, timeZone);
  } catch (error) {
    console.error(`reply-log: timezone '${timeZone}' could not be used (${error.message}); using this machine's local time`);
    return stamp(when, "");
  }
}

function saveReply(directory, slug, header, text) {
  const file = join(directory, "runs", slug, "replies.md");
  try {
    mkdirSync(dirname(file), { recursive: true });
    appendFileSync(file, `## ${header}\n\n${text}\n\n`);
  } catch (error) {
    // The reply is already on its way to the screen; a full disk must not cost the session its answer.
    console.error(`reply-log: could not save the reply to ${file}: ${error.message}`);
  }
}

export default Plugin.define({
  id: "cg.reply-log",
  async setup(ctx) {
    // Deliberate: a headless builder sets WS_RUN_EVENTS and its reply is a result document, not an orchestrator reply.
    if (process.env.WS_RUN_EVENTS) return;
    const options = ctx.options ?? {};
    const directory = options.directory ?? ctx.location?.directory ?? process.cwd();
    const slug = readSlug(directory, options.slug);
    // A slug becomes a path component; anything else is a broken selection, not a project to write under.
    if (!/^[A-Za-z0-9._-]+$/.test(slug)) {
      if (slug) console.error(`reply-log: project '${slug}' is not a usable slug; the reply was not saved`);
      return;
    }
    const when = typeof options.now === "function" ? options.now : () => new Date();
    const timeZone = options.timeZone ?? process.env.WS_TZ ?? "";
    const pending = new Map();

    const flush = (sessionID) => {
      const parts = pending.get(sessionID);
      if (!parts?.size) return;
      pending.delete(sessionID);
      const text = [...parts.values()].join("\n\n").trimEnd();
      if (!text) return;
      const { date, time, zone } = localStamp(when(), timeZone);
      saveReply(directory, slug, `${date} ${time} ${zone}`.trim(), text);
    };

    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          const data = event.data ?? {};
          switch (event.type) {
            case "session.text.ended": {
              const text = typeof data.text === "string" ? data.text : "";
              if (!text.trim()) break;
              let parts = pending.get(data.sessionID);
              if (!parts) pending.set(data.sessionID, (parts = new Map()));
              // One text part per ordinal; a repeated event for the same part does not double the entry.
              parts.set(`${data.assistantMessageID ?? event.id}:${data.ordinal ?? ""}`, text);
              break;
            }
            case "session.idle":
            case "session.execution.succeeded":
              flush(data.sessionID);
              break;
            default:
              break;
          }
        }
      } catch (error) {
        if (error.name !== "AbortError") console.error(`reply-log: event stream failed: ${error.message}`);
      }
    })();

    return () => controller.abort();
  },
});
