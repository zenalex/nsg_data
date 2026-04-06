# Реестр зависимостей

## Область аудита

Этот реестр покрывает прямые зависимости от `GetX`, найденные в:

- `nsg_data`
- `nsg_controls`

Цель документа - зафиксировать, где именно используется `GetX`, какую роль он там играет и какие места наиболее чувствительны для совместимости существующих приложений.

## Обозначения

- `Категория`: `Shell services`, `Status / async state`, `Navigation API`, `Controller contracts`, `UI-only conveniences`, `Example/demo code`
- `Поверхность`: `Public surface`, `Compatibility-sensitive internal`, `Low-risk internal`
- `Можно ли заменить интерфейсом`: можно ли спрятать текущее использование за framework-agnostic контрактом без немедленного переписывания приложений

## Версии зависимостей

| Пакет | Зависимость от GetX |
| --- | --- |
| `nsg_data` | `get: ^5.0.0-release-candidate-9.2.1` |
| `nsg_controls` | `get: ^5.0.0-release-candidate-9.2.1` |

После унификации обе зависимости сидят на одной и той же `release-candidate` линии. Риск полного version mismatch между `nsg_data` и `nsg_controls` снят, но риск pre-stable поведения самого `GetX` все еще остается.

## `nsg_data`

| Файл | Прямое использование `GetX` | Роль | Категория | Можно ли заменить интерфейсом | Поверхность |
| --- | --- | --- | --- | --- | --- |
| `lib/controllers/nsgBaseController.dart` | `GetxController`, `StateMixin`, `GetStatus`, `Get.offAndToNamed`, `Get.back`, `Get.context` | Базовый тип контроллера, модель async-статуса, legacy refresh-механика, навигация item-страниц, fallback-доступ к context | `Controller contracts`, `Status / async state`, `Navigation API`, `Shell services` | Частично. Навигацию и context можно выносить раньше; controller/status требуют transitional bridge | `Public surface` |
| `lib/controllers/nsgDataController.dart` | `GetStatus.loading/success/error` | Распространение async-статуса в create/save flow | `Status / async state` | Да, через package-owned status contract и legacy mapping | `Public surface` |
| `lib/controllers/nsgDataTableController.dart` | `Get.back`, `Get.offAndToNamed`, `Get.context`, `GetStatus.success` | Навигация table edit flow, поведение close/cancel, статусные обновления | `Navigation API`, `Shell services`, `Status / async state` | Частично. Навигация и context хорошо выносятся в shell seam; статус требует bridge | `Public surface` |
| `lib/navigator/nsg_navigator.dart` | `Get.currentRoute`, `Get.toNamed`, `Get.offAndToNamed`, `Get.back` | Глобальный navigation facade, уже используемый и пакетами, и приложениями | `Navigation API` | Да, это один из самых ценных первых seam-кандидатов | `Public surface` |
| `lib/navigator/nsg_get_page.dart` | `GetPage` | Контракт регистрации роутов | `Shell services` | Только через compatibility adapter; прямое изменение заставит приложения менять bootstrap | `Public surface` |
| `lib/navigator/nsg_middleware.dart` | `GetMiddleware`, `Get.parameters` | Извлечение route params и hooks page pipeline | `Shell services` | Частично. Нужен adapter layer, потому что приложения уже могут вшивать это в `GetMaterialApp` routes | `Public surface` |
| `lib/ui/nsg_data_ui.dart` | `GetStatus`, `obx(...)`, `Get.context` | Load-more status, UI status binding, получение locale | `Status / async state`, `Shell services` | Частично. Locale можно вынести раньше в environment shell; `obx` требует legacy bridge | `Public surface` |
| `lib/nsg_data_provider.dart` | `getx.Get.snackbar`, `getx.SnackPosition.bottom` | Показ ошибок из provider/auth flow | `Shell services`, `UI-only conveniences` | Да, через message shell с default `GetX` implementation | `Compatibility-sensitive internal` |
| `lib/authorize/nsgPhoneLoginPage.dart` | `Get.back`, `Get.context` | Закрытие auth-страницы и доступ к context | `Navigation API`, `Shell services` | Да | `Public surface` |
| `lib/authorize/nsgPhoneLoginRegistrationPage.dart` | `Get.context` | Доступ к context на auth-странице | `Shell services` | Да | `Public surface` |
| `lib/authorize/nsgPhoneLoginVerificationPage.dart` | `Get.context` | Доступ к context на auth-странице | `Shell services` | Да | `Public surface` |
| `lib/nsg_data_request.dart` | `import 'package:get/get.dart'` | Похоже на import ради extension-методов типа `firstWhereOrNull`, а не ради runtime `Get.*` | `UI-only conveniences` | Да, это недорогая поздняя очистка | `Low-risk internal` |
| `lib/nsg_data_item.dart` | `import 'package:get/get.dart'`; комментарий с рекомендацией `Get.find` | Extension import и legacy-guidance в документации/комментариях | `UI-only conveniences` | Да | `Low-risk internal` |
| `lib/nsg_data.dart` | Переэкспорт `nsgBaseController`, `nsgDataController`, `nsgDataTableController`, `nsg_navigator`, `nsg_get_page`, `nsg_middleware`, `nsg_data_ui`, auth pages | Делает `GetX`-связанные классы частью public API пакета | Cross-cutting | Здесь не нужен новый интерфейс, но именно этот export shape объясняет риск совместимости | `Public surface` |

