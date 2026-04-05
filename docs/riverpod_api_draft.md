# Riverpod API Draft For `nsg_data`

## Цель

Этот документ фиксирует технический черновик API для первого набора `Riverpod`-объектов в `nsg_data`.

Это не финальная реализация и не окончательный public API пакета.
Это рабочий draft, который нужен для:

- согласования структуры первых классов;
- фиксации минимального контракта;
- уменьшения архитектурной неопределенности перед кодингом.

Документ покрывает:

- state objects;
- query object;
- repository contract;
- notifier contract.

## Общие принципы

### 1. Новый API не повторяет `GetX` API

Новый слой не должен пытаться воспроизвести:

- `obx`
- `GetStatus`
- `sendNotify`
- `Get.find`
- `update(keys)`

Вместо этого вводится обычный state-driven API.

### 2. Все core-объекты должны быть UI-agnostic

Нельзя тащить в новый core слой:

- `BuildContext`
- `Widget`
- навигацию
- зависимости на `GetX`

### 3. Объекты должны быть immutable там, где это возможно

Особенно это касается:

- query
- state

### 4. Сначала проектируем простые generic contracts

На первом этапе не нужно проектировать сверх-универсальный framework со множеством extension points.

Нужен небольшой и читаемый базовый контракт.

### 5. Code generation в первой итерации не используем

На первом этапе не вводим:

- `freezed`
- `riverpod_annotation`
- `riverpod_generator`

Причины:

- текущая задача - зафиксировать минимальный runtime-контракт;
- в `nsg_data` пока нет riverpod/codegen зависимостей;
- добавление codegen сейчас увеличит количество moving parts.

Решение:

- первая итерация делается на ручных provider-ах и обычных immutable class;
- если boilerplate окажется избыточным, `freezed` и `@riverpod` рассматриваются на втором этапе.

## 1. State API

## 1.1 `NsgListState<T extends NsgDataItem>`

Назначение:

- состояние списка;
- хранение query;
- выбранный элемент;
- признаки загрузки списка.

Предлагаемый состав:

```dart
import 'dart:collection';

class NsgListState<T extends NsgDataItem> {
  final UnmodifiableListView<T> items;
  final NsgListQuery query;
  final String? selectedId;
  final int? totalCount;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Object? error;
  final StackTrace? stackTrace;

  NsgListState({
    Iterable<T> items = const [],
    NsgListQuery? query,
    this.selectedId,
    this.totalCount,
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.stackTrace,
  }) : query = query ?? NsgListQuery(),
       items = UnmodifiableListView<T>(
         items.map((e) => e.clone() as T),
       );

  NsgListState._trusted({
    required this.items,
    required this.query,
    required this.selectedId,
    required this.totalCount,
    required this.hasMore,
    required this.isLoading,
    required this.isRefreshing,
    required this.isLoadingMore,
    required this.error,
    required this.stackTrace,
  });

  T? get selectedItem {
    if (selectedId == null) return null;
    for (final item in items) {
      if (item.id == selectedId) return item;
    }
    return null;
  }
  bool get hasError => error != null;
  bool get isEmpty => items.isEmpty;
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;

  NsgListState<T> copyWith({
    Iterable<T>? items,
    NsgListQuery? query,
    String? selectedId = _sentinelString,
    int? totalCount = _sentinelInt,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _sentinel,
    StackTrace? stackTrace = _sentinel,
  }) {
    return NsgListState<T>._trusted(
      items: items != null
          ? UnmodifiableListView<T>(items.map((e) => e.clone() as T))
          : this.items,
      query: query ?? this.query,
      selectedId: identical(selectedId, _sentinelString)
          ? this.selectedId
          : selectedId,
      totalCount: identical(totalCount, _sentinelInt)
          ? this.totalCount
          : totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error,
      stackTrace: identical(stackTrace, _sentinel)
          ? this.stackTrace
          : stackTrace,
    );
  }
}
```

Решение по `selectedItem`:

- основное хранимое значение: `selectedId`;
- `selectedItem` вычисляется из `items`;
- это снижает риск рассинхронизации.

Решение по мутабельности:

- `NsgDataItem` в текущей системе мутабелен;
- поэтому state не делает вид, что хранит truly immutable domain object;
- на границе записи в state каждый объект должен клонироваться;
- коллекции должны храниться только как `UnmodifiableListView`;
- это осознанное ограничение первого этапа.

Решение по производительности:

