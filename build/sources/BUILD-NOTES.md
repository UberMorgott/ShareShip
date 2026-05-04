# Patched source assets — spec

Authoritative description of both patches applied to retail cooked DataAssets. These files are the input to the legacy V8B pak repack (see [`../README.md`](../README.md)).

---

## Patch 1: `DA_InteractionOption_ShipManagement` (v1.0 → v1.3)

The core patch that gates opening the ship-management UI (Q on the helm).

## Summary

- **Source asset:** `/Game/Gameplay/Interaction/Options/DA_InteractionOption_ShipManagement` (cooked `.uasset` + `.uexp`, extracted from retail Windrose IoStore paks).
- **Change:** redirect ALL six references to `R5Requirement_CanOpenShipManagement` to `R5IsTargetAliveRequirement` — across the `FObjectImport` table, `FObjectExport` table, and preload dependencies.
- **Diff size:** exactly 7 bytes in the `.uasset`. The `.uexp` is verbatim.
- **Why the complete redirect?** The 2026-04-30 engine update tightened `AsyncLoading2`'s export validation: it now checks `TemplateObject->IsA(LoadClass)`, meaning the class import (Import[3]), the CDO import (Import[16]), and the export's `ClassIndex`/`TemplateIndex` must all agree. The original v1.0 2-byte patch only redirected Import[16] (the CDO), leaving Import[3] (the class) and Export[2] referencing the old class. The engine detected the mismatch and skipped the export entirely.
- **Why `R5IsTargetAliveRequirement`?** It's already imported by this same DataAsset (it's the `IsTargetAliveRequirement` slot of the interaction's `PrimaryRequirement` composition), so the engine has nothing new to resolve at load time.

## Byte-level diff (v1.3, complete patch)

| Offset (hex) | 1-based decimal | Field                                        | Before (octal) | After (octal) |
|-------------:|----------------:|----------------------------------------------|----------------:|--------------:|
| `0x652`      | 1619            | `FObjectImport[3].ObjectName.FName.index`    | 5               | 4             |
| `0x7E6`      | 2023            | `FObjectImport[16].ClassName.FName.index`    | 5               | 4             |
| `0x7F2`      | 2035            | `FObjectImport[16].ObjectName.FName.index`   | 35 (=29)        | 34 (=28)      |
| `0x91E`      | 2335            | `FObjectExport[2].ClassIndex`                | 374             | 375           |
| `0x926`      | 2343            | `FObjectExport[2].TemplateIndex`             | 357             | 360           |
| `0xA7A`      | 2683            | `PreloadDependencies` entry (ClassIndex ref) | 374             | 375           |
| `0xA7E`      | 2687            | `PreloadDependencies` entry (TemplateIndex ref)| 357           | 360           |

