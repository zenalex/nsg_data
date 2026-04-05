# Riverpod MVP Slice For `nsg_data`

## Цель

Этот документ фиксирует минимальный первый срез реализации нового `Riverpod`-слоя в `nsg_data`.

Задача первого этапа:

- не заменить весь `GetX`-слой;
- не переписать `NsgBaseController`;
- не внедрять сразу полный framework нового поколения;
- а собрать маленький, рабочий и расширяемый набор абстракций, на котором можно реализовать первые новые экраны.

## Что входит в MVP

В первый этап входят только базовые кирпичики:

1. `state`
2. `query`
3. `repository`
4. `notifier`
5. `provider`

На этом этапе не входят:

- навигация;
- совместимость с `obx`;
- переписывание legacy controller API;
- универсальные table/form сценарии повышенной сложности;
- замена `Bindings`.

## Основной сценарий MVP

Первый MVP должен покрывать самый частый и самый дешевый сценарий:

- загрузить список объектов;
- обновить список;
- выбрать элемент;
- открыть экран просмотра/редактирования уже на стороне приложения;
- редактировать отдельный объект через draft;
- сохранить изменения.

То есть целевая первая функциональность:

- `list + edit`

Без попытки сразу решить:

- сложный master-detail;
- табличные части;
- синхронизацию нескольких экранов;
- сложную lazy-loading UI интеграцию.

## Предлагаемый минимальный состав файлов

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
```

## 1. State layer

### `nsg_list_state.dart`

Состояние списка.

Минимальный состав:

- `items`
- `query`
- `selectedId`
- `isLoading`
- `isRefreshing`
- `isLoadingMore`
- `hasMore`
- `error`
- `totalCount`

Важно:

- состояние списка не должно содержать UI-объекты;
- выбранный элемент лучше хранить отдельно как `selectedId`, а не как mutable shared object.
- элементы списка должны записываться в state через `clone()`;
- коллекция `items` должна быть неизменяемой снаружи.

### `nsg_edit_state.dart`

Состояние редактирования.

Минимальный состав:

- `original`
- `draft`
- `isDirty`
- `isSaving`
- `validationErrors`
- `error`

Это будет замена связке:

- `selectedItem`
- `backupItem`
- `isModified`

из legacy controller-мира.

## 2. Query layer

### `nsg_list_query.dart`

Минимальный объект описания списка.

Должен включать:

- `NsgDataRequestParams requestParams`

На первом этапе можно не пытаться вынести все варианты фильтрации в отдельные мелкие типы.

Главное:

- `NsgDataRequestParams` уже содержит `top`, `count`, `referenceList`, поэтому не надо дублировать их в `NsgListQuery`;
- query должен быть immutable;
- `requestParams` внутри query должен клонироваться при создании и копировании;
- query должен быть easy to copy;
- query должен быть пригоден для `provider.family`.

## 3. Repository layer

### `nsg_entity_repository.dart`

Базовый интерфейс репозитория для объекта `T extends NsgDataItem`.

Минимальный контракт:

- `Future<List<T>> fetchList(NsgListQuery query)`
- `Future<T> fetchItem(String id, {List<String>? referenceList})`
- `Future<T> createDraft()`
- `Future<T> cloneAsDraft(T item)`
- `Future<T> save(T item)`
- `Future<void> deleteMany(List<T> items)`

Важно:

- repository не должен знать о `Riverpod`;
- repository не должен знать о `BuildContext`;
- repository не должен знать о навигации.

### `nsg_default_entity_repository.dart`

Первая реализация базового интерфейса поверх текущего `nsg_data`.

Может использовать:

- `NsgDataClient.client.getNewObject(...)`
- `NsgDataRequest<T>`
- `NsgDataRequestParams`
- `NsgDataPost`
- `NsgDataDelete`

Это должен быть bridge между новым state-layer и текущим transport/data-layer.

## 4. Notifier layer

### `nsg_list_notifier.dart`

Минимальный список-команд для списка:

- `load()`
- `refresh()`
- `setQuery(...)`
- `select(String id)`
- `clearSelection()`

Ответственность:

- работать только со списком;
- не держать draft редактирования;
- не выполнять навигацию;
- не хранить view-specific logic.

`NsgListNotifier<T>` должен управлять `NsgListState<T>`.

По умолчанию list notifier лучше делать на `Notifier`, а не на `AutoDisposeNotifier`, чтобы состояние списка переживало переходы между экранами.

### `nsg_edit_notifier.dart`

Минимальный edit API:

- `create()`
- `loadById(String id)`
- `seedFromItem(T item)`
- `setDraft(T draft)`
- `updateDraft(T Function(T draft) update)`
- `validate()`
- `save()`
- `reset()`

Ответственность:

- управлять только edit-сценарием;
- не делать list orchestration;
- не решать routing/navigation задачи.

`NsgEditNotifier<T>` должен управлять `NsgEditState<T>`.

Для `save()` нужно сразу зафиксировать поведение:

- при ошибках валидации notifier пишет `validationErrors` в state и возвращает `null`;
- при repository/transport ошибках notifier пишет `error` в state и возвращает `null`.

## 5. Provider layer

### `nsg_core_providers.dart`

На первом этапе достаточно базовых helper provider-ов.

Не нужно пытаться сразу собрать всю систему generic provider factories.

Минимально допустимо:

- provider репозитория для конкретной feature;
- `NotifierProvider` для списка;
- `AutoDisposeNotifierProviderFamily` для editor-сценариев.

То есть сначала лучше ориентироваться не на "идеальный generic framework", а на понятную прикладную сборку.

Для create/edit режима лучше использовать общий аргумент режима, например:

- `NsgEditArgCreate()`
- `NsgEditArgExisting(id)`

У этого аргумента обязательно должны быть корректные `==` и `hashCode`, потому что он используется как key для `family` provider.

## Решение по code generation

В первом MVP code generation не используется:

- без `freezed`;
- без `@riverpod`;
- без `riverpod_generator`.

Причина проста: сначала нужно стабилизировать сами runtime-контракты, а уже потом снижать boilerplate.

## Пример использования MVP в feature

Пример структуры уже в приложении, а не в `nsg_data`:

```text
feature/
  user_role/
    user_role_repository.dart
    user_role_list_provider.dart
    user_role_edit_provider.dart
