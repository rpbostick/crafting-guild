# reactbits-kit: plan

**In flight right now**

**MAINTENANCE (2026-10-09 20:02 MDT, Patrick keeps making demos with React Bits backgrounds):** the kit is the one source for customised backgrounds; new demos use `rbx`. A background is added only when a demo needs it. Step 3 (the site onto the kit, so the two don't drift) is one light task when there's room after Bike Weather. Licence: React Bits is MIT + Commons Clause, so it stays out of Bike Weather and anything sold unless the terms are checked first.

(2026-10-02): step 1 merged (rbk-foundation: our modules, 12 transforms for Waves/Aurora/Iridescence, rbx CLI, 81 tests). Step 2 merged (rbk-seven: all ten components, sheet and site profiles, React adapter, 114 tests). Next: step 3, move rpbostick.github.io onto rbx (after the figurewright inside-the-ball round merges, since it changes Waves), step 4 (chargen-toybox plug-in) running as `ppr-toybox-rbx`. Kit on GitHub private, tag v0.2.0.

## Requirements (Patrick, 2026-10-02)
- One tool to deploy all our React Bits customizations everywhere; its own repo; never package React Bits itself.
- Repo rpbostick/reactbits-kit, private until proven on the site and the character sheet.

## Steps
1. Foundation (above).
2. Transforms for the other seven components (Threads, Balatro, LiquidChrome, Galaxy, Plasma, SoftAurora, RippleGrid) from the chargen-toybox plug-in.
3. Move rpbostick.github.io (figurewright/skywright/colorwright) onto `rbx`; `rbx check` in its build.
4. Move pen-paper-rpg chargen-toybox's React Bits plug-in onto `rbx`.
5. GitHub private repo; later public after the release audit.
- 2026-10-02: kit 0.2.1 (compiled JS) on GitHub; chargen-toybox uses it (merged d7abce6). Figurewright shipped with ripple/swirl, sheet glide and ball spin 0.1 (site dc26805). Running: `rbk-site-sync` (site profile catches up with the live Waves, sphereSpin module). Then step 3: the site switches to rbx. Then the toybox library's backgrounds get momentum/ripple via the kit's modules.
- 2026-10-02: kit v0.3.0 PUBLIC at github.com/rpbostick/reactbits-kit (one audited commit; Patrick chose a new public repo). Private dev history renamed to rpbostick/reactbits-kit-dev (local origin). Later public releases: audit, then commit the new tree on top of the public branch (`public-release` locally, remote `public`) and tag. Site switching to the kit (`site-uses-kit`); chargen-toybox still pins the dev repo's v0.2.1 and must move to the public v0.3.0.
- 2026-10-02: steps 3 and 4 done. Site on the public kit (0b2ba24, deployed); chargen-toybox on the public kit v0.3.0 (pen-paper-rpg b6beefa). All three consumers (site, chargen-toybox, toybox library from 0.5.0) use github:rpbostick/reactbits-kit.
- 2026-10-03: 0.4.0 public (sheet profile ripple/sheet/spin for all ten; toyboxState adapter). chargen-toybox updating (`ppr-toybox-060`).
- 2026-10-03: future public releases: bump package.json, merge, then `ws --project reactbits-kit release` (ws 2.3.0).
