# Shell Interfaces

## Цель

На этапе `TASK02` shell-зависимости выносятся из прямых вызовов `Get.*` в package-owned контракты, которые могут иметь:

- default `GetX` implementation
- альтернативную реализацию в будущем
- точку подмены без немедленного переписывания существующих приложений

## Введенные контракты

Базовый слой находится в `nsg_data/lib/shell/nsg_shell.dart`.

### `NsgNavigationShell`

Отвечает за navigation API и route state:

- `currentRoute`
- `previousRoute`
- `parameters`
- `toNamed(...)`
- `offAndToNamed(...)`
- `back(...)`

Назначение:

- убрать прямую зависимость внутренних мест пакетов от `Get.toNamed`, `Get.offAndToNamed`, `Get.back`
- сохранить старое поведение через default adapter
- подготовить seam для будущего custom shell или Riverpod-oriented composition

### `NsgDialogShell`

Отвечает за modal/dialog presentation:

- `show(...)`

Назначение:

- убрать прямые вызовы `Get.dialog(...)` из контролов и helper-ов
- оставить совместимую семантику `barrierDismissible` и `barrierColor`

### `NsgMessageShell`

Отвечает за user messages, которые раньше показывались через `Get.snackbar(...)`:

- `showSnackbar(...)`

Дополнительно введен package-owned enum:

- `NsgMessagePosition`

Назначение:

- убрать прямую привязку базовых пакетов к `Get.snackbar`
- не тащить `SnackPosition` как обязательный тип в framework-agnostic слой

### `NsgEnvironmentShell`

Отвечает за доступ к shell/environment state:

- `context`
- `requireContext`
- `locale`
- `width`
- `height`

Назначение:

- убрать прямые обращения к `Get.context`, `Get.locale`, `Get.width`, `Get.height`
- дать единое место доступа к environment state

## Registry и default behavior

Для runtime-выбора реализаций введен package-level registry:

- `NsgShell.navigation`
- `NsgShell.dialog`
- `NsgShell.message`
- `NsgShell.environment`

Поддерживаются:

- `NsgShell.configure(...)`
- `NsgShell.resetToDefaults()`

Это позволяет:

- оставить `GetX` default implementation без изменений в старых приложениях
- точечно подменять реализации в bootstrap будущих приложений

## Default GetX adapters

По умолчанию используются:

- `NsgGetXNavigationShell`
- `NsgGetXDialogShell`
- `NsgGetXMessageShell`
- `NsgGetXEnvironmentShell`

Они по-прежнему делегируют в `GetX`, но теперь эта зависимость локализована в одном adapter layer, а не размазана по пакетам.

## Что уже переведено на новый слой

### В `nsg_data`

На shell contracts переведены основные места:

- `NsgNavigator`
- `NsgMiddleware` route params access
- controller navigation/context fallbacks в `nsgBaseController` и `nsgDataTableController`
- provider-level snackbar calls
- часть auth/context usage
- locale access в `nsg_data_ui`

### В `nsg_controls`

На shell contracts переведена значимая часть shell-вызовов:

- dialogs в save/cancel, errors, period filter, file picker, table, multi-selection
- navigation/back в list/input/file-picker flows
- locale/context helpers
- width/height access в list, file picker, table helpers, overlay positioning
- snackbar/message calls в file picker и shared helpers

## Что сознательно не решается этим этапом

Этот слой не пытается пока заменить:

- `GetxController`
- `GetBuilder`
- `StateMixin`
- `GetStatus`

Это следующий seam, а не shell seam.

## Ключевой итог этапа

Теперь `GetX` выступает не как единственный способ вызвать shell-функции, а как default adapter behind package-owned contracts. Это и есть нужная совместимая промежуточная архитектура для дальнейших шагов программы.