Name-table resolution (indices into the `.uasset`'s FName table):

- name[4]  = `R5IsTargetAliveRequirement`
- name[5]  = `R5Requirement_CanOpenShipManagement`
- name[28] = `Default__R5IsTargetAliveRequirement`
- name[29] = `Default__R5Requirement_CanOpenShipManagement`

### What each byte does

1. **Import[3]** (offset `0x652`): the CLASS import — the engine resolves this to the UClass object. Changed from `R5Requirement_CanOpenShipManagement` to `R5IsTargetAliveRequirement`.
2. **Import[16]** (offsets `0x7E6`, `0x7F2`): the CDO import — ClassName + ObjectName. This was the original v1.0 2-byte patch. Changed from `R5Requirement_CanOpenShipManagement` / `Default__R5Requirement_CanOpenShipManagement` to `R5IsTargetAliveRequirement` / `Default__R5IsTargetAliveRequirement`.
3. **Export[2]** (offsets `0x91E`, `0x926`): `ClassIndex` and `TemplateIndex` on the export record. These point at the import entries and must reference the same class as the imports for `IsA()` validation to pass.
4. **PreloadDependencies** (offsets `0xA7A`, `0xA7E`): preload dependency entries that mirror the export's class/template references.

## `FObjectImport[16]` record layout

File offset `0x7DE`, record stride **32 bytes** (this cooked format omits the optional `PackageName` / `bImportOptional` fields):

| Field | Offset into record | Value (before → after) |
|-------|-------------------:|------------------------|
| `ClassPackage` FName  | +0  | `(15, 0)` = `/Script/R5` (unchanged) |
| `ClassName`    FName  | +8  | `(5, 0)` → `(4, 0)` |
| `OuterIndex`          | +16 | `-12` = `imports[11]` = `/Script/R5` (unchanged) |
| `ObjectName`   FName  | +20 | `(29, 0)` → `(28, 0)` |
| trailing u32          | +28 | `0` (unchanged) |

The `Imports` array has 20 entries total, spanning `[ImportOffset=0x5DE, ExportOffset=0x85E)` — exactly 640 bytes, confirming the 32-byte stride.

## What is NOT modified

- **Names table** — byte-identical to source.
- **Summary header offsets** — `TotalHeaderSize`, `ExportOffset`, `ImportOffset`, `DependsOffset`, `AssetRegistryDataOffset`, etc.
- **DependsMap**, **AssetRegistryData**.
- **`.uexp`** — copied verbatim (142 bytes).

Output `.uasset` size: 2736 bytes, same as source.

## Runtime effect on the interaction's `PrimaryRequirement` composition

Before the patch, four requirements gated the management UI:

1. `R5IsTargetAliveRequirement`
2. `R5Requirement_CanOpenShipManagement`   *(the owner check)*
3. `R5Requirement_CommonComposition`
4. `R5Requirement_CommonTagBased` (`Boarding.Loser`, `Boarding.SteeringProhibited`)

After the patch:

1. `R5IsTargetAliveRequirement`
2. `R5IsTargetAliveRequirement`   *(duplicate — formerly the owner check)*
3. `R5Requirement_CommonComposition`
4. `R5Requirement_CommonTagBased`

The duplicate `IsTargetAlive` check is redundant but harmless: it returns true whenever the targeted actor (the helm) is alive, which is always the case when the interaction prompt is eligible to fire. The owner gate is bypassed while the dead-target / boarding-state gates are preserved.

## Verifying the patch

### Byte diff

```bash
cmp -l <retail>/DA_InteractionOption_ShipManagement.uasset \
       DA_InteractionOption_ShipManagement.uasset
# Expected (1-based decimal offsets, values in octal):
#   1619   5   4    (0x652: Import[3] ObjectName)
#   2023   5   4    (0x7E6: Import[16] ClassName)
#   2035  35  34    (0x7F2: Import[16] ObjectName)
#   2335 374 375    (0x91E: Export[2] ClassIndex)
#   2343 357 360    (0x926: Export[2] TemplateIndex)
#   2683 374 375    (0xA7A: PreloadDep ClassIndex ref)
#   2687 357 360    (0xA7E: PreloadDep TemplateIndex ref)
```

### `retoc` round-trip (structural validator)

```bash
mkdir -p /tmp/validate/R5/Content/Gameplay/Interaction/Options
cp DA_InteractionOption_ShipManagement.{uasset,uexp} \
   /tmp/validate/R5/Content/Gameplay/Interaction/Options/
retoc.exe to-zen --version UE5_6 /tmp/validate /tmp/validate_out.utoc
# Expected: silent success, producing .utoc + .ucas + .pak.
```

## `.uexp` risk analysis

The `.uexp` blob references objects through `FPackageIndex` (unchanged by this patch) and *potentially* through `(FName.idx, FName.number)` pairs. A scan (`uexp_scan.go` in the toolkit) found a single speculative `idx=5, num=2` hit at `.uexp` offset `0x68`; at `num=2` it cannot be a real FName reference to `R5Requirement_CanOpenShipManagement`, which only ever appears with `num=0`. `retoc to-zen` round-trips the patched pair cleanly, confirming the `.uexp` still parses against the mutated import table.

---

## Patch 2: `DA_InteractionTarget_ShipSteeringWheel` (v1.1+)

A 4-byte edit to the helm target's `.uexp` that removes the dock-specific Management option from the helm's `Options` TArray.

### Summary

- **Source asset:** `/Game/Gameplay/Interaction/Params/Ship/DA_InteractionTarget_ShipSteeringWheel` (cooked `.uasset` + `.uexp`, extracted from retail Windrose IoStore paks).
- **Change:** null-patch the third `FPackageIndex` entry in the helm's `Options` TArray.
- **Diff size:** 4 bytes in the `.uexp` at offset `0x14-0x17`. The `.uasset` is byte-identical to retail.
- **Why:** In v1.0, when a ship was docked the helm showed two Q prompts — the mod's always-on "Ship Management" plus vanilla's dock-specific "Ship Management (docked)". This patch removes the dock option at source.

### Byte-level diff

The helm's 28-byte `.uexp` stores the `Options` TArray as three consecutive `FPackageIndex` int32s at offsets `0x0c-0x17`:

| Offset (hex) | Field                        | Before (hex)   | After (hex)    |
|-------------:|------------------------------|---------------:|---------------:|
| `0x0c-0x0f`  | Options[0]: ShipSteering     | `f8 ff ff ff`  | `f8 ff ff ff`  |
| `0x10-0x13`  | Options[1]: ShipManagement   | `f9 ff ff ff`  | `f9 ff ff ff`  |
| `0x14-0x17`  | Options[2]: ShipDockMgmt     | `fa ff ff ff`  | `00 00 00 00`  |

The null `FPackageIndex` (`0x00000000`) resolves to nullptr at runtime. The engine iterates the TArray, skips the null entry, and the helm only advertises two options (Steering on E, Management on Q). The dock-specific Management option never appears.

### Tool

Produced by `helm_options_null.go` / `patch_helm_options_null.exe` from the [Windrose-Modding-Toolkit](https://github.com/uberMorgott/Windrose-Modding-Toolkit).

---

## Files in this folder

| File | Size | Notes |
|------|-----:|-------|
| `DA_InteractionOption_ShipManagement.uasset`         | 2736 B | 7 bytes differ from retail (offsets `0x652`, `0x7E6`, `0x7F2`, `0x91E`, `0x926`, `0xA7A`, `0xA7E`). Patch 1. |
| `DA_InteractionOption_ShipManagement.uexp`           |  142 B | Verbatim copy of retail. |
| `DA_InteractionTarget_ShipSteeringWheel.uasset`      |  —     | Byte-identical to retail. |
| `DA_InteractionTarget_ShipSteeringWheel.uexp`        |   28 B | 4 bytes differ from retail (offset `0x14-0x17`). Patch 2. |

## Known limits

- The ShipManagement patcher tool looks up the four target name strings by content. It refuses to patch any `.uasset` that doesn't contain all four.
- `FObjectImport` stride is assumed to be 32 bytes. If a future target asset uses the cooked layout with `PackageName` / `bImportOptional` fields (stride ≠ 32), the tool aborts with an explicit mismatch error.
