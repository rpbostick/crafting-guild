import { readFileSync } from "node:fs";

// OpenCode matches a permission rule against the command text with its quotes kept, so `python3 "-c" 1` passes the
// rule `python3 -c*` while the shell runs `python3 -c 1`. This hook runs before the tool and tests the builder's deny
// list (WS_RUN_DENY, the file bin/ws-run reads) against the same text with the quoting removed.
//
// Deliberate: this removes quoting and splits at separators, and stops there, because a full reading of the command
// is a shell parser. It does not see a word only the shell computes: `x=-c; python3 $x 1`. A separator inside a quoted
// word is not a split point, so a commit message that mentions `bash -c` is not refused.
const QUOTED = /\$?'[^']*'|\$?"(?:\\[\s\S]|[^"\\])*"|\\[\s\S]/g;
const SEPARATORS = /[;&|()\n`{}!]/;

function unquoted(word) {
  const text = word.replace(/^\$(?=['"])/, "").replace(/["'\\]/g, "");
  // A substitution inside double quotes is still a command; a separator in any other quoted word is plain text.
  return /\$\(|`/.test(word) ? text : text.replace(new RegExp(SEPARATORS.source, "g"), "_");
}

function simpleCommands(command) {
  return command
    .replace(QUOTED, unquoted)
    .split(SEPARATORS)
    .map((part) => part.trim().replace(/^(?:\w+=\S*\s+)+/, ""))
    .filter(Boolean);
}

// A rule's `*` spans spaces and a trailing ` *` also matches no arguments, as OpenCode's own wildcard does.
function ruleRegex(rule) {
  const body = rule.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, "[\\s\\S]*");
  return new RegExp(`^${body.replace(/ \[\\s\\S\]\*$/, "(?: [\\s\\S]*)?")}$`);
}

export const DenyGuardPlugin = async (_input = {}, options = {}) => {
  const file = options.denyFile ?? process.env.WS_RUN_DENY;
  if (!file) return {};
  const rules = readFileSync(file, "utf8").split("\n").filter(Boolean).map(ruleRegex);
  return {
    "tool.execute.before": async (input = {}, output = {}) => {
      if (input.tool !== "bash") return;
      for (const command of simpleCommands(String(output.args?.command ?? ""))) {
        if (rules.some((rule) => rule.test(command))) {
          // "prevents you from using" is the wording scripts/opencode_run.py counts as a denied call.
          throw new Error(`A deny rule prevents you from using this command with its quotes removed: ${command}`);
        }
      }
    },
  };
};
