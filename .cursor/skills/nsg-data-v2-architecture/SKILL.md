---
name: nsg-data-v2-architecture
description: Implements and reviews features in nsg_data v2 architecture (abstract/data/view, store snapshots, data sources, riverpod/bloc adapters). Use when tasks mention nsg_data/lib/v2, V2 controllers, DataController/ViewController split, snapshot/store flow, or migration from legacy NsgBaseController API.
---

# NSG Data V2 Architecture

## Scope

Use this skill for work inside `nsg_data/lib/v2` and for migration from legacy `lib/controllers/nsgBaseController.dart`.

Primary goals:
- keep strict boundaries between `abstract`, `data`, and `view` layers;
- keep one source of truth in controller `store` snapshots;
- implement framework adapters (`riverpod`, `bloc`) as thin wrappers without business logic duplication.

## Core Rules

1. **Contracts first**
   - Update `lib/v2/abstract/*` only when API changes are required.
   - Implementation must follow contracts, not bypass them.

2. **Data vs View responsibilities**
   - `DataController`: loading/saving/deleting data, request params, cache, data-source orchestration.
   - `ViewController`: selected/backup item lifecycle, page-local state and page behavior.
   - Do not move page-local behavior into data layer.

3. **Single source of truth**
   - Persistent state lives in `NsgControllerStore` snapshots.
   - Any controller change must end with `store.update(snapshot.copyWith(...))`.

4. **Adapters must stay thin**
   - `riverpod` and `bloc` only forward to controller API and mirror snapshot stream.
   - No duplicated save/delete/filter business rules in adapters.

## Layer-by-Layer Checklist

### 1) Abstract layer (`lib/v2/abstract`)
- Keep interfaces minimal and composable.
- Add methods only if needed by at least one concrete flow.
- Avoid framework-specific details in abstract contracts.

### 2) Data layer (`lib/v2/controller/data`, `lib/v2/data_source`)
- Query behavior:
  - `load(...)` fetches from `DataSource`.
  - `refresh(...)` updates status (`loading/success/error`) and writes items to snapshot.
  - Protect against stale requests (`requestId` pattern) where relevant.
- Command behavior:
  - `create()` creates item (server/local aware).
  - `save(...)` validates and persists filtered items.
  - `delete(...)` removes items from source and from in-memory snapshot.
- DataSource behavior:
  - remote/local storage differences stay in `data_source/*`.
  - controller code must not branch on transport details unless unavoidable.

### 3) View layer (`lib/v2/controller/view`)
- Keep selected-item lifecycle here:
  - `selectedItem`, `backupItem`, `isModified`,
  - `select`, `saveBackup`, `restoreFromBackup`,
  - `createAndSelect`, `saveSelected`, `deleteSelected`.
- Delegate persistence/query operations to `dataController`.

### 4) Adapters (`lib/v2/riverpod`, `lib/v2/bloc`)
- Subscribe to `itemsUpdates` stream and mirror snapshot state.
- Expose convenience methods by delegating to `NsgViewControllerV2`.
- Lifecycle:
  - cancel subscriptions on dispose/close,
  - optional controller dispose with explicit flag,
  - allowed to use `unawaited(...)` only for intentional fire-and-forget calls.

## Migration Guide: Legacy `NsgBaseController` -> V2

When porting legacy behavior:

1. Map each method to target layer first:
   - data request/save/delete -> `DataController`;
   - selected/backup/page flow -> `ViewController`;
   - framework glue -> `riverpod`/`bloc`.

2. Preserve behavior parity for:
   - status transitions,
   - validation flow before save,
   - stale response handling,
   - selected item synchronization after save/delete.

3. Prefer incremental migration:
   - add API in v2 controller/mixin;
   - adapt riverpod/bloc facade;
   - verify lints and compile usage;
   - only then remove old flow usage.

## Implementation Workflow

Use this sequence for any v2 change:

1. Read impacted contracts in `lib/v2/abstract`.
2. Update core controller logic (`data` or `view`).
3. Update adapters (`riverpod`/`bloc`) if public behavior changed.
4. Run lints on changed files.
5. Validate no responsibility leaks across layers.

## Done Criteria

A change is complete when:
- contracts and implementation are aligned;
- snapshot is updated consistently for success/error paths;
- adapters compile and remain thin;
- linter diagnostics for changed files are clean;
- behavior parity for migrated legacy method is preserved.
