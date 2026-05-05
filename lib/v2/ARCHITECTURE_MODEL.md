# nsg_data v2 Architecture Model

## Diagram

```mermaid
flowchart LR
  A[abstract contracts<br/>Controller / Query / Command / Store / DataSource / Lifecycle]

  subgraph C[controllers]
    DC[NsgDataControllerV2<br/>+ query + command]
    VC[NsgViewControllerV2<br/>selection / backup / page state]
    ST[NsgControllerStore&lt;T&gt;<br/>snapshot stream]
  end

  subgraph DS[data_source]
    REM[NsgRemoteDataSource]
    LOC[NsgLocalDataSource]
  end

  subgraph AD[adapters]
    B[NsgDataBloc]
    R[NsgDataStateNotifier<br/>(Riverpod)]
  end

  A --> DC
  A --> VC
  A --> ST

  DC --> ST
  VC --> DC

  DC --> REM
  DC --> LOC

  B --> VC
  R --> VC
  ST --> B
  ST --> R
```

## Short Description

- **`abstract`** defines stable contracts: what a controller/data source/store must do, without framework-specific logic.
- **`NsgDataControllerV2`** is the data facade. It combines query and command behavior, updates snapshot status (`loading/success/error`) and works with cache/request params.
- **`NsgViewControllerV2`** owns page-local state (`selectedItem`, `backupItem`, modification lifecycle) and delegates persistence to the data controller.
- **`NsgControllerStore<T>`** is the single source of truth: all controller state changes are published through snapshot updates.
- **`data_source`** isolates transport/storage (`remote` vs `local`), so controller logic does not depend on storage implementation details.
- **`bloc` / `riverpod` adapters** are thin wrappers: they subscribe to controller snapshot stream and expose convenience methods without duplicating business rules.
