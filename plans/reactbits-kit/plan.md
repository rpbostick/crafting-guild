# reactbits-kit: plan

**In flight right now** (2026-10-02): step 1 merged (rbk-foundation: our modules, 12 transforms for Waves/Aurora/Iridescence, rbx CLI, 81 tests). Step 2 merged (rbk-seven: all ten components, sheet and site profiles, React adapter, 114 tests). Next: step 3, move rpbostick.github.io onto rbx (after the figurewright inside-the-ball round merges, since it changes Waves), then step 4 (chargen-toybox plug-in).

## Requirements (Patrick, 2026-10-02)
- One tool to deploy all our React Bits customizations everywhere; its own repo; never package React Bits itself.
- Repo rpbostick/reactbits-kit, private until proven on the site and the character sheet.

## Steps
1. Foundation (above).
2. Transforms for the other seven components (Threads, Balatro, LiquidChrome, Galaxy, Plasma, SoftAurora, RippleGrid) from the chargen-toybox plug-in.
3. Move rpbostick.github.io (figurewright/skywright/colorwright) onto `rbx`; `rbx check` in its build.
4. Move pen-paper-rpg chargen-toybox's React Bits plug-in onto `rbx`.
5. GitHub private repo; later public after the release audit.