```

Где:

- `user_role_repository.dart` использует `NsgDefaultEntityRepository<UserRole>`
- `user_role_list_provider.dart` использует `NsgListNotifier<UserRole>`
- `user_role_edit_provider.dart` использует `NsgEditNotifier<UserRole, NsgEditArg>`

Таким образом `nsg_data` предоставляет базовые building blocks, а feature-модули собираются уже в приложении.

## Что не надо делать в MVP

### Не делать `NsgRiverpodBaseController`

На первом этапе не нужен новый аналог `NsgBaseController`.

Причины:

- это снова приведет к слишком жирному базовому классу;
- появится соблазн перенести старый API почти без изменений;
- архитектура снова станет controller-centric вместо state-centric.

### Не делать совместимость с `GetStatus`

Новый слой должен сразу жить на собственных state-моделях.

Иначе получится гибрид, который будет тяжело поддерживать.

### Не делать table layer первым

`NsgDataTableController` у вас сильно завязан на:

- `masterController`
- `selectedItem`
- `Get.back()`
- сценарии редактирования строки

Это не лучший первый кандидат для миграции.

### Не делать UI helpers в ядре

Первый MVP не должен включать:

- `NsgAsyncState<T>` как общую async-абстракцию;
- аналоги `obx`;
- widget helper-методы;
- `BuildContext` в state/repository;
- screen composition helpers.

## Порядок реализации

### Шаг 1. State

Сначала собрать state-модели:

- `NsgListState<T>`
- `NsgEditState<T>`

Это фиксирует новый контракт состояния.

### Шаг 2. Query

Сделать `NsgListQuery`.

Это фиксирует новый контракт описания списка.

### Шаг 3. Repository interface

Сделать `NsgEntityRepository<T>`.

Это отделит:

- источник данных;
- бизнес-операции;
- состояние.

### Шаг 4. Default repository implementation

Сделать `NsgDefaultEntityRepository<T>`.

Это даст reuse существующего data-layer без переписывания transport.

### Шаг 5. List notifier

Сделать `NsgListNotifier<T>`.

После этого уже можно строить первые list-экраны на `Riverpod`.

### Шаг 6. Edit notifier

Сделать `NsgEditNotifier<T>`.

После этого уже можно строить первые edit-экраны на `Riverpod`.

## Первая целевая feature для обкатки

Для первого внедрения лучше выбрать простой модуль:

- справочник;
- список ролей;
- список уведомлений;
- настройки;
- любой экран без сложного master-detail.

Не стоит первым брать:

- `Project`
- `Tasks`
- `TaskBoard`
- табличные части

## Признаки успешного MVP

MVP можно считать удачным, если:

1. новый экран работает без `GetView`;
2. новый экран не зависит от `Get.find()` как от источника состояния;
3. список и редактирование живут в отдельных state units;
4. `NsgDataItem` не протекает в state как общая mutable-ссылка без `clone()`;
5. `nsg_data` при этом продолжает использовать существующий data-layer;
6. legacy-экраны и legacy-контроллеры не пришлось ломать.

## Decision

Первый технический срез для `nsg_data` должен быть небольшим и прагматичным:

- два state-файла;
- один query-файл;
- один repository interface;
- одна default repository implementation;
- два notifier-файла;
- минимальный provider entrypoint.

Это даст рабочий старт новой архитектуре и не приведет к преждевременному переписыванию всего framework-слоя.
