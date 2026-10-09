# Bike Weather research: what CozyBuilder's character editor does (research only, no product code)

Track: light

Bike Weather will show the suggested outfit on the user's avatar, with clothing layered like real clothing: underwear to coat, several garments at once with the lower layers visible, added and removed in order (read `README.md` and `src/model/` here for our garments, regions and layers). CozyBuilder (github.com/SadLittleKing/CozyBuilder, .NET 10 and MonoGame) has a CharacterEditor that assembles a modular villager and dog from named meshes in one Blender source, with slots for hair, outfit, hand equipment, backpack, and head, body, glove and feet gear, and a glTF model per item.

**It has no licence.** Read it and describe what it does in your own words. Do not copy its code, assets, or text into this repository, and do not paste more than a line of its code into the report.

## Steps

1. Clone it, shallow, into `.ws-evidence/scratch/cozybuilder` (untracked): `git clone --depth 1 https://github.com/SadLittleKing/CozyBuilder .ws-evidence/scratch/cozybuilder`.
2. Read, don't build or run. Start with `README.md`, `agent.md`, `src/Game.Assets/` (the GLB loader and character assembly), `src/CharacterEditor/`, `assets/villager/` (its generators and validation), `character.json`, and the screenshots in the root.
3. Answer, with file and line references into the clone:
   1. **Slots and layers:** which slots exist and how a piece attaches (bones, named meshes, sockets); how the layer order is set; how a piece hides or replaces what is under it; how swapping works.
   2. **Bodies:** whether there is more than one body shape, and how gear would fit different builds.
   3. **Asset pipeline:** how the Blender source, the generators and the validation fit together; naming conventions; what adding one new garment takes, step by step.
   4. **Editor interface:** how a user picks, cycles and previews pieces, and how the choice is saved (`character.json`).
   5. **For Bike Weather:** what to adopt as an idea, what doesn't fit (our garments carry warmth, wind and water ratings and a body region), and what would be worth asking the author for if a licence were offered.

## Output

`docs/research/avatar-cozybuilder.md`: the five answers, short, with a small table of slots and how each attaches. Name the commit you read. State facts plainly; mark anything you could not establish from the code as unknown.

## Prior art

This is the prior-art step for the avatar build.

## Commands

`git clone --depth 1 https://github.com/SadLittleKing/CozyBuilder .ws-evidence/scratch/cozybuilder`, `ls`, `cat`, `grep`, `git -C .ws-evidence/scratch/cozybuilder log -1`, `git add`, `git commit`. One command per Bash call.

## Done when

- The report is committed at `docs/research/avatar-cozybuilder.md` and answers all five questions with file references.
- It names the commit read.
- It copies no code, assets or text from CozyBuilder.
