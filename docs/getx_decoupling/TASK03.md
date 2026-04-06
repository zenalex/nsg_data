# TASK03 - Async Status And Reactive Contracts Without GetStatus

## Цель

Убрать из базовых пакетов прямую зависимость на `GetStatus`, `StateMixin` и `GetxController` там, где речь идет именно о модели состояния, а не о конкретной legacy-реализации.

Это второй критический seam после shell layer.

## Почему это важно

Пока в основе лежат:

- `GetStatus`
- `StateMixin`
- `GetxController`

невозможно сказать, что базовые пакеты действительно framework-agnostic.

Даже если навигация и dialogs уже вынесены, состояние все еще остается `GetX`-native.

## Что нужно получить

Собственный минимальный контракт async/reactive state, который:

- не зависит от `GetX`
- подходит и для legacy GetX layer, и для Riverpod layer
- допускает adapter-мост в старые `GetX`-контроллеры

## Что нужно спроектировать

### 1. Собственный status model

Нужен тип уровня:

- `idle`
- `loading`
- `success`
- `empty`
- `error`

Названия могут отличаться, но контракт должен быть package-owned, а не borrowed from `GetX`.

### 2. Reactive update contract

Нужно решить, как выражать:

- изменение статуса
- уведомление UI
- data refresh signaling

Не нужно копировать `GetX` API 1-в-1.

Нужно создать минимальный общий runtime-контракт, поверх которого legacy code можно адаптировать.

### 3. Mapping layer для GetX

Старые контроллеры должны уметь:

- принимать новый internal status
- маппить его на `GetStatus` для старого UI

Это важно для совместимости существующих приложений.

## Ограничение совместимости

Нельзя требовать от существующих приложений немедленно:

- заменить все `controller.obx(...)`
- убрать все `GetView`
- переписать все экраны под новый status type

Нужен transitional layer:

- core contracts уже без `GetX`
- legacy GetX UI все еще работает через адаптер

## Что нужно сделать

1. Спроектировать новый status contract.
2. Выделить reactive base abstractions там, где это необходимо.
3. Добавить compatibility mapping на сторону legacy controller-ов.
4. Перевести внутренние места пакетов с прямого `GetStatus` на новый internal contract.
5. Не ломать старые public UI usage patterns раньше времени.

## Что нужно документировать

Нужно создать:

- `status_contract.md`
- `legacy_getx_mapping.md`

### `status_contract.md`

Описывает новый async/status contract и его роль.

### `legacy_getx_mapping.md`

Описывает, как старые GetX controller-ы продолжают работать поверх новой внутренней модели.

## Acceptance Criteria

- Введен package-owned async/status contract.
- Есть понятный compatibility bridge на `GetStatus`.
- Существующие приложения не обязаны сразу переписывать все `obx`-экраны.
- Базовый слой состояния больше не зависит концептуально от `GetStatus` как от основного типа.