- публичный конструктор клонирует входные элементы;
- `copyWith()` не должен повторно клонировать неизменившиеся `items`;
- для этого нужен внутренний `_trusted`-конструктор, который принимает уже защищённую коллекцию.

## 1.2 `NsgEditState<T extends NsgDataItem>`

Назначение:

- отдельное состояние редактирования;
- хранение `original` и `draft`;
- информация о dirty/saving/validation.

Предлагаемый состав:

```dart
class NsgEditState<T extends NsgDataItem> {
  final T? original;
  final T? draft;
  final bool isSaving;
  final bool isLoading;
  final Map<String, String> validationErrors;
  final Object? error;
  final StackTrace? stackTrace;

  const NsgEditState({
    this.original,
    this.draft,
    this.isSaving = false,
    this.isLoading = false,
    this.validationErrors = const {},
    this.error,
    this.stackTrace,
  });

  bool get hasDraft => draft != null;
  bool get hasError => error != null;
  bool get isDirty;

  NsgEditState<T> copyWith({
    T? original = _sentinelItem,
    T? draft = _sentinelItem,
    bool? isSaving,
    bool? isLoading,
    Map<String, String>? validationErrors,
    Object? error = _sentinel,
    StackTrace? stackTrace = _sentinel,
  });
}
```

Решение по `isDirty`:

- вычислять через `draft` и `original`;
- использовать уже существующий `isEqual(...)` у `NsgDataItem`.
- `original` и `draft` должны записываться в state как клоны, а не как исходные mutable-ссылки.

## 1.3 Почему `NsgAsyncState<T>` убран из первого этапа

Первоначально предполагался общий async building block, но в первой итерации он не нужен.

Причины:

- `NsgListState` и `NsgEditState` уже имеют собственные async-поля;
- отдельный `NsgAsyncState<T>` пока не даёт практической пользы;
- преждевременная абстракция только усложнит первый этап.

Решение:

- `NsgAsyncState<T>` не входит в MVP;
- к общей async-модели можно вернуться позже, если появится повторяемый шаблон.

## 2. Query API

## 2.1 `NsgListQuery`

Назначение:

- immutable описание того, как загружать список.

Предлагаемый состав:

```dart
class NsgListQuery {
  final NsgDataRequestParams requestParams;

  NsgListQuery({
    NsgDataRequestParams? requestParams,
  }) : requestParams = requestParams?.clone() ?? NsgDataRequestParams();

  NsgListQuery copyWith({
    NsgDataRequestParams? requestParams,
  });
}
```

Примечания:

- `NsgDataRequestParams` уже содержит `top`, `count`, `referenceList` и фильтрацию;
- дублирующие поля в `NsgListQuery` не вводим;
- `NsgListQuery` - это тонкая immutable-обёртка над `NsgDataRequestParams`;
- при записи и копировании `requestParams` должен клонироваться;
- query должен хорошо работать с `family` provider-ами.

## 3. Repository API

## 3.1 `NsgEntityRepository<T extends NsgDataItem>`

Назначение:

- единый контракт доступа к сущности и списку сущностей;
- bridge между `Riverpod` state-layer и текущим `nsg_data` transport layer.

Предлагаемый контракт:

```dart
abstract class NsgEntityRepository<T extends NsgDataItem> {
  Type get dataType;

  Future<List<T>> fetchList(NsgListQuery query);

  Future<T> fetchItem(
    String id, {
    List<String>? referenceList,
  });

  Future<T> createDraft();

  Future<T> cloneAsDraft(T item);

  Future<T> save(T item);

  Future<void> delete(T item) => deleteMany([item]);

  Future<void> deleteMany(List<T> items);
}
```

Допустимые расширения второго этапа:

- `copy(T item)`
- `postMany(List<T> items)`
- `validate(T item)`
- `fetchByQuery(...)`

Но в первом этапе это не обязательно.

## 3.2 `NsgDefaultEntityRepository<T extends NsgDataItem>`

Назначение:

- базовая реализация `NsgEntityRepository`;
- reuse существующего `nsg_data`.

Предлагаемый каркас:

```dart
class NsgDefaultEntityRepository<T extends NsgDataItem>
    implements NsgEntityRepository<T> {
  @override
  final Type dataType;

  const NsgDefaultEntityRepository({
    required this.dataType,
  });

  @override
  Future<List<T>> fetchList(NsgListQuery query);

  @override
  Future<T> fetchItem(
    String id, {
    List<String>? referenceList,
  });

  @override
  Future<T> createDraft();

  @override
  Future<T> cloneAsDraft(T item);

  @override
  Future<T> save(T item);

  @override
  Future<void> deleteMany(List<T> items);
}
```

