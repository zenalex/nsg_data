# Карта миграционных рисков

## Модель риска

- `High`: с высокой вероятностью ломает существующие приложения при прямом изменении
- `Medium`: в основном внутреннее место, но уже связанное с видимым поведением или package integration points
- `Low`: зависимость уровня convenience, которую можно убирать позже с минимальным риском для совместимости

## Высокий риск

| Зона | Пакет | Файлы / поверхность | Почему риск высокий | Безопасная стратегия |
| --- | --- | --- | --- | --- |
| Legacy controller inheritance | `nsg_data` | `lib/controllers/nsgBaseController.dart`, `lib/controllers/nsgDataController.dart`, `lib/controllers/nsgDataTableController.dart` | Существующие приложения могут напрямую наследоваться от этих контроллеров. Кроме того, эти классы уже выносят `GetxController`, `StateMixin` и `GetStatus` в app code. | Сохранить классы, увести внутренности за package-owned contracts, добавлять adapters вместо прямой замены типов |
| Public navigation facade | `nsg_data` | `lib/navigator/nsg_navigator.dart` | Это хороший shell extraction candidate, но он уже часть public surface и, вероятно, используется приложениями напрямую. | По возможности сохранить API shape и делегировать внутренности на новый navigation shell |
| Route registration contracts | `nsg_data` | `lib/navigator/nsg_get_page.dart`, `lib/navigator/nsg_middleware.dart` | Приложения уже могут зависеть от поведения `GetPage`, `GetMiddleware` и `Get.parameters` в bootstrap. | Ввести compatibility wrappers и default adapter; не удалять эти типы на раннем этапе |
| Global context dependence | `nsg_data`, `nsg_controls` | Controllers, auth pages, `helpers.dart`, `nsg_progress_dialog.dart`, `nsg_snackbar.dart`, UI locale helpers | Многие flow неявно предполагают валидный `Get.context` от `GetMaterialApp` overlay/root navigator. Ошибочная миграция даст null или wrong-context failures. | Ввести environment shell с default `GetX` fallback и переносить call sites постепенно |
| Dialog and route flows inside controls | `nsg_controls` | `nsg_input.dart`, `nsg_filter_chips_row.dart`, `nsg_dialog_save_or_cancel.dart`, `nsg_table.dart`, `nsg_multi_selection.dart`, file picker files | Сейчас controls сами владеют navigation/dialog behavior. Если резко поменять shell contract, множество пользовательских flow перестанет работать. | Сначала ввести navigation/dialog shell и сохранить default `GetX` behavior |
| Public status model | `nsg_data`, `nsg_controls` | `GetStatus` usage в controllers, `nsg_data_ui.dart`, `nsg_reactive.dart`, `nsg_selection.dart` | `GetStatus` используется так, как будто это package-native type. Экраны и виджеты уже могут зависеть от его семантики. | Сначала добавить package-owned status contract и явный legacy mapping, и только потом менять внутреннюю реализацию |
| Rebuild semantics tied to `GetX` | `nsg_controls` | `nsg_image.dart`, `nsg_selection.dart`, части table/UI с `GetBuilder` или `obx` | Проблема не только в названиях типов, но и в update timing и rebuild triggers. | Отложить до controller capability stage и сохранять legacy bridge во время rollout |

## Средний риск

