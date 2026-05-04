# Building ShareShip from source

This document describes how to reproduce `ShareShip_P.pak` from retail Windrose assets. The pre-built output lives in [`../ShareShip/`](../ShareShip/) and the patched intermediate sources are in [`sources/`](sources/). See [`sources/BUILD-NOTES.md`](sources/BUILD-NOTES.md) for the byte-level specification of both patches.

> **Note (v1.3.0):** v1.2.0 attempted to switch to legacy V8B `.pak` format to work around a `AsyncLoading2` validation error, but legacy paks cannot override IoStore-packaged vanilla assets in UE 5.6. v1.3.0 returns to IoStore format with a complete 7-byte patch that redirects ALL class references consistently, satisfying the validation.

## Prerequisites

| Tool | Why | Where to get it |
|------|-----|-----------------|
| `retoc.exe` | Extracts retail IoStore paks to legacy format for patching, and repacks patched files into IoStore triple. | [trumank/retoc](https://github.com/trumank/retoc) — download the Windows release. |
| Go 1.22+ | Builds the `.uasset` patch utilities. | [go.dev/dl](https://go.dev/dl/). |
| `patch_uasset_redirect.exe` | Swaps two FName indices inside the `FObjectImport` table (the core of the patch). | Clone [uberMorgott/Windrose-Modding-Toolkit](https://github.com/uberMorgott/Windrose-Modding-Toolkit), then `go build -C environment/tools/scripts/patch_uasset_fname -o ../patch_uasset_redirect.exe redirect.go`. |
| A Windrose install | Source of the retail `DA_InteractionOption_ShipManagement.uasset`. | Steam AppID `3041230`. |

## Build steps

### 1. Extract the retail DataAsset

`retoc.exe` can dump a single asset out of the IoStore paks by glob:

```powershell
retoc.exe to-legacy `
  --filter "DA_InteractionOption_ShipManagement" `
  --version UE5_6 `
  "<Windrose install>\R5\Content\Paks" `
  "<scratch>\extracted"
```

You should end up with:

```
<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uasset
<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uexp
```

The `.uasset` is 2736 bytes, the `.uexp` is 142 bytes.

### 2. Apply the FName redirect

```powershell
patch_uasset_redirect.exe `
  -in  "<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uasset" `
  -out "<scratch>\patched\DA_InteractionOption_ShipManagement.uasset" `
  -v
```

The tool locates all references to `R5Requirement_CanOpenShipManagement` — in both `FObjectImport` entries (class import and CDO import), the `FObjectExport` table (`ClassIndex` and `TemplateIndex`), and preload dependency entries — and rewrites them to point at `R5IsTargetAliveRequirement`. Exactly seven bytes change from the retail file. See [`sources/BUILD-NOTES.md`](sources/BUILD-NOTES.md) for the complete byte-level specification.

### 3. Copy the `.uexp` verbatim

The `.uexp` blob is not modified — copy it beside the patched `.uasset`:

```powershell
Copy-Item `
  "<scratch>\extracted\R5\Content\Gameplay\Interaction\Options\DA_InteractionOption_ShipManagement.uexp" `
  "<scratch>\patched\"
```

### 4. Stage into the UE content tree

`repak pack` preserves the directory layout under the input root, so the patched files must sit at the correct engine-relative path before packaging:

```powershell
mkdir "<scratch>\staging\R5\Content\Gameplay\Interaction\Options"
mkdir "<scratch>\staging\R5\Content\Gameplay\Interaction\Params\Ship"
Copy-Item "<scratch>\patched\DA_InteractionOption_ShipManagement.uasset" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Options\"
Copy-Item "<scratch>\patched\DA_InteractionOption_ShipManagement.uexp" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Options\"
Copy-Item "<scratch>\patched\DA_InteractionTarget_ShipSteeringWheel.uasset" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Params\Ship\"
Copy-Item "<scratch>\patched\DA_InteractionTarget_ShipSteeringWheel.uexp" `
  "<scratch>\staging\R5\Content\Gameplay\Interaction\Params\Ship\"
```

### 5. Pack the IoStore triple

```powershell
retoc.exe to-zen --version UE5_6 `
  "<scratch>\staging" `
  "<scratch>\out\ShareShip_P.utoc"
```

Output: three files — `ShareShip_P.utoc`, `ShareShip_P.ucas`, and `ShareShip_P.pak` (~3.4 KB total).

Drop all three into the [`ShareShip/`](../ShareShip/) folder (or directly into `<Windrose install>\R5\Content\Paks\~mods\ShareShip\`) to use the freshly-built mod.

> **Why IoStore and not legacy V8B?** Windrose ships its vanilla assets in IoStore (Zen) containers. In UE 5.6, IoStore assets take priority over legacy V8B paks, so a legacy pak override is silently ignored. The mod must be packaged as an IoStore triple to actually override the vanilla asset.

## Verification

**Byte diff against retail.** The patch must change exactly seven bytes:

```bash
cmp -l <retail-uasset> <patched-uasset>
# Expected (1-based decimal offsets, values in octal):
#   1619   5   4    (offset 0x652: Import[3] ObjectName FName index 5 -> 4)
#   2023   5   4    (offset 0x7E6: Import[16] ClassName FName index 5 -> 4)
#   2035  35  34    (offset 0x7F2: Import[16] ObjectName FName index 29 -> 28)
#   2335 374 375    (offset 0x91E: Export[2] ClassIndex)
#   2343 357 360    (offset 0x926: Export[2] TemplateIndex)
#   2683 374 375    (offset 0xA7A: PreloadDependency)
#   2687 357 360    (offset 0xA7E: PreloadDependency)
```

**Runtime mount check.** On game start, `R5\Saved\Logs\R5.log` should contain:

```
LogPakFile: Mounting pak file ... ShareShip_P.pak
```

**Functional check.** Join a server with the mod loaded as a non-owner, walk up to another player's ship helm, and press the interaction key. The ship-management Q prompt should appear and the management UI should open.

## Rebuilding from the provided sources

If you just want to repack the included patched sources (skipping extraction + patch), start at step 4 using the files in [`sources/`](sources/) as input. Both patched DataAssets (`DA_InteractionOption_ShipManagement` and `DA_InteractionTarget_ShipSteeringWheel`) must be staged at their correct engine-relative paths.
