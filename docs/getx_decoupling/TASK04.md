# TASK04 - Small Controller Interfaces Instead Of Concrete GetX Base Classes

## Цель

Разделить нынешний монолитный controller-мир на маленькие интерфейсные контракты, чтобы:

- `nsg_controls` зависел от capabilities, а не от concrete GetX base classes
- `GetX` и `Riverpod` могли реализовывать одинаковые контракты
- существующие legacy контроллеры можно было сохранить как адаптированную реализацию

## Главный принцип

Не создавать один "универсальный новый controller interface" на все случаи.

Нужны маленькие, узкие, composable контракты.

## Примерные группы контрактов

Набор нужно уточнить по результатам `TASK01`, но ожидаются контракты такого уровня:

- list loading
- item selection
- edit/draft handling
- validation
- command actions
- table rows handling
- filtering/sorting
- navigation-aware actions, если совсем необходимо

## Что нужно сделать

### 1. Определить capability interfaces

Например, условно:

- `NsgListReadable<T>`
- `NsgSelectable<T>`
- `NsgEditable<T>`
- `NsgTableEditable<T>`
- `NsgFilterable`
- `NsgRefreshable`

Названия могут быть другими, но важно именно capability-based разбиение.

### 2. Привязать `nsg_controls` к интерфейсам

Новые или обновленные базовые контролы должны требовать не `NsgBaseController`, а нужный capability contract там, где это возможно.

### 3. Сохранить backward compatibility

Существующие `GetX`-контроллеры должны:

- либо прямо реализовывать новые интерфейсы
- либо предоставляться через adapter layer

Так, чтобы старые приложения не были обязаны переписывать свой контроллерный слой одномоментно.

### 4. Подготовить почву для Riverpod

Нужно отдельно зафиксировать, какие capability contracts действительно разумно реализовать поверх Riverpod notifiers, а какие лучше не делать 1-в-1.

## Особый фокус для `nsg_controls`

Сначала нужно выбрать 2-3 наиболее важные точки внедрения интерфейсов:

- `NsgInput`
- `NsgTable`
- selection/filter related widgets

Не надо пытаться перевести на capability contracts все controls за один шаг.

## Что нужно документировать

Нужно создать:

- `controller_capabilities.md`
- `control_integration_points.md`

### `controller_capabilities.md`

Описывает набор capability interfaces и их ответственность.

### `control_integration_points.md`

Описывает, какие контролы переходят на интерфейсы первыми и почему.

## Acceptance Criteria

- Есть набор small controller interfaces.
- Появился путь, при котором `nsg_controls` может работать не только с concrete GetX base classes.
- Legacy GetX controllers остаются рабочими через interface implementation или adapters.
- Никакое существующее приложение не вынуждено в этом этапе массово переписывать свои контроллеры.