| Зона | Пакет | Файлы / поверхность | Почему риск средний | Безопасная стратегия |
| --- | --- | --- | --- | --- |
| Provider-level snackbar calls | `nsg_data`, `nsg_controls` | `nsg_data_provider.dart`, `nsg_file_picker_provider.dart`, `nsg_file_picker.dart` | Это внутренняя реализация, но она видима пользователю и завязана на overlay/context assumptions. | Перевести на message shell после появления shell interfaces |
| Locale lookup through `Get.context` or `Get.locale` | `nsg_data`, `nsg_controls` | `nsg_data_ui.dart`, `nsg_data_controller_ui.dart`, `helpers.dart`, `nsg_table.dart` | Абстрагируется сравнительно легко, но ошибка проявится как неправильная локализация или runtime assertion. | Пустить через environment shell и сохранить fallback behavior |
| Screen metrics via `Get.width` and `Get.height` | `nsg_controls` | `nsg_table.dart`, `nsg_listpage.dart`, file picker widgets, context menu, expansion panel, `nsg_control_options.dart` | Концептуально заменить просто, но call sites много и возможны тонкие layout regressions. | Ввести viewport/environment shell и мигрировать постепенно |
| Mixed navigator usage | `nsg_controls` | `nsg_filter_chips_row.dart`, `nsg_progress_dialog.dart` | В отдельных местах уже смешаны `Get` и `Navigator.pop`, что может скрывать stack assumptions. | Сначала нормализовать через dialog/navigation shell |
| Общая зависимость на pre-stable `GetX` | `nsg_data`, `nsg_controls` | `pubspec.yaml` в обоих пакетах | Version mismatch между пакетами уже снят, но поведенческие изменения внутри release-candidate линии все еще могут протечь в adapters и тесты. | Держать adapter contracts узкими и явно проверять общее default behavior |
| Public exports that re-expose coupled files | `nsg_data`, `nsg_controls` | `lib/nsg_data.dart`, `lib/nsg_controls.dart` | Сами по себе эти exports не опасны, но они увеличивают blast radius любого breaking change. | Не трогать export shape на ранних этапах; сначала внутренняя делегация |

## Низкий риск

| Зона | Пакет | Файлы / поверхность | Почему риск низкий | Безопасная стратегия |
| --- | --- | --- | --- | --- |
| Convenience imports from `get.dart` | `nsg_data`, `nsg_controls` | `nsg_data_request.dart`, `nsg_data_item.dart` и несколько controls-файлов с неиспользуемыми `get` imports | Похоже, что они не определяют app-facing runtime behavior. | Позже заменить на package-local helpers или стандартные collection extensions |
| `get_animations` helper | `nsg_controls` | `widgets/nsg_progressbar.dart` | Animation helper не является core contract и может быть заменен почти без риска для совместимости. | Убирать после стабилизации более важных seam-слоев |
| Comment/docs mentions of `Get.find` | `nsg_data` | `nsg_data_item.dart` и похожие legacy comments | Это долг документации, а не runtime coupling. | Обновить, когда появится устойчивая replacement-guidance |
| Example application wiring | `nsg_controls` example и `nsg_data` example | Example-only `GetMaterialApp`, `Bindings`, `Get.put`, `Get.find` | Полезно как smoke testing, но не входит в published package contract. | Поддерживать examples рабочими, но не давать им диктовать архитектуру пакета |

## Приоритизация риска

Порядок миграции должен следовать не числу call sites, а логике сдерживания риска.

Рекомендуемый порядок:

1. Shell seams с высокой ценностью и низкой вероятностью массовой ломки.
2. Status contract с legacy mapping.
3. Controller capabilities и decoupling rebuild contract.
4. Очистка convenience imports и низкоуровневых `GetX` helpers.

## Красные линии

Следующие изменения слишком рискованны до более поздних фаз:

- удалять `GetX`-based controller base classes из public package surface
- заставлять все приложения заменять `GetMaterialApp`
- делать bootstrap registration обязательной для default runtime path
- удалять `NsgNavigator`, `NsgGetPage` или `NsgMiddleware` до появления compatible delegates
- требовать немедленного переписывания `obx`-based screens

## Итоговое решение

Если возникает конфликт между архитектурной чистотой и совместимостью:

- сначала сохраняем legacy app behavior
- потом вводим seam
- депрекейт делаем только после стабилизации и `GetX`, и `Riverpod` paths

Эта программа считается успешной только в том случае, если старые приложения продолжают работать, пока пакеты постепенно перестают считать `GetX` единственной внутренней архитектурой.
