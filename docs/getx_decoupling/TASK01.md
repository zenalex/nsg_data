# TASK01 - Dependency Audit And Compatibility Boundary Map

## Цель

Построить полную карту прямых зависимостей `nsg_data` и `nsg_controls` от `GetX`, а также разделить их на типы, чтобы дальше выносить их не хаотично, а по seam-уровням.

Это обязательный нулевой шаг. Без него есть риск начать "выносить GetX" в неправильном порядке и сломать совместимость.

## Главный критерий этапа

После завершения этого этапа должно быть понятно:

- какие зависимости относятся к shell/navigation/UI infrastructure
- какие зависимости относятся к status/reactivity
- какие относятся к controller API
- какие сидят только в примерах/example
- какие опасны для совместимости приложений

## Что нужно зафиксировать

### 1. Прямые зависимости `nsg_data` от `GetX`

Нужно собрать реестр:

- `Get.find`
- `Get.back`
- `Get.toNamed`
- `Get.offAndToNamed`
- `Get.currentRoute`
- `Get.parameters`
- `Get.context`
- `GetStatus`
- `StateMixin`
- `GetxController`

Для каждого использования указать:

- файл
- роль использования
- можно ли заменить интерфейсом
- является ли это public surface или только внутренней реализацией

### 2. Прямые зависимости `nsg_controls` от `GetX`

Нужно собрать реестр:

- screen metrics (`Get.width`, `Get.height`)
- locale/context (`Get.context`, `Get.locale`)
- dialogs/snackbar
- popup/navigation
- status/controller coupling

### 3. Совместимые seam-категории

Все найденные места нужно разложить минимум по таким категориям:

- Shell services
- Status / async state
- Navigation API
- Controller contracts
- UI-only conveniences
- Example/demo code

## Что должно быть создано

Нужно создать документы:

- `dependency_inventory.md`
- `compatibility_boundaries.md`
- `migration_risk_map.md`

### `dependency_inventory.md`

Должен содержать структурированный список мест, где пакеты напрямую зависят от `GetX`.

### `compatibility_boundaries.md`

Должен описывать, какие seam-и нужно вводить первыми, чтобы не ломать старые приложения.

### `migration_risk_map.md`

Должен отдельно выделять:

- high-risk public API точки
- medium-risk internal API точки
- low-risk internal convenience точки

## Очень важное ограничение

На этом этапе нельзя:

- массово менять код
- удалять `GetX`
- переименовывать публичные классы
- ломать существующие точки интеграции приложений

Этап purely analytical + design-oriented.

## Acceptance Criteria

- Есть полный inventory прямых `GetX`-зависимостей в двух пакетах.
- Понятно, какие изменения могут пройти без изменений в приложениях, а какие нет.
- Есть приоритизированный seam-порядок для следующих этапов.
- Есть явная фиксация того, что example/demo code не должен диктовать public API решение.
