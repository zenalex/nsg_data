# NSG Data V2 Architecture

## Scope

Use this skill for work inside `nsg_data/lib/v2` and for migration from legacy `lib/controllers/nsgBaseController.dart`.

Primary goals:
- keep strict boundaries between `abstract`, `data`, and `view` layers;
- keep one source of truth in controller `store` snapshots;
- implement framework adapters (`riverpod`, `bloc`) as thin wrappers without business logic duplication.

Full reference: [ARCHITECTURE_MODEL.md](../../../lib/v2/ARCHITECTURE_MODEL.md) and [README.md](../../../lib/v2/README.md).

## Core Rules

1. **Contracts first**
   - Update `lib/v2/abstract/*` only when API changes are required.
   - Implementation must follow contracts, not bypass them.

2. **Data vs View responsibilities**
   - `DataController`: loading/saving/deleting data, request params, cache, data-source orchestration.
   - `ViewController`: selected/backup item lifecycle, page-local state and page behavior.
   - Do not move page-local behavior into data layer.

3. **Single source of truth**
   - Persistent list state lives in `NsgControllerStore` snapshots inside `NsgDataControllerV2`.
   - Any controller change to list state must end with `store.update(snapshot.copyWith(...))`.
   - `selectedStore` and `backupStore` inside `ViewController` are **separate `NsgControllerStore` instances by design** — they own page-scoped selection state and are not part of the main data snapshot. This is intentional, not a violation of the single-source-of-truth rule.
   - `selectedItems` are **not automatically reconciled** with `snapshot.items` after `refresh()` — see Known Gaps.

4. **Adapters must stay thin**
   - `riverpod` and `bloc` only forward to controller API and mirror the **main list** snapshot stream (`controller.itemsUpdates`).
   - **Adapters do not mirror `selectedStore` or `backupStore`.** For selection state in UI use `controller.selectedItemsUpdates`, `controller.backupItemsUpdates`, or `ViewController.observeStatus(...)`.
   - No duplicated save/delete/filter business rules in adapters.
   - **Adapters do not emit metrica events** — tracking stays in controllers (`NsgMetricaMixin`) or app code.

5. **Metrica (`lib/v2/metrica`)**
   - Contracts in `abstract/metrica.dart`: `MetricaEvent`, `MetricaSink`, `Metrica` (all `Lifecycle` where applicable).
   - `NsgMetrica` is composite: synchronous `track()`, async fan-out per sink; sink errors must not reach controllers.
   - Controllers accept optional `Metrica? metrica`; `null` = silent no-op.
   - Auto hooks on `DataController`: `init`, `dispose`, successful `refresh`/`save`/`delete`, `onRetry`, errors in catch blocks.
   - Auto hooks on `ViewController`: `init`, `dispose`, `select`, `createAndSelect`; data ops delegate to `dataController` hooks.
   - Manual events: `trackEvent(event)` or `metrica.track(...)` — use built-in types from `nsg_metrica_events.dart` or subclass `MetricaEvent` in the app.
   - App backends implement `MetricaSink` (Firebase, HTTP, etc.); register via `di.bind<NsgMetrica>(NsgMetrica(sinks: [...]))`.
   - Do not add framework-specific analytics to `abstract/` beyond existing contracts.

## Layer-by-Layer Checklist

### 1) Abstract layer (`lib/v2/abstract`)
- Keep interfaces minimal and composable.
- Add methods only if needed by at least one concrete flow.
- Avoid framework-specific details in abstract contracts.
- Note: `DataItem` currently imports Flutter's `@immutable` — avoid adding further Flutter/framework dependencies to `abstract/`.

### 2) Data layer (`lib/v2/controller/data`, `lib/v2/data_source`)
- Query behavior:
  - `load(...)` fetches from `DataSource`.
  - `refresh(...)` updates status (`loading/success/error`) and writes items to snapshot.
  - **Stale-request guard**: `load()` generates a `Guid` request ID before the async call and checks it after. If a newer call has replaced the ID, it throws `NsgV2ExceptionDataObsolete`, which `refresh()` silently ignores. Always preserve this pattern when adding new query paths.
- Command behavior:
  - `create()` creates item (server/local aware via `prototype.createOnServer`).
  - `save(...)` validates all items first; on failure sets `status: error` with `validateResults`.
  - `delete(...)` removes items from source and from in-memory snapshot.
- DataSource behavior:
  - remote/local storage differences stay in `data_source/*`.
  - `NsgCachedRequestParams` normalizes `NsgDataRequestParams` to a stable cache key. When changing how request params are cached, verify consistency between `fetchItems` and `selectCount` — they currently use different normalization paths.
  - controller code must not branch on transport details unless unavoidable.

