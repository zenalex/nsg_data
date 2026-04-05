# Riverpod Controller Architecture For `nsg_data`

## Цель

Этот документ описывает целевую структуру нового слоя управления состоянием для `nsg_data`.

Задача не в том, чтобы переписать текущие `GetX`-контроллеры один в один, а в том, чтобы:

- сохранить существующий data-layer (`NsgDataItem`, `NsgDataRequest`, `NsgDataProvider`, `NsgDataClient`);
- построить рядом новый state-layer на `Riverpod`;
- дать возможность постепенно переводить экраны с `GetX` на `Riverpod`;
- не ломать текущие `Bindings`, `Get.find()` и `obx()` в legacy-экранах.

## Что остается без изменений на первом этапе

Следующие сущности остаются рабочей основой и не переписываются в первой итерации:

- `NsgDataItem`
- `NsgDataRequest`
- `NsgSimpleRequest`
- `NsgDataProvider`
- `NsgDataClient`
- модели, поля, сортировка, фильтры, сравнения
- серверная интеграция и локальная БД

Это важно: новая архитектура должна строиться поверх уже работающего data-layer, а не заменять его сразу.

## Что считается legacy-слоем

Текущая controller-архитектура считается legacy-слоем:

- `NsgBaseController`
- `NsgDataController<T>`
- `NsgDataTableController<T>`
- `NsgDataUI<T>`
- экранные паттерны на `GetView`, `Get.find`, `controller.obx(...)`

Этот слой будет продолжать работать параллельно, пока приложение не будет постепенно переведено на новый state-layer.

## Главный принцип новой схемы

Новый слой не должен повторять все обязанности старого `NsgBaseController`.

Старый контроллер совмещает:

- загрузку данных;
- выбранный элемент;
- черновик редактирования;
- статус загрузки;
- lifecycle;
- UI helper API;
- навигационные helper-методы;
- реактивные уведомления для GetX.

В новом подходе эти обязанности разделяются на отдельные объекты.

## Новые типы объектов

### 1. Query object

Объект запроса описывает, какие данные и как именно нужно загружать.

Пример задач query object:

- фильтры;
- сортировка;
- пагинация;
- `referenceList`;
- параметры привязки к master object;
- специальные параметры для server-side запросов.

Пример будущих сущностей:

- `NsgListQuery`
- `NsgItemQuery`
- `NsgTableQuery`

Эти объекты должны быть простыми immutable-моделями без UI-логики.

### 2. Repository

Repository отвечает за чтение и запись данных через текущий `nsg_data` transport layer.

Repository не должен зависеть от:

- `GetX`;
- `BuildContext`;
- роутинга;
- UI-компонентов.

Пример будущих интерфейсов:

- `NsgListRepository<T extends NsgDataItem>`
- `NsgEntityRepository<T extends NsgDataItem>`
- `NsgTableRepository<T extends NsgDataItem>`

Пример обязанностей:

- `fetchList(query)`
- `fetchItem(id, referenceList)`
- `createDraft()`
- `save(item)`
- `delete(items)`
- `copy(item)`

Repository может использовать:

- `NsgDataRequest`
- `NsgSimpleRequest`
- `NsgDataTable`
- `NsgDataClient`

## 3. State objects

Состояние должно быть явным и типизированным.

Вместо implicit-состояния внутри контроллера вводятся отдельные state-объекты.

### 3.1 `NsgListState<T>`

Состояние списка.

Содержит:

- список `items`;
- `query`;
- `totalCount`;
- `selectedId`;
- `hasMore`;
- флаги `isLoading`, `isRefreshing`, `isLoadingMore`;
- ошибку;
- служебные данные для пагинации.

Важное ограничение первого этапа:

- `NsgDataItem` остается мутабельным типом;
- при записи в state объекты должны клонироваться;
- коллекции должны храниться в неизменяемом виде.

### 3.2 `NsgItemState<T>`

Состояние просмотра одного объекта.

Содержит:

- `item`;
- `referenceList`;
- `isLoading`;
- `error`;
- `isStale`;

Этот объект остается допустимым только для более позднего этапа и не входит в MVP.