Правила реализации:

- `createDraft()` должен использовать `NsgDataClient.client.getNewObject(dataType) as T`;
- `cloneAsDraft(...)` должен копировать объект в редактируемый draft;
- `save(...)` должен возвращать сохраненную версию объекта;
- repository не должен модифицировать глобальный UI state.

Примечание:

- `NsgDataClient.client.getNewObject(Type)` возвращает `NsgDataItem`, поэтому `as T` здесь нормален и ожидаем.

## 4. Notifier API

## 4.1 `NsgListNotifier<T extends NsgDataItem>`

Назначение:

- управлять только list state.

Предлагаемый каркас:

```dart
abstract class NsgListNotifier<T extends NsgDataItem>
    extends Notifier<NsgListState<T>> {
  ProviderListenable<NsgEntityRepository<T>> get repositoryProvider;

  NsgEntityRepository<T> get repository => ref.read(repositoryProvider);

  NsgListQuery get initialQuery => NsgListQuery();

  @override
  NsgListState<T> build() {
    return NsgListState<T>(query: initialQuery);
  }

  Future<void> load();

  Future<void> refresh();

  Future<void> loadMore();

  void setQuery(NsgListQuery query);

  void select(String? id);

  void clearSelection();

  void clearError();
}
```

Правила поведения:

- `load()` выполняет initial load;
- `refresh()` сохраняет текущие `items`, но включает `isRefreshing`;
- `loadMore()` добавляет новую порцию в конец списка;
- `setQuery(...)` только меняет query, а запуск загрузки решается явно;
- `select(...)` не должен триггерить загрузку.

Решение по lifecycle:

- list notifier по умолчанию не `autoDispose`;
- список обычно должен переживать переходы между экранами;
- если feature требует иного поведения, это решается на уровне конкретного provider.

## 4.2 `NsgEditNotifier<T extends NsgDataItem>`

Назначение:

- управлять только edit state.

Предлагаемый каркас:

```dart
abstract class NsgEditNotifier<T extends NsgDataItem, A>
    extends AutoDisposeFamilyNotifier<NsgEditState<T>, A> {
  ProviderListenable<NsgEntityRepository<T>> get repositoryProvider;

  NsgEntityRepository<T> get repository => ref.read(repositoryProvider);

  @override
  NsgEditState<T> build(A arg);

  Future<void> create();

  Future<void> loadById(String id);

  void seedFromItem(T item);

  void setDraft(T draft);

  void updateDraft(T Function(T currentDraft) update);

  Map<String, String> validate();

  Future<T?> save();

  void reset();

  void clearError();
}
```

Предлагаемые правила:

- `create()` создает новый draft через repository;
- `loadById(...)` является основным способом открытия edit state;
- `seedFromItem(...)` допускается как optional helper, если caller гарантирует свежие данные;
- `updateDraft(...)` меняет только draft;
- `validate()` не делает network calls;
- `save()` при ошибках валидации пишет `validationErrors` в state и возвращает `null`;
- `save()` при repository/transport ошибках пишет `error` в state и возвращает `null`;
- `reset()` возвращает draft к `original`.

## 5. Provider API

Первый шаг не требует сложного generic provider factory, но полезно заранее договориться о стиле.

## 5.1 Repository provider

Пример направления:

```dart
final userRoleRepositoryProvider =
    Provider<NsgEntityRepository<UserRole>>((ref) {
  return NsgDefaultEntityRepository<UserRole>(dataType: UserRole);
});
```

## 5.2 List provider

Пример направления:

```dart
final userRoleListProvider = NotifierProvider<
    UserRoleListNotifier, NsgListState<UserRole>>(
  UserRoleListNotifier.new,
);
```

## 5.3 Edit provider

Пример направления:

```dart
sealed class NsgEditArg {
  const NsgEditArg();
}

class NsgEditArgCreate extends NsgEditArg {
  const NsgEditArgCreate();

  @override
  bool operator ==(Object other) => other is NsgEditArgCreate;

  @override
  int get hashCode => runtimeType.hashCode;
}

class NsgEditArgExisting extends NsgEditArg {
  final String id;
  const NsgEditArgExisting(this.id);

  @override
  bool operator ==(Object other) =>
      other is NsgEditArgExisting && other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

final userRoleEditProvider = AutoDisposeNotifierProviderFamily<
    UserRoleEditNotifier, NsgEditState<UserRole>, NsgEditArg>(
  UserRoleEditNotifier.new,
);
```

