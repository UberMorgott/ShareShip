# Building ShareShip from source

This document describes how to reproduce `ShareShip_P.pak` from retail Windrose assets. The pre-built output lives in [`../ShareShip/`](../ShareShip/) and the patched intermediate sources are in [`sources/`](sources/). See [`sources/BUILD-NOTES.md`](sources/BUILD-NOTES.md) for the byte-level specification of both patches.

> **Note (v1.2.0):** The mod was previously packaged as an IoStore triple (`.pak` + `.ucas` + `.utoc`) using `retoc to-zen`. After the 2026-04-30 Windrose engine update tightened AsyncLoading2's export validation, the Zen format rejects the patched import redirect. v1.2.0 switches to a single legacy V8B `.pak` built with `repak pack`, which resolves the redirect cleanly via the legacy linker.

## Prerequisites

| Tool | Why | Where to get it |
|------|-----|-----------------|
| `repak.exe` | Packs loose `.uasset`/`.uexp` files into a legacy V8B `.pak`. | [trumank/repak](https://github.com/trumank/repak) — download the Windows release. |
| `retoc.exe` | Extracts retail IoStore paks to legacy format for patching. | [trumank/retoc](https://github.com/trumank/retoc) — download the Windows release. |
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

The tool locates the `FObjectImport` entry whose `ClassName` is `R5Requirement_CanOpenShipManagement` and rewrites two `FName.index` fields to point at `R5IsTargetAliveRequirement` / `Default__R5IsTargetAliveRequirement` instead. It refuses to patch any asset that doesn't contain all four target name strings. Exactly two bytes change: offsets `0x7E6` and `0x7F2`.

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

### 5. Pack the legacy V8B pak

```powershell
repak.exe pack --version V8B `
  "<scratch>\staging" `
  "<scratch>\out\ShareShip_P.pak"
```

Output: one file — `ShareShip_P.pak` (~5.3 KB).

Drop it into the [`ShareShip/`](../ShareShip/) folder (or directly into `<Windrose install>\R5\Content\Paks\~mods\ShareShip\`) to use the freshly-built mod.

> **Why not IoStore?** Prior to v1.2.0 the mod was packed as an IoStore triple using `retoc to-zen`. The 2026-04-30 Windrose engine update tightened `AsyncLoading2`'s export validation (`TemplateObject->IsA(LoadClass)`), which rejects the patched import redirect in Zen format. Legacy V8B paks use a different linker path that resolves the redirect cleanly.

## Verification

**Byte diff against retail.** The patch must change exactly two bytes:

```bash
cmp -l <retail-uasset> <patched-uasset>
# Expected:
#   2023   5   4    (offset 0x7E6: ClassName FName index  5 -> 4)
#   2035  35  34    (offset 0x7F2: ObjectName FName index 29 -> 28, octal)
```

**Runtime mount check.** On game start, `R5\Saved\Logs\R5.log` should contain:

```
LogPakFile: Mounting pak file ... ShareShip_P.pak
```

**Functional check.** Join a server with the mod loaded as a non-owner, walk up to another player's ship helm, and press the interaction key. The ship-management Q prompt should appear and the management UI should open.

## Rebuilding from the provided sources

If you just want to repack the included patched sources (skipping extraction + patch), start at step 4 using the files in [`sources/`](sources/) as input. Both patched DataAssets (`DA_InteractionOption_ShipManagement` and `DA_InteractionTarget_ShipSteeringWheel`) must be staged at their correct engine-relative paths.
