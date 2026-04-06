# TASK05 - Introduce Riverpod Adapters Without Breaking GetX Apps

## Цель

После появления shell interfaces, status contract и controller capabilities добавить вторую реализацию на `Riverpod`, не ломая старые `GetX`-приложения.

Это ключевой момент всей программы: не заменить одно другим, а сделать двустековую базу.

## Что значит "без ломки существующих приложений"

После выпуска этой фазы:

- старые приложения на `GetX` должны собираться и работать как раньше
- новые приложения или новые flow должны иметь возможность использовать `Riverpod`
- приложение не должно быть вынуждено мигрировать все экраны сразу, чтобы обновить пакеты

## Что нужно сделать

### 1. Определить, какие интерфейсы реально реализуются на Riverpod

Нужно выбрать only meaningful contracts.

Не надо механически повторять весь legacy controller API.

### 2. Добавить Riverpod adapter layer

Например:

- adapters вокруг `Notifier` / `AutoDisposeNotifier`
- bindings между state objects и capability interfaces
- при необходимости bridge objects для controls package

### 3. Проверить `nsg_controls` на двустековую совместимость

Хотя бы несколько базовых controls должны уметь работать:

- с legacy GetX implementation
- с Riverpod-based implementation

### 4. Не заставлять существующие приложения менять bootstrap

Riverpod integration должна быть opt-in.

Если приложение ничего не меняет, оно должно оставаться на default GetX path.

## Что нужно валидировать

Минимум на двух сценариях:

- simple scalar edit flow
- list/table related flow

Лучше через небольшой pilot app или existing example flow.

## Что нужно документировать

Нужно создать:

- `riverpod_adapter_strategy.md`
- `app_migration_minimal_steps.md`

### `riverpod_adapter_strategy.md`

Описывает, какие interface contracts реализованы через Riverpod и где проходят intentional boundaries.

### `app_migration_minimal_steps.md`

Описывает, какие минимальные шаги нужно сделать приложению, если оно хочет начать использовать новый Riverpod path.

Этот документ особенно важен: он должен показывать, что переход может быть постепенным.

## Acceptance Criteria

- Есть работающий Riverpod adapter layer поверх новых контрактов.
- Старые GetX apps остаются рабочими без обязательной массовой миграции.
- Есть документированный minimal migration path для приложений.
- Базовые controls могут использовать оба стека хотя бы в representative сценариях.
