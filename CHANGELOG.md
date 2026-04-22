# Changelog

All notable changes to ShareShip are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-22 — Dock duplicate-prompt fix

### Fixed
- **Duplicate Q prompt when a ship is docked.** In v1.0 the helm showed two "Ship Management" options simultaneously for any player standing at a docked ship's wheel — the mod's always-on variant plus the vanilla dock-specific variant. Both bound to Q, confusing the UI. v1.1 eliminates the duplicate at the helm level: the helm now only ever advertises one Management option, regardless of dock state or ownership. All four cases (owner / non-owner × docked / not-docked) now resolve to exactly one Q prompt.

### Changed
- **Mechanism moved from DataAsset requirement swap to helm `Options` TArray null-patch.** v1.0 left both interaction options (`ShipManagement` and `ShipDockManagement`) registered on the helm and used a requirement-level swap on `ShipManagement` to bypass the owner check — which also removed the embedded dock-mutex, surfacing the duplicate prompt. v1.1 keeps the v1.0 requirement swap intact (so non-owners can still open the Management UI) and additionally overrides the helm target DataAsset `DA_InteractionTarget_ShipSteeringWheel`: a 4-byte edit to its `.uexp` at offset `0x14-0x17` rewrites the third `FPackageIndex` in the helm's `Options` TArray — the one pointing at `DA_InteractionOption_ShipDockManagement` — to a null index. The engine iterates the TArray, the null entry resolves to nullptr, the UI skips it, and the dock-specific Management option simply never appears at the helm. Same surgical byte-patch pattern as v1.0.
- **Pak triple sizes** grow from 347 + 1643 + 501 bytes (v1.0, ~2.5 KB) to 347 + 2434 + 673 bytes (v1.1, ~3.4 KB) because the override now carries two cooked DataAssets instead of one.
- **`mod.json`** version bumped from `0.0.1` to `1.1.0`.

### Cosmetic note
- When docked, the Q prompt label reverts to "Ship Management" instead of "Ship Management (docked)". Cosmetic only — the management UI itself is identical in both variants (same cargo hold, slot upgrades, etc.). No functional feature is lost.

### Tested
- Listen-server smoke test on Windows client (2026-04-22). All four test-matrix cases (owner / non-owner × docked / not-docked) resolve to one Q "Management" prompt. v1.0's duplicate-Q in dock is gone.
- `retoc to-zen --version UE5_6` Legacy→Zen container validator round-trips cleanly; `retoc verify` reports the triple as valid.

### Abandoned path (kept for transparency)
- An earlier v1.1-experimental build (`patched-v3/` in the toolkit repo) tried to fix the duplicate by additionally redirecting `R5Requirement_CanOpenShipDockManagement` to an always-true requirement. That made the DockManagement option visible to everyone, which did not reduce the prompt count for owners — the duplicate bug was untouched. v1.1 (Path E, helm-level cut) supersedes and drops that attempt.

### Pending
- Dedicated-server cross-host smoke test with a remote client (files deployed to the dedicated server, needs server restart + friend's client also installing the v1.1 triple).
- Nexus Mods upload of the v1.1.0 file (Nexus supports automated updates via its Upload API for existing mod pages; mod page is already live at https://www.nexusmods.com/windrose/mods/147).

## [0.1.0] - 2026-04-22 — Initial release

### Added
- IoStore triple (`ShareShip_P.pak` + `.ucas` + `.utoc`, ~2.5 KB total) that overrides the cooked DataAsset `/Game/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement`.
- Patched source `.uasset` + `.uexp` in `build/sources/` with a byte-level diff spec in `BUILD-NOTES.md`.
- `build/README.md` reproducing the extract → patch → repack pipeline from retail Windrose assets using `retoc` and the toolkit's Go-based `patch_uasset_redirect.exe`.

### Changed
- The `FObjectImport` entry for `R5Requirement_CanOpenShipManagement` (the owner-only check on the ship-management interaction) is redirected to `R5IsTargetAliveRequirement`, which is already imported by the same DataAsset and evaluates true for any live helm. Exactly 2 bytes differ from the retail `.uasset`.

### Tested
- Listen-server on Windows client: mod mounts (`LogPakFile: Mounting pak file ... ShareShip_P.pak` in `R5\Saved\Logs\R5.log`), non-owner Q prompt appears on another player's helm, and the management UI opens.
- `retoc to-zen --version UE5_6` Legacy→Zen structural validator round-trips cleanly.

### Known issues
- **In-dock duplicate prompt.** When the targeted ship is in a dock, the helm shows two Q options ("Ship Management" from this mod and "Ship Management (docked)" from vanilla). Root cause: vanilla `CanOpenShipManagement` contained both the owner check AND a dock-mutex embedded as C++ lambdas; replacing it with a trivially-true requirement dropped both. A fix requires wrapping `CanOpenShipDockManagement` with a `CommonComposition.CheckType = Not` gate via a `.uexp` byte-level edit, tracked for v0.2. Out-of-dock behaviour is unaffected.

### Pending
- Dedicated-server validation (cross-host smoke test).
- Nexus Mods release packaging.
- v0.2: composition-NOT wrap to suppress the mod's prompt when the ship is docked.

### Notes
- No Lua, no UE4SS, no runtime injection. Pure cooked-asset override. Coexists with Windrose's anti-cheat because the AC does not scan cooked pak contents.
- No save-schema changes, no replicated properties added, no sidecar state files. Uninstalling is a clean folder delete.