### 3.3 `NsgEditState<T>`

Состояние редактирования.

Содержит:

- `original`;
- `draft`;
- `isDirty`;
- `isSaving`;
- `validationErrors`;
- `error`;

`original` и `draft` также должны храниться как клоны, а не как внешние mutable-ссылки.

### 3.4 `NsgTableState<T>`

Состояние табличной части.

Содержит:

- `rows`;
- `ownerId`;
- `tableFieldName`;
- `selectedRowId`;
- `isDirty`;
- `isSaving`;

Этот объект тоже откладывается на второй этап.

### 3.5 Почему `NsgAsyncState<T>` исключен из MVP

Первоначально планировался общий async building block, но в первом этапе он не используется.

Причины:

- `NsgListState` и `NsgEditState` уже покрывают нужный async-state;
- отдельная абстракция пока не даёт полезного reuse;
- это преждевременное усложнение.

## 4. Riverpod controllers

Новые "контроллеры" в архитектурном смысле лучше оформлять как `Notifier` / `AsyncNotifier`, а не как универсальный базовый controller с UI API.

### 4.1 `NsgListNotifier<T>`

Отвечает за список данных.

Обязанности:

- initial load;
- refresh;
- load more;
- change query;
- выбор текущего элемента списка.

Пример публичного API:

- `load()`
- `refresh()`
- `loadMore()`
- `setQuery(...)`
- `select(...)`

Решение по lifecycle:

- по умолчанию list notifier должен быть `Notifier`, а не `AutoDisposeNotifier`;
- список обычно должен переживать переходы между экранами;
- если конкретной feature нужен иной lifecycle, это решается на уровне feature-provider.

### 4.2 `NsgItemNotifier<T>`

Отвечает за загрузку и обновление одного объекта по id.

Обязанности:

- загрузить item;
- перечитать item;
- обновить после внешних изменений.

Пример API:

- `load(id)`
- `reload()`
- `invalidate()`

### 4.3 `NsgEditNotifier<T>`

Отвечает за сценарий создания и редактирования.

Обязанности:

- создать draft;
- загрузить item по id в draft;
- менять draft;
- валидировать;
- сохранять;
- отменять изменения.

Пример API:

- `create()`
- `loadById(id)`
- `seedFromItem(item)`
- `updateDraft(...)`
- `save()`
- `reset()`

Решение по lifecycle:

- edit notifier по умолчанию должен быть `AutoDisposeFamilyNotifier`;
- edit-сценарий чаще всего одноразовый и должен очищаться после закрытия;
- для family-аргумента лучше использовать общий `NsgEditArg`, а не `String?`;
- `NsgEditArg` должен иметь корректные `==` и `hashCode`.

### 4.4 `NsgTableNotifier<T>`

Отвечает за табличные части.

Обязанности:

- загрузка строк из owner object;
- добавление строки;
- редактирование строки;
- удаление строки;
- сохранение изменений.

### 4.5 `NsgSelectionNotifier<T>`

Опциональный узкий объект для shared selection-сценариев.

Нужен там, где раньше использовались:

- `masterController`;
- `selectedItem`;
- `selectedMasterRequired`;

Его задача - не хранить весь список, а только текущий выбор и события его изменения.

## 5. Provider structure

Новый слой должен быть собран из маленьких provider-объектов, а не из одного глобального registry.

Рекомендуемая структура:

- provider репозитория;
- provider списка;
- provider режима редактирования;
- provider выбранного объекта;
- provider табличной части.

Примерный вид:

- `projectRepositoryProvider`
- `projectListProvider`
- `selectedProjectProvider`
- `projectEditorProvider`
- `projectUsersTableProvider`

Важно: один экран должен зависеть от понятного набора provider-объектов, а не от одного большого универсального controller.

## 6. Предлагаемая структура каталогов

Новый слой стоит держать отдельно от legacy controllers.

Предлагаемая структура внутри `lib`:

