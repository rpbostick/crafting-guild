# Upstream findings (bike-weather)

Findings meant for other projects' maintainers. Each entry: observed / re-checked / inferred / posted. Post only re-checked findings that would change what the maintainers do, batched, with the draft shown to Patrick first.

## M3-org/CharacterStudio
- **observed 2026-10-20 at 293182b** (bw-avatar-cs-handson, report `docs/research/avatar-characterstudio-handson.md` §1): `VITE_` secrets inlined into the client bundle (S1); committed `key.pem` / `cert.pem` (S2); a manifest with `solanaPurchaseAssets` starts a wallet connection with no click (S3); server-built transactions signed unchecked (S4); the deploy job runs `npm install` with write permissions and a tag-pinned action (S5); 59 production audit findings (S6); wallet bugs (S11). Draft: `runs/bike-weather/evidence/bw-avatar-cs-handson/issue-draft.md` (copy kept beside this log as `upstream-characterstudio-draft.md`). Next: re-check against their latest commit before proposing a post.
