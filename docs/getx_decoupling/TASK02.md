# TASK02 - Shell And Environment Interfaces With Default GetX Adapters

## Цель

Вынести из `nsg_data` и `nsg_controls` прямые shell-зависимости на `GetX` за интерфейсы, но сделать это так, чтобы старые приложения продолжили работать без обязательного переписывания bootstrap.

Это первый реальный кодовый этап, потому что shell seams дешевле и безопаснее, чем controller seams.

## Что считается shell-зависимостью

- navigation actions
- dialogs
- snackbar/messages
- текущий context
- locale access
- screen size / viewport
- route params/current route

## Что нужно спроектировать

Нужен небольшой набор интерфейсов, примерно такого типа:

- `NsgNavigationShell`
- `NsgDialogShell`
- `NsgMessageShell`
- `NsgEnvironmentShell`

Можно выбрать другие имена, но смысл должен быть именно такой.

## Основное требование совместимости

Существующие приложения не должны быть обязаны вручную регистрировать эти интерфейсы сразу после обновления пакетов.

Нужна стратегия default behavior:

- либо package-level singleton с default GetX implementation
- либо service locator с default fallback implementation
- либо аналогичная схема, не требующая немедленного изменения каждого приложения

## Что нужно сделать

### 1. Добавить интерфейсы shell-уровня

Интерфейсы должны жить в framework-agnostic слое.

Они не должны импортировать `get`.

### 2. Добавить default GetX implementation

Нужно реализовать эти интерфейсы через `GetX` так, чтобы старый runtime behavior сохранился.

### 3. Перевести внутренние вызовы на интерфейсы

Вместо прямого:

- `Get.back()`
- `Get.dialog(...)`
- `Get.snackbar(...)`
- `Get.width`
- `Get.locale`

внутри пакетов должен использоваться новый shell layer.

### 4. Сохранить backward compatibility

Старые публичные entrypoints должны продолжить работать.

Если какой-то старый public API невозможно сохранить в точности, изменение должно быть:

- минимальным
- локальным
- документированным

## Особый фокус для `nsg_controls`

Особенно внимательно проверить:

- popup/dialog widgets
- progress dialogs
- `BodyWrap`
- app bar helpers
- `NsgInput`
- `NsgTable`
- file picker/dialog helpers
- helpers, где используется `Get.context`, `Get.width`, `Get.height`

## Что нужно документировать

Нужно создать:

- `shell_interfaces.md`
- `compatibility_bootstrap.md`

### `shell_interfaces.md`

Описывает новые shell contracts и их обязанности.

### `compatibility_bootstrap.md`

Описывает, почему старые приложения не обязаны сразу менять bootstrap, и где при желании можно подключить другую реализацию.

## Acceptance Criteria

- Введены framework-agnostic shell interfaces.
- Есть default GetX implementation.
- На обновление пакетов старые приложения не обязаны массово менять свой bootstrap.
- Внутри пакетов значимая часть shell-вызовов больше не идет напрямую в `Get.*`.
