# Bike Weather: fix the name check's summary and wording

Track: light

Research document only: edit `docs/research/naming.md` and the one README line that links it. Uses WebSearch and WebFetch where a finding asks for a check to be run. A review of the branch found the points below. Fix every one under "Must fix"; fix those under "Also" unless one is wrong, and say so in the result if it is.

The rule behind most of them: the summary table may claim only what the body shows, a risk rating needs a recorded check behind it, and `[read]` means the page itself was fetched and its content read.

## Must fix
- `docs/research/naming.md` line 17: The Summary row for Enjoy the Weather claims more than the body supports, in four places. (1) It lists `enjoytheweather.io` as the studio's; the body only says it is registered 2021-09-23 at Key-Systems (line 92) and never links it to the studio. (2) It says the studio has the `.com` "since 2008"; lines 45-46 say the 2008 creation predates the studio's 2016 founding and the domain may have changed hands. (3) It says "the `.com` is not obtainable"; lines 46-48 say only that no sale listing was seen on the page, and leave Afternic, Sedo and WHOIS history as hand checks. (4) The risk cell says "no registered mark found", yet lines 60-63 record live ENJOY registrations in classes 9 and 42 and ENJOY THE WORK in class 9. Fix: reword the row to what the body shows — drop or source the `.io` attribution, say the domain was created in 2008 with holder history unknown, say no sale listing was seen, and mention the ENJOY class 9/42 marks.

- `docs/research/naming.md` line 18: The Summary rates ETW "Low legal risk", but section 3 (lines 107-133) contains no trademark search for ETW at all: it covers other meanings, stores, the icon label, npm and GitHub. The only trademark fact touching ETW points the other way: ETW Consulting Services Inc. holds a live class 9 mark (line 60). The rating is a verification claim with no check behind it. Fix: either run and record the Trademarkia search for "ETW" as was done for the other names, or change the cell to say trademarks were not searched for ETW and drop the risk rating.

## Also
- `docs/research/naming.md` line 7: Rules 3 and 15: every `[read]` mark is a verification claim, but no fetched response is saved under `.ws-evidence/` and nothing ran through `ws-run`. The RDAP 404s, store searches and npm answers are time-sensitive and cannot be re-checked later from the links alone. Save the raw responses (at least the RDAP, iTunes and npm JSON) as evidence.
- `docs/research/naming.md` line 199: Line 10 says absence is always written as "no record found in <where>, searched <how>" and never means a name is free. Lines 188, 190, 198 and 199 then call `.app` domains "open" and say "Register the open domains", and lines 17 and 20-22 say "No app ... on either store". Use the document's own wording ("no RDAP record found"), or soften line 10's "always".
- `docs/research/naming.md` line 83: "Each server was first checked against a domain known to exist" names controls for `.app`, `.co` and `.org` only. The `.com` and `.io` servers are covered by their positive results, but the Verisign `.net` endpoint (line 91) has one lookup, a 404, and no named control. Name a `.net` control or narrow "each".
- `docs/research/naming.md` line 123: The npm reasoning rests on an "unused scope" returning 404, but the control scope is not named or linked, so the comparison cannot be repeated. The `/-/org/<name>/package` endpoint also shows an organisation, not necessarily a user-owned scope; say that `@enjoytheweather` could still be held by a user account.
- `docs/research/naming.md` line 192: "Togs and Brisk are blocked by live or pending marks in the classes that matter" is a legal conclusion in a document that opens with "not legal advice". Something like "carry the highest risk: live or pending marks in classes 9, 25 or 42" matches what was found.
- `docs/research/naming.md` line 152: "Its last push date is today's" and "are open today" (line 199) read wrong on any later day. Use the date (2026-10-06), as the rest of the document does.
- `docs/research/naming.md` line 198: "(cheap, reversible)": a domain registration is cheap but not normally refundable. "Cheap, and can be left to lapse" is accurate.
- `docs/research/naming.md` line 52: `[read]` is defined as "the page or API response itself was fetched and read", but it is also used for fetches that returned nothing (USPTO, EUIPO, TMview, WIPO at lines 52-68). A third mark such as `[not reachable]` would keep `[read]` meaning what line 7 says.
- `README.md` line 10: The link text "whether the names are free to use" promises what the document says it cannot give (naming.md:10-11: "It does not mean a name is free to use"). Something like "what a desk check found on the names" matches the document.
- A date after the day the document was written appears in it (2027-04-06): keep it only if it is a fact from a source (an expiry date, say) and name it as such.

## Commands
`git status`, `git diff`, `git add`, `git commit`, `ls`, `cat`, `grep`. One command per Bash call. No installs.

## Done when
Each point above is fixed in the document or answered in the result; the summary table and the body agree line by line; the result restates in three lines whether anything found stands in the way of "Enjoy the Weather", the three strongest app-name candidates, and what could not be checked from here. Safe to re-run.