### Сводка по `nsg_data`

| Тип зависимости | Где сосредоточена | Комментарий |
| --- | --- | --- |
| `GetxController` / `StateMixin` / `GetStatus` | Controller layer и `nsg_data_ui` | Это самая глубокая архитектурная связка, потому что она задает и runtime state, и публичный паттерн наследования |
| `Get.*` navigation | `nsg_navigator.dart`, контроллеры, auth pages | Хороший первый seam-кандидат: можно обернуть без переписывания всех экранов приложений |
| `Get.context` | Контроллеры, auth pages, UI helpers | Переносить нужно аккуратно, потому что часть flow уже завязана на `Get` overlay/root navigator context |
| `Get.snackbar` | Provider layer | Это shell-зависимость, которая протекла в data layer |
| `GetPage` / `GetMiddleware` / `Get.parameters` | Navigator package | Очень чувствительно к bootstrap существующих приложений |

## `nsg_controls`

| Файл | Прямое использование `GetX` | Роль | Категория | Можно ли заменить интерфейсом | Поверхность |
| --- | --- | --- | --- | --- | --- |
| `lib/widgets/nsg_filter_chips_row.dart` | `Get.toNamed`, `Get.context` | Открытие selection form и использование глобального context для закрытия | `Navigation API`, `Shell services` | Да | `Public surface` |
| `lib/widgets/nsg_dialog_save_or_cancel.dart` | `Get.dialog`, `Get.back` | Жизненный цикл save/cancel dialog | `Shell services`, `Navigation API` | Да | `Public surface` |
| `lib/table/nsg_table.dart` | `Get.width`, `Get.dialog`, `Get.back`, `Get.locale` | Responsive layout, dialogs, close actions, locale-зависимый tooltip text | `UI-only conveniences`, `Shell services`, `Navigation API` | Да | `Public surface` |
| `lib/nsg_selection.dart` | `GetStatus`, `GetxController`, `StateMixin`, `obx` | Внутренний selection state controller и UI binding | `Status / async state`, `Controller contracts` | Частично. Нужен compatibility bridge, потому что UI использует `StateMixin`/`obx` | `Compatibility-sensitive internal` |
| `lib/nsg_listpage.dart` | `Get.width`, `Get.back` | Размеры list page и навигация | `UI-only conveniences`, `Navigation API` | Да | `Public surface` |
| `lib/nsg_data_controller_ui.dart` | `Get.context` | Получение locale для data-driven UI | `Shell services` | Да | `Public surface` |
| `lib/helpers.dart` | `Get.context` | Локализационный helper `tranControls` | `Shell services` | Да | `Public surface` |
| `lib/formfields/nsg_period_filter.dart` | `Get.dialog` | Period filter dialog | `Shell services` | Да | `Public surface` |
| `lib/file_picker/nsg_file_picker_table_controller.dart` | `Get.dialog`, `Get.back`, `Get.width`, `Get.height` | Жизненный цикл file picker dialog и sizing | `Shell services`, `Navigation API`, `UI-only conveniences` | Да | `Public surface` |
| `lib/file_picker/nsg_file_picker_provider.dart` | `Get.context`, `Get.snackbar` | Показ ошибок в file operations | `Shell services`, `UI-only conveniences` | Да | `Compatibility-sensitive internal` |
| `lib/file_picker/nsg_file_picker_controller.dart` | `Get.dialog`, `Get.back`, `Get.width`, `Get.height` | Жизненный цикл dialog и sizing в file picker controller | `Shell services`, `Navigation API`, `UI-only conveniences` | Да | `Public surface` |
| `lib/file_picker/nsg_file_picker.dart` | `Get.back`, `Get.dialog`, `Get.width`, `Get.height`, `Get.snackbar` | Modal behavior и user feedback file picker-а | `Shell services`, `Navigation API`, `UI-only conveniences` | Да | `Public surface` |
| `lib/widgets/nsg_snackbar.dart` | `Get.context` | Context по умолчанию для snackbar | `Shell services` | Да | `Public surface` |
| `lib/formfields/nsg_input.dart` | `Get.back`, `Get.toNamed` | Selection routing из form field | `Navigation API` | Да | `Public surface` |
| `lib/nsg_control_options.dart` | `Get.width` | Глобальные responsive-метрики | `UI-only conveniences` | Да | `Public surface` |
| `lib/nsg_reactive.dart` | `GetStatus` | Общие reactive helper types | `Status / async state` | Частично. Это нужно мигрировать после shell seams, сохранив backward mapping | `Public surface` |
| `lib/widgets/nsg_error_widget.dart` | `Get.dialog`, `Get.back` | Жизненный цикл error dialog | `Shell services`, `Navigation API` | Да | `Public surface` |
| `lib/file_picker/nsg_file_picker_gallery.dart` | `Get.height` | Размеры gallery | `UI-only conveniences` | Да | `Compatibility-sensitive internal` |
| `lib/nsg_progress_dialog.dart` | `Get.context` | Context по умолчанию и `rootNavigator.pop` | `Shell services` | Да | `Public surface` |
| `lib/widgets/nsg_expansion_panel.dart` | `Get.height` | Позиционирование overlay | `UI-only conveniences` | Да | `Compatibility-sensitive internal` |
| `lib/nsg_multi_selection.dart` | `Get.dialog`, `Get.back` | Жизненный цикл multi-selection dialog | `Shell services`, `Navigation API` | Да | `Public surface` |
| `lib/widgets/nsg_context_menu.dart` | `Get.width` | Позиционирование context menu | `UI-only conveniences` | Да | `Compatibility-sensitive internal` |
| `lib/widgets/nsg_image.dart` | `GetBuilder` | Контракт обновления виджета через `GetX` controller update IDs | `Controller contracts` | Частично. Позже надо заменить capability interface или bridge | `Public surface` |
| `lib/widgets/nsg_progressbar.dart` | `get_animations/OpacityAnimation` | Animation helper из семейства `GetX` пакетов | `UI-only conveniences` | Да | `Compatibility-sensitive internal` |
| `lib/nsg_controls.dart` | Переэкспорт `nsg_input`, `nsg_selection`, `nsg_table`, `file_picker`, `nsg_reactive`, widgets на helpers | Выносит `GetX`-связанное поведение в public API пакета | Cross-cutting | Здесь не нужен отдельный интерфейс, но этот export shape усиливает миграционную чувствительность | `Public surface` |
| `example/controls_examples/lib/**` | `GetMaterialApp`, `GetPage`, `Bindings`, `Get.put`, `Get.find`, screen metrics | Wiring demo app-а | `Example/demo code` | Не должно определять решение для package public contracts | `Example/demo code` |