### 3) View layer (`lib/v2/controller/view`)
- Keep selected-item lifecycle here:
  - `selectedItem`, `backupItem`, `isModified`,
  - `select`, `saveBackup`, `restoreFromBackup`,
  - `createAndSelect`, `saveSelected`, `deleteSelected`.
- Delegate persistence/query operations to `dataController`.
- `observeStatus({listenables, builder})` returns a `StreamBuilder` that by default merges `itemsUpdates`, `selectedItemsUpdates`, and `backupItemsUpdates`. Use it as the standard reactive rebuild point in pages.
- **`NsgViewCommandControllerV2.delete` override is fire-and-forget** — it calls `dataController.delete(items: items)` without `await`. The public `deleteSelected()` does await. When calling `delete(...)` directly, be aware errors are not surfaced to the caller.

### 4) Metrica (`lib/v2/metrica`, `lib/v2/controller/nsg_metrica_mixin.dart`)
- Keep `abstract/metrica.dart` minimal; extend event types in `nsg_metrica_events.dart` or in the app via `MetricaEvent` subclasses.
- When adding new auto-tracked controller operations, add a typed event + `trackMetrica*` helper on `NsgMetricaMixin`, then call from the appropriate mixin (`DataController` or `ViewController`).
- Preserve once-per-lifecycle tracking for `init`/`dispose` (`_metricaInitTracked` / `_metricaDisposeTracked`).
- `metricaControllerKey` defaults to `runtimeType.toString()` — override in app controllers for stable analytics keys.

### 5) Adapters (`lib/v2/riverpod`, `lib/v2/bloc`)
- Subscribe to `controller.itemsUpdates` stream and mirror main list snapshot state.
- Expose convenience methods by delegating to `NsgViewControllerV2`.

**BLoC event → controller method mapping:**

| Event | Controller call |
|---|---|
| `NsgDataRefreshEvent` | `replaceRequestParams` (optional) + `controller.refresh()` |
| `NsgDataSelectEvent` | `controller.select(item)` |
| `NsgDataCreateEvent` | `controller.createAndSelect()` or `controller.create()` |
| `NsgDataSaveSelectedEvent` | `controller.saveSelected()` |
| `NsgDataDeleteSelectedEvent` | `controller.deleteSelected()` |

- Lifecycle:
  - cancel subscriptions on dispose/close,
  - optional controller dispose with explicit `disposeControllerOnClose` / `disposeControllerOnDispose` flag,
  - `NsgDataStateNotifier.dispose` uses `unawaited(Future.sync(() => controller.dispose()))` for the async controller dispose — this is intentional fire-and-forget.
- **Riverpod API level:** `NsgDataStateNotifier` uses `StateNotifier` and `nsgDataProvider` uses `StateNotifierProvider.autoDispose` (Riverpod 1.x). Do not migrate to Riverpod 2.x `Notifier` without a coordinated update.

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
3. If changing request params or cache behavior, verify `NsgCachedRequestParams` key consistency between `fetchItems` and `selectCount` in `NsgRemoteDataSource` / `NsgLocalDataSource`.
4. Update metrica events/mixin if controller lifecycle or command behavior changed.
5. Update adapters (`riverpod`/`bloc`) if public behavior changed.
6. Run lints on changed files.
7. Validate no responsibility leaks across layers.

## Known Gaps

### 1. selectedItems not reconciled after refresh
`selectedItems` live in `selectedStore` and are not updated when `DataController.refresh()` brings new data. After a refresh the selected item may be a stale instance. Planned fix: id-based reconcile in `ViewController` with a configurable missing-item policy (`keepStale` / `dropMissing` / `reloadMissing`). Until this is implemented, callers must manually re-select after refresh if item freshness matters.

### 2. FilterStorage not implemented
There is no standard mechanism to persist filter state (`NsgDataRequestParams`) across page visits. Current workaround: pass saved params to `replaceRequestParams(...)` at page open from outside the controller. Planned fix: injectable `FilterStorage` interface with `load(controllerKey)` / `save(controllerKey, params)`.

## Done Criteria

A change is complete when:
- contracts and implementation are aligned;
- snapshot is updated consistently for success/error paths;
- adapters compile and remain thin;
- adapters mirror only the main list snapshot — no selection-state or metrica duplication inside adapter;
- linter diagnostics for changed files are clean;
- behavior parity for migrated legacy method is preserved.
