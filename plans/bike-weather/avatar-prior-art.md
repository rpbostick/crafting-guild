# Bike Weather: avatar prior art (CozyBuilder and CharacterStudio)

**In flight right now**

**PLANNED (2026-10-09, Patrick asked for it):** not dispatched. Two research spikes, then a decision talk. Waits for the budget reset on 2026-10-12 (about $16 for both spikes plus about $3 for the reviews). Queue: `avatar-prior-art.queue`.

## Why

The core loop shows the suggested outfit on the user's avatar, with clothing layered like real clothing: underwear to coat, several garments at once with the lower layers visible, added and removed in order, and a get-dressed animation later (decisions 2026-09-28). Today the avatar waits on figurewright's body, which is paused. Two projects do parts of this already, and the build should learn from them before it starts:

| | CozyBuilder | CharacterStudio |
|---|---|---|
| Repository | github.com/SadLittleKing/CozyBuilder | github.com/M3-org/CharacterStudio |
| What | A cozy village game (.NET 10, MonoGame). Its **CharacterEditor** assembles a modular villager and dog from named meshes in one Blender source: hair, outfit, hand equipment, backpack, and gear slots for head, body, gloves and feet. Every item has its own glTF model. | A web avatar creator for glTF/VRM (three.js, `@pixiv/three-vrm`, React optional; logic in a `CharacterManager` class): traits by slot, a colour picker, culling of faces hidden under other layers, merging meshes and atlasing textures down to one draw call, batch export against metadata schemas. |
| Licence | **None**: all rights reserved. We may read it and learn ideas; we may not copy its code or assets. | **MIT** for the code. Its asset packs (`loot-assets`, `character-assets`) are separate repositories with their own licences, to check. |
| Size, activity | 0 stars; pushed 2026-10-04; mostly assets and screenshots | 354 stars; pushed 2026-08-11; about 470 MB |
| To note | Needs a desktop OpenGL session to run; read, don't run. | The repository commits `cert.pem` and `key.pem` and depends on web3 packages: read before any install, and never run its install scripts. |

## Questions both spikes answer

1. **Slots and layers.** How an outfit is assembled: which slots exist, how the layer order is decided, how a garment hides what is under it (CharacterStudio's face culling, CozyBuilder's named meshes), and how adding or removing a layer works. Set against our layering rules (lower layers visible, add and remove in order).
2. **Bodies.** How garments fit different body shapes (blend shapes, bones, separate meshes per build), and what that would mean for "every garment fits every shape".
3. **Asset pipeline.** How garments are made: Blender sources, generators, validation scripts, naming conventions, export. What it would cost us per garment, against our parametric garments generated in code.
4. **Customisation interface.** How the user picks and cycles items, colours them, and sees the result.
5. **Rendering on our stack.** Whether this approach runs in Expo on web, iOS and Android: three.js and `three-vrm` through `expo-gl` or react-three-fiber, bundle size, frame rate, and what 2D (figurewright's SVG body) keeps or loses against 3D.
6. **What we may reuse.** Per item: code, assets or only the idea, with its licence.

## Steps

1. **`bw-avatar-cozybuilder`**: research spike on CozyBuilder (`task-bw-avatar-cozybuilder.md`). Reading only. Output: `docs/research/avatar-cozybuilder.md`.
2. **`bw-avatar-characterstudio`**: research spike on CharacterStudio (`task-bw-avatar-characterstudio.md`). Reading first; an optional local build with install scripts off. Output: `docs/research/avatar-characterstudio.md`.

   Steps 1 and 2 are independent and can run in parallel.
3. **Decision talk with Patrick** (orchestrator, no builder): from both reports, a short comparison and the questions to decide. These include 2D or 3D for the avatar, which slot and layer model to adopt, whether figurewright's body work continues as is, and whether to ask CozyBuilder's author for a licence. Recorded in `product.md` under Decisions.
4. Then, depending on the decisions: a build plan for the avatar on the Today screen, with this research as its `## Prior art`.

## Done when

- [ ] Both reports are merged in `docs/research/`, answering questions 1 to 6 with file and line references.
- [ ] Neither report copies code or assets from CozyBuilder.
- [ ] Patrick has decided 2D or 3D, the slot and layer model, and what happens to the figurewright body work, and the decisions are in `product.md`.
