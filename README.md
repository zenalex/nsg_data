# nsg_data

Core-библиотека данных NSG для Flutter: модели предметной области, транспорт к API, контроллеры загрузки/фильтрации/сохранения, локальное хранилище и авторизация.

## Что решает пакет

- описывает data model через `NsgDataItem` и типизированные поля;
- выполняет сетевые запросы и авторизацию через `NsgDataProvider`;
- предоставляет контроллеры (`NsgBaseController`, `NsgDataController`) для страниц списков/карточек;
- поддерживает серверный и локальный (`NsgLocalDb`) режимы хранения;
- дает общие утилиты для фильтрации, сортировки, навигации и ошибок API.

## Установка

### Локально (mono-repo)

```yaml
dependencies:
  nsg_data:
    path: ../nsg_data
```

### Hosted package

```yaml
dependencies:
  nsg_data: ^1.0.0
```

Затем:

```bash
flutter pub get
```

## Архитектура (коротко)

- `NsgDataProvider` — подключение к серверу, токены, login/logout, базовые HTTP-запросы.
- `NsgDataClient.client` — реестр типов данных и фабрика новых объектов.
- `NsgDataItem` — базовый класс доменной модели.
- `NsgBaseController` / `NsgDataController<T>` — state + запросы + фильтрация + CRUD.
- `NsgDataRequest` / `NsgDataPost` — низкоуровневые операции чтения/записи.

## Быстрый старт

### 1) Создайте `NsgDataProvider`

```dart
import 'package:nsg_data/nsg_data.dart';

final provider = NsgDataProvider(
  applicationName: 'footballers_diary_app',
  applicationVersion: '1.0.0',
  firebaseToken: '',
  availableServers: NsgServerParams(
    {
      'https://your-main-server.com': 'main',
      'https://your-test-server.com': 'test',
    },
    'https://your-main-server.com',
  ),
  // eventOpenLoginPage: () async { ... }, // если нужен кастомный экран логина
);
```

## Serverpod

`nsg_data` can now work with `serverpod` as an alternative server transport without changing `NsgDataController` or `NsgInput`.

```dart
class CompanyItem extends NsgServerpodDataItem<CompanyDto> {
  @override
  String get apiRequestItems => '/company';

  @override
  CompanyItem getNewObject() => CompanyItem();

  @override
  CompanyDto createServerpodModel(Map<String, dynamic> json) => CompanyDto.fromJson(json);

  @override
  void initialize() {
    addField(NsgDataStringField('id'), primaryKey: true);
    addField(NsgDataStringField('name'));
  }
}

final provider = NsgDataProvider(
  applicationName: 'titan_control',
  applicationVersion: '1.0.0',
  firebaseToken: '',
  availableServers: availableServers,
  providerKind: NsgRemoteProviderKind.serverpod,
  serverpodAdapter: NsgServerpodAdapter(
    fetchItems: (context) async => client.company.list(context.filter),
    postItems: (context) async => client.company.saveMany(
      context.items.map((e) => (e as CompanyItem).toServerpodModel()).toList(),
    ),
    deleteItems: (context) async {
      await client.company.deleteMany(context.items.map((e) => e.id).toList());
    },
  ),
);
```

For per-entity customization you can override `serverpodAdapter` directly in a concrete `NsgDataItem`.

## Dependencies
### 2) Инициализируйте и подключитесь

```dart
await provider.initialize();
// Обычно connect вызывается из контроллера:
// await provider.connect(controller);
```

### 3) Зарегистрируйте типы данных в `NsgDataClient`

```dart
NsgDataClient.client.registerDataItem(YourDataItem()..remoteProvider = provider);
```

### 4) Используйте контроллер данных

```dart
final controller = NsgDataController<YourDataItem>(
  dataType: YourDataItem,
  requestOnInit: true,
);
```

## Авторизация и токены

`NsgDataProvider` поддерживает:

- анонимный вход (`AnonymousLogin`);
- вход по телефону/e-mail и SMS (`phoneLoginRequestSMS`, `phoneLogin`);
- парольный сценарий (`phoneLoginPassword`);
- logout (`logout`) и сброс токена (`resetUserToken`);
- уведомления о смене токена (`tokenChanges`, `onTokenChanged`);
- web sync токена между вкладками (через `CrossTabAuth`).

## Работа с серверами

Через `NsgServerParams` можно:

- хранить набор адресов окружений (main/test/etc);
- сохранять и восстанавливать выбранный сервер;
- хранить токены отдельно для разных групп серверов.

## Запросы и фильтры

Основные инструменты:

- `NsgCompare` + `NsgComparisonOperator` — построение условий;
- `NsgDataRequestParams` — параметры запроса;
- `NsgSorting` — сортировка;
- `controller.getRequestFilter` — сбор итогового фильтра в контроллере.

## Локальное хранение

Для offline/кэш-сценариев можно использовать `NsgLocalDb` и переключать `controllerMode.storageType`.

## Публичный API

Главная точка входа: `package:nsg_data/nsg_data.dart`.

Экспортируются:

- data fields (`stringField`, `dateField`, `referenceField`, и др.);
- контроллеры (`nsgDataController`, `nsgBaseController`, `nsgDataTableController`);
- provider/request/post API;
- навигация (`NsgNavigator`, middleware/page helpers);
- вспомогательные типы (`NsgPeriod`, validate/result, sorting, exceptions).

## Замечание про публикацию

В монорепе `nsg_data` обычно используется вместе с `nsg_controls` и `nsg_login`; при публикации на pub.dev учитывайте версии зависимостей между пакетами.

## Лицензия

MIT, подробнее в `LICENSE`.
