# figurewright easing spike: fix 1 (report wording)

Track: light

Your branch `agent/fw-easing` (reviewed at 313a833) has one blocking review finding. Fix only this, in `spike/easing/REPORT.md`; change nothing else.

- **REPORT.md:7**: the headline says the posed average body lands on easing's silhouette "within about a centimetre at the neck, feet and hands". That is false for the hands: in `renders/posed-vs-original.png` the near wrist sits about 25 units (~6 cm) outside easing's near hand and the far wrist about 30 units (~8 cm) outside, because the arms open 6° and 10° to clear the torso (as section 2 and question 1 already say). Limit the claim to the neck and feet, and say the hands sit out by the arm opening, with those figures.
- While in the file, line ~132: "within 14% of easing's angle" while the log's largest value is ×1.141; say "about 14%".

Do not commit `spike/easing/debug-hand.ts` (untracked; leave it).

## Commands
One command per Bash call. `git add spike/easing/REPORT.md`, `git commit`.

## Done when
One commit that changes only `spike/easing/REPORT.md`, with both statements corrected.
