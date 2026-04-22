# Changelog

All notable changes to ShareShip are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