Где параметр family:

- `NsgEditArgCreate()` для create mode;
- `NsgEditArgExisting(id)` для edit mode.

## 6. Decisions по типам и контрактам

## 6.1 Почему `error` это `Object?`, а не `String?`

Причины:

- не теряется тип исключения;
- можно по-разному маппить ошибки в UI;
- можно логировать и анализировать richer context.

## 6.2 Почему `selectedId`, а не `selectedItem`

Причины:

- меньше shared mutable state;
- проще поддерживать консистентность;
- проще обновлять список без гонок по ссылкам на объект.

## 6.3 Почему `edit` отдельно от `list`

Причины:

- меньше связности;
- меньше случайных перерисовок;
- проще писать тесты;
- проще переписывать экраны по одному.

## 6.4 Почему `repository` один, а не разные transport service и use case прямо сейчас

Причины:

- первый этап должен быть минимальным;
- repository уже дает хорошую границу ответственности;
- дробить дальше можно позже, если это реально потребуется.

## 6.5 Почему state хранит клоны `NsgDataItem`

Причины:

- `NsgDataItem` мутабелен;
- если хранить исходные ссылки, внешний код сможет менять state незаметно для notifier;
- clone-on-write - минимальная защита на первом этапе.

Ограничение:

- это не делает доменную модель truly immutable;
- это только уменьшает риск скрытой мутации.

## 6.6 Почему list по умолчанию `Notifier`, а edit `AutoDisposeNotifier`

Причины:

- list screen обычно должен кэшироваться между переходами;
- edit screen чаще всего одноразовый и должен очищаться после закрытия;
- это более безопасный дефолт, чем делать всё `autoDispose`.

Если конкретный list-экран должен auto-dispose:

- это решается отдельным provider;
- либо через `AutoDisposeNotifier` в самой feature.

## 6.7 Почему `NsgEditArg` общий и с value equality

Причины:

- family-аргументы в Riverpod должны иметь корректные `==` и `hashCode`;
- делать отдельный arg-type на каждую сущность слишком многословно;
- общий `NsgEditArg` покрывает типовой сценарий `create | existing(id)`.

Это обязательное решение, а не stylistic preference, потому что без value equality
family provider-ы будут создаваться повторно для логически одинаковых аргументов.

## 6.8 Почему `selectedItem` ищется по `id`

В `NsgDataItem` свойство `id` является основным строковым идентификатором объекта и проксируется через `primaryKeyField`.

Решение:

- в state и provider API используем `selectedId`;
- поиск `selectedItem` выполняется по `item.id`;
- отдельное использование `primaryKeyValue` не требуется.

## 7. Что допустимо отложить

Можно отложить на второй этап:

- `NsgAsyncState<T>`
- `NsgItemState<T>`
- `NsgItemNotifier<T>`
- table abstractions;
- selection notifier;
- optimistic updates;
- subscriptions/sync between providers;
- shared form-field abstractions;
- typed validation result object вместо `Map<String, String>`.

## 8. Минимальный порядок кодинга

Рекомендуемая очередность:

1. `NsgListQuery`
2. `NsgListState<T>`
3. `NsgEditState<T>`
4. `NsgEntityRepository<T>`
5. `NsgDefaultEntityRepository<T>`
6. `NsgListNotifier<T>`
7. `NsgEditNotifier<T>`

## 9. Definition of Done для API draft

API можно считать достаточно зрелым для старта реализации, если:

1. для list-сценария понятны все обязательные поля state;
2. для edit-сценария понятны все обязательные методы notifier;
3. repository можно реализовать поверх текущего `nsg_data` без переписывания transport layer;
4. новый код не зависит от `GetX`;
5. первый feature-модуль можно собрать без обращения к `NsgBaseController`.

## Decision

Первый реальный implementation contract для `nsg_data` должен строиться вокруг:

- `NsgListQuery`
- `NsgListState<T>`
- `NsgEditState<T>`
- `NsgEntityRepository<T>`
- `NsgDefaultEntityRepository<T>`
- `NsgListNotifier<T>`
- `NsgEditNotifier<T>`

Этого достаточно, чтобы начать писать новый `Riverpod`-слой без преждевременного переписывания всего legacy framework.