### Сводка по `nsg_controls`

| Тип зависимости | Где сосредоточена | Комментарий |
| --- | --- | --- |
| `Get.dialog` / `Get.back` / `Get.toNamed` | Dialogs, file picker, inputs, list/table flows | Лучшие кандидаты для shell extraction с default `GetX` adapter |
| `Get.context` | Localization, snackbars, progress dialog helpers | Частая точка сбоев вне `GetMaterialApp`/overlay-managed apps |
| `Get.width` / `Get.height` / `Get.locale` | Tables, file picker, menus, layout helpers | Концептуально слабая связка, но call sites много |
| `GetBuilder` / `GetStatus` / `StateMixin` | `nsg_reactive.dart`, `nsg_selection.dart`, `nsg_image.dart` | Это уже граница между shell migration и более поздней controller/status migration |
| `get_animations` | `nsg_progressbar.dart` | Можно убирать поздно и с низким риском для совместимости |

## Граница example/demo code

`example`-приложения в обоих репозиториях действительно сильно используют `GetX`, но они не должны диктовать публичную архитектуру пакетов.

Из этого следует:

- example usage полезен как regression coverage
- example usage недостаточен как аргумент, чтобы оставлять `GetX`-тип в core contract
- порядок seam-этапов нужно выбирать по реальным exported library APIs, а не по текущему wiring demo app-а

## Выводы по inventory

1. Первый безопасный seam - shell/environment access: navigation, dialogs, snackbar/messages, context, locale, width/height, route params.
2. Второй seam - status/reactive state: `GetStatus`, `StateMixin`, `obx` и helper-ы вокруг них.
3. Самый рискованный seam - controller inheritance и update semantics: `GetxController`, `GetBuilder` и экспортируемые base classes, которые приложения уже могут использовать напрямую.
4. `GetPage` и `GetMiddleware` уже являются публичными и bootstrap-sensitive, поэтому их надо адаптировать, а не удалять.
5. Низкоуровневые `get` imports, используемые только ради convenience extensions, нужно чистить позже: они дешевы по изменению и почти ничего не дают для совместимости на ранних этапах.
