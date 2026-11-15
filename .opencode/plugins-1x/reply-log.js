import { appendFileSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

function readSlug(directory) {
  const pinned = (process.env.WS_PROJECT ?? "").trim();
  if (pinned) return pinned;
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

export const ReplyLogPlugin = async (input = {}, options = {}) => {
  // Deliberate: a headless builder sets WS_RUN_EVENTS and its reply is a result document, not an orchestrator reply.
  if (process.env.WS_RUN_EVENTS) return {};
  const opts = options ?? {};
  const directory = input.directory ?? process.cwd();
  const done = new Set();

  return {
    // A finished reply gets the local-time banner, and one dated entry in the project's log.
    "experimental.text.complete": async (input, output) => {
      try {
        if (typeof output?.text !== "string" || output.text.trim() === "") return;
        const key = input?.messageID || `${input?.sessionID ?? "unknown"}:${input?.partID ?? "unknown"}`;
        if (done.has(key)) return;
        done.add(key);
        const when = typeof opts.now === "function" ? opts.now() : new Date();
        const timeZone = opts.timeZone ?? process.env.WS_TZ ?? "";
        const { date, time, zone } = localStamp(when, timeZone);
        const banner = `━━ ${time} ━━`;
        const slug = readSlug(directory);
        // A slug becomes a path component; anything else is a broken selection, not a project to write under.
        if (/^[A-Za-z0-9._-]+$/.test(slug)) {
          saveReply(directory, slug, `${date} ${time} ${zone}`.trim(), output.text.trimEnd());
        } else if (slug) {
          console.error(`reply-log: project '${slug}' is not a usable slug; the reply was not saved`);
        }
        output.text = `${banner}\n\n${output.text}`;
      } catch (error) {
        console.error(`reply-log: ${error.message}`);
      }
    },
  };
};
