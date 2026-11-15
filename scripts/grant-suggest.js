// The grant a refused command would have needed, shared by the 1.x and 2.x deny guards and `bin/ws-run`, and read
// back by scripts/denied-summary.py from the refusal each guard throws. Only one rule decides it: the grant whose
// pattern starts with the longest run of the command's own words, so `ls -d node_modules` is answered with
// `Bash(ls *)` when the builder holds `ls *`. A word in a pattern may end in `*`, as a rule's last word does.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

function patternWords(rule) {
  const body = rule.trim().replace(/^Bash\((.*)\)$/, "$1");
  return body.split(/\s+/).filter(Boolean);
}

function wordMatches(word, pattern) {
  if (!pattern.includes("*")) return word === pattern;
  const escaped = pattern
    .split("*")
    .map((part) => part.replace(/[.+?^${}()|[\]\\]/g, "\\$&"))
    .join("[\\s\\S]*");
  return new RegExp(`^${escaped}$`).test(word);
}

// The closest grant for a command, as the `Bash(...)` spelling a task uses, or null when no grant shares its first
// word. `grants` is the builder's grant list, one pattern per line.
export function closestGrant(command, grants) {
  const words = command.trim().split(/\s+/).filter(Boolean);
  let best = null;
  let bestWords = 0;
  for (const grant of grants) {
    const pattern = patternWords(grant);
    let matched = 0;
    while (matched < words.length && matched < pattern.length && wordMatches(words[matched], pattern[matched])) {
      matched += 1;
    }
    if (matched > bestWords) {
      best = pattern.join(" ");
      bestWords = matched;
    }
  }
  return best;
}

// The grant list from a file, once per run: dispatch writes it beside the deny list and the builder inherits its
// path. A named file that cannot be read stops the plugin rather than letting every refusal claim no grant covers it.
export function readGrants(file) {
  if (!file) return null;
  return readFileSync(file, "utf8").split("\n").map((line) => line.trim()).filter(Boolean);
}

// The suggestion alone, for a caller that refuses for a reason of its own and prints it after its own text: the
// grant that would have allowed the command, and what to do when the spelling is denied anyway (a deny rule wins
// over every grant) or no grant shares its first word. `bin/ws-run` prints it for a command matching no grant.
export function grantSuggestion(command, grants) {
  if (grants === null) {
    return "no grant list is set, so no grant can be suggested; say in open_questions what the task needs";
  }
  const grant = closestGrant(command, grants);
  if (grant === null) {
    return "no grant covers this; say in open_questions what the task needs";
  }
  return `closest grant: Bash(${grant}); a denied spelling stays refused, so rewrite the command in that shape or say in open_questions that no shape fits`;
}

// What a model is told when the guard refuses its call: the command, then the suggestion for it.
export function refusalMessage(command, grants) {
  return `A deny rule prevents you from using this command with its quotes removed: ${command} (${grantSuggestion(command, grants)})`;
}

// `node scripts/grant-suggest.js <grants-file> <command> [args...]` prints the suggestion for a caller written in
// another language, such as `bin/ws-run`.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [file, ...words] = process.argv.slice(2);
  if (!file || words.length === 0) {
    console.error("usage: grant-suggest.js <grants-file> <command> [args...]");
    process.exit(2);
  }
  console.log(grantSuggestion(words.join(" "), readGrants(file)));
}