```text
lib/
  riverpod/
    core/
      state/
        nsg_list_state.dart
        nsg_edit_state.dart
      query/
        nsg_list_query.dart
      repository/
        nsg_entity_repository.dart
        nsg_default_entity_repository.dart
      notifier/
        nsg_list_notifier.dart
        nsg_edit_notifier.dart
      provider/
        nsg_core_providers.dart
    features/
      project/
        project_repository.dart
        project_list_provider.dart
        project_edit_provider.dart
      task/
        ...
```

Принцип:

- `controllers/` остаются для legacy GetX-слоя;
- `riverpod/` содержит новый слой;
- новая архитектура живет рядом, а не внутри старых контроллеров.

## 7. Mapping с текущей архитектуры

### Старый список

Сейчас:

- `NsgDataController<T>` хранит `items`, `currentItem`, `status`, сортировку, фильтры и refresh-логику.

Будет:

- `NsgListQuery`
- `NsgListState<T>`
- `NsgListNotifier<T>`
- `NsgEntityRepository<T>`

### Старое редактирование

Сейчас:

- `selectedItem`
- `backupItem`
- `isModified`
- `itemPagePost()`
- `itemPageCancel()`

Будет:

- `NsgEditState<T>`
- `NsgEditNotifier<T>`

### Старые табличные части

Сейчас:

- `NsgDataTableController<T>`

Будет:

- `NsgTableState<T>`
- `NsgTableNotifier<T>`

Но не в первом MVP.

### Старый master-detail

Сейчас:

- `masterController`
- `dependsOnControllers`
- события `selectedItemChanged`

Будет:

- explicit provider dependencies;
- `selected item` provider;
- семейства provider-объектов (`family`);
- при необходимости узкий selection notifier.

## 8. Что не надо переносить в новый слой

Следующие вещи не стоит повторять в Riverpod-слое как есть:

- `NsgAsyncState<T>` в первом MVP как общую базовую async-абстракцию;
- `obx()`
- `GetStatus`
- `Get.find()`
- `Get.back()`, `Get.toNamed()` и другая навигация;
- `BuildContext` внутри core state objects;
- UI helper-методы внутри repository/notifier;
- универсальный "mega-controller", который делает сразу все.

Новый слой должен быть UI-agnostic.

UI должен получать:

- state;
- команды;
- события сохранения/ошибки;

но не знать о внутреннем устройстве transport layer.

## 9. Минимальный контракт для первого этапа

Чтобы начать миграцию без большого рефакторинга, достаточно реализовать:

1. базовые state-объекты;
2. базовые repository interface + default implementation поверх `NsgDataRequest`;
3. `NsgListNotifier<T>`;
4. `NsgEditNotifier<T>`;
5. feature-level providers для 1-2 простых модулей.

На первом этапе не нужно:

- переписывать `NsgBaseController`;
- удалять `GetX`;
- трогать legacy navigation;
- пытаться сделать совместимость с `obx`;
- вводить code generation (`freezed`, `riverpod_generator`, `riverpod_annotation`);
- делать table layer;
- делать item layer как отдельный обязательный слой.

## 10. Порядок миграции

### Шаг 1

Добавить новый пакетный слой `lib/riverpod`.

### Шаг 2

Собрать core abstractions:

- state
- query
- repository
- notifier

Решение по codegen на этом этапе:

- ручные provider-ы;
- без `freezed`;
- без `@riverpod`.

### Шаг 3

Выбрать 1 простой модуль и сделать для него первую реализацию:

- например роли, уведомления или справочники без сложного master-detail.

### Шаг 4

Начать писать новые экраны на `Riverpod`, не трогая старые экраны на `GetX`.

### Шаг 5

Когда паттерн стабилизируется, переносить более сложные feature:

- project
- task
- table editors
- item-specific providers

## 11. Decision

Для `nsg_data` рекомендуется стратегия parallel architecture:

- legacy GetX controllers остаются;
- новый Riverpod state-layer создается рядом;
- экраны мигрируют постепенно;
- foundation transport/data layer переиспользуется;
- отказ от `GetX` в базовом слое откладывается до момента, когда новый слой покроет большую часть сценариев.

Это наиболее безопасный путь для текущей кодовой базы.
