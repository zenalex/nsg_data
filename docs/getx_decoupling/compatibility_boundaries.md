# Границы совместимости

## Главное правило

Миграция должна сохранять возможность для существующих `GetX`-приложений обновить `nsg_data` и `nsg_controls`:

- без изменений в приложении
- либо с очень небольшими изменениями на bootstrap-уровне

Все остальное в этом документе выводится из этого правила.

## Карта границ

## 1. Граница shell и environment

Это самый безопасный первый seam.

Сюда входят:

- навигационные действия вроде `back`, `toNamed`, `offAndToNamed`
- dialogs и modal presentation
- snackbar/message presentation
- доступ к текущему context
- получение locale
- screen metrics вроде width и height
- route params и current route

Почему это безопасно выносить первым:

- эти операции уже по своей природе сервисные
- их можно спрятать за интерфейсами, не заставляя приложения сразу уходить с `GetMaterialApp`
- default `GetX` adapters могут сохранить текущее runtime behavior

Как должна выглядеть совместимая реализация:

- package-owned interfaces во framework-agnostic слое
- default `GetX` implementation, выбираемая автоматически
- optional override point для будущего `Riverpod` или custom shell

Чего нельзя делать на этом этапе:

- заставлять каждое приложение заменять `GetMaterialApp`
- заставлять каждое приложение сразу руками регистрировать adapters
- убирать `NsgNavigator`, `NsgGetPage` или `NsgMiddleware` до появления adapter-слоя

## 2. Граница status и reactive state

Это второй seam, и он должен идти только после shell extraction.

Сюда входят:

- `GetStatus`
- `StateMixin`
- `obx`
- helper-ы для распространения статуса
- внутренняя семантика `loading/success/error/empty`

Почему это не первый seam:

- эти типы участвуют и во внутренней логике, и в публичном UI-поведении
- слишком ранняя замена сломает `obx`-экраны и controller flows

Как должна выглядеть совместимая реализация:

- новая package-owned status model
- mapping layer между package status и legacy `GetStatus`
- legacy `GetX` UI patterns продолжают работать во время перехода

Чего нельзя делать на этом этапе:

- заставлять все приложения переписывать `controller.obx(...)`
- убирать `StateMixin` из экспортируемых legacy controllers без bridge support
- делать `Riverpod` единственным поддерживаемым runtime path

## 3. Граница controller contracts

Это самый рискованный seam, и его нужно отложить до стабилизации shell и status seams.

Сюда входят:

- наследование от `GetxController`
- `GetBuilder`-based rebuild semantics
- экспортируемые base controller classes, которые приложения могут использовать напрямую
- capability expectations, уже вшитые в controls/widgets

Почему риск высокий:

- существующие приложения могут наследоваться от `NsgBaseController` и связанных классов
- controls уже предполагают конкретные controller methods, update timing и status behavior
- прямая замена отдаст волну правок по множеству экранов

Как должна выглядеть совместимая реализация:

- ввести маленькие capability interfaces вместо одного нового монолитного controller
- сохранить legacy `GetX` base classes как adapter-backed implementations
- дать controls зависеть от capabilities, а не от concrete `GetX` bases

Чего нельзя делать на этом этапе:

- удалять или переименовывать legacy base controllers
- требовать от приложений переписать все контроллеры до обновления пакета
- менять `GetBuilder`/legacy update semantics без replacement contracts

## 4. Граница example/demo code

Example code - это потребитель, а не владелец архитектурного решения.

Это значит:

- example-приложения нужно обновлять после появления seam-слоев
- `GetX`-паттерны, живущие только в example, не должны блокировать очистку core contracts
- example regressions полезны как сигнал, но не являются достаточной причиной держать `GetX` в public core APIs

## Границы public API, которые должны оставаться стабильными на ранних этапах

Следующие поверхности слишком чувствительны к совместимости, чтобы ломать их в `TASK02` и `TASK03`:

- экспортируемые controller classes в `nsg_data`
- `NsgNavigator`
- `NsgGetPage`
- `NsgMiddleware`
- controls, которые сами открывают dialogs или routes, включая input selection и file picker flows
- localization helpers, которые сейчас падают обратно на `Get.context`
- snackbar/progress helpers с неявным использованием глобального context

Их нужно внутренне перенаправить на новые контракты, а не удалять.

## Упорядоченный seam-план

Безопасная последовательность такая:

1. Провести аудит и классификацию прямых `GetX`-зависимостей.
2. Ввести shell/environment interfaces с default `GetX` adapters.
3. Перевести внутренние shell-вызовы на новые интерфейсы, сохранив legacy entrypoints.
4. Ввести package-owned async/status contract с legacy `GetStatus` mapping.
5. Разделить controller expectations на маленькие capability interfaces.
6. Добавить `Riverpod` implementations как второй стек, а не как принудительную замену.
7. Только после стабилизации начинать депрекейтить прямые `GetX` public touchpoints.

## Граница default behavior

Обратная совместимость зависит от того, сохраняется ли поведение по умолчанию, когда приложение после обновления пакета не делает вообще ничего.

Значит:

- default shell implementation все еще должна использовать `GetX`
- legacy controllers должны продолжать работать без дополнительной регистрации
- приложения должны иметь возможность постепенно подключать custom implementations

Если обновление пакетов требует немедленных ручных bootstrap-изменений в каждом приложении, значит миграция проваливает главный критерий совместимости.

## Рекомендации по следующим задачам

### Для `TASK02`

- выделить `NsgNavigationShell`, `NsgDialogShell`, `NsgMessageShell`, `NsgEnvironmentShell`
- сохранить package-level default adapter на базе `GetX`
- внутренне перевести `Get.back`, `Get.dialog`, `Get.snackbar`, `Get.width`, `Get.height`, `Get.locale`, `Get.context`, `Get.currentRoute` и `Get.parameters` на новый слой
- пока не трогать controller inheritance, если это не требуется строго для wiring

### Для `TASK03`

- определить package-owned status values
- добавить compatibility mapper для `GetStatus`
- сохранить legacy `obx`-style flows на время перехода
- держать status bridge внутри legacy controllers, пока controls еще зависят от него напрямую

### Для `TASK04`

- увести controls от concrete `GetX` base classes к capability contracts
- сохранить legacy controller classes как доступные adapted implementations

## Финальное boundary-решение

Миграция должна трактовать `GetX` как:

- default runtime adapter в краткосрочной перспективе
- legacy-compatible implementation в среднесрочной перспективе
- optional implementation в долгосрочной перспективе

И не должна трактовать его как:

- единственную внутреннюю модель shell access
- единственную status model
- единственный controller contract
- bootstrap prerequisite для всех будущих приложений
