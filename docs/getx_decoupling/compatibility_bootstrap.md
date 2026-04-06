# Compatibility Bootstrap

## Главный принцип

Обновление `nsg_data` и `nsg_controls` после `TASK02` не должно требовать от существующих `GetX`-приложений немедленного переписывания bootstrap.

Именно поэтому shell layer реализован через package-level default adapters, а не через обязательную ручную регистрацию.

## Почему старые приложения продолжают работать

После обновления пакетов старое приложение по-прежнему может:

- использовать `GetMaterialApp`
- использовать `GetPage`
- использовать существующие navigation/dialog flows
- не вызывать никакой дополнительный setup-код

Это возможно потому, что:

- `NsgShell` уже инициализирован default `GetX` adapters
- внутренние вызовы пакетов больше идут в `NsgShell.*`, а не напрямую в `Get.*`
- сами default adapters делегируют обратно в `GetX`

То есть runtime behavior сохраняется, но архитектурная привязка смещается из call sites в adapter layer.

## Что именно является default bootstrap

По умолчанию используется следующая связка:

- `NsgShell.navigation = NsgGetXNavigationShell()`
- `NsgShell.dialog = NsgGetXDialogShell()`
- `NsgShell.message = NsgGetXMessageShell()`
- `NsgShell.environment = NsgGetXEnvironmentShell()`

Эта конфигурация выставляется автоматически внутри пакета и не требует действий со стороны приложения.

## Когда приложение может захотеть вмешаться в bootstrap

Новый bootstrap нужен только если приложение осознанно хочет:

- подменить navigation shell
- подменить dialog shell
- подменить message shell
- подменить environment shell

То есть bootstrap change теперь опционален и нужен только для opt-in сценариев, а не для обычного обновления пакетов.

## Точка расширения

Для подмены реализаций предусмотрен:

- `NsgShell.configure(...)`

А для возврата к default поведению:

- `NsgShell.resetToDefaults()`

## Пример совместимого будущего bootstrap

Ниже пример именно opt-in сценария, а не обязательного шага для legacy apps:

```dart
void main() {
  NsgShell.configure(
    navigation: MyNavigationShell(),
    dialog: MyDialogShell(),
    message: MyMessageShell(),
    environment: MyEnvironmentShell(),
  );

  runApp(const MyApp());
}
```

Если приложение этого не делает, оно продолжает работать через default `GetX` adapters.

## Что это дает для миграции

Такой подход позволяет:

- сначала убрать жесткую зависимость внутренних пакетов от `Get.*`
- не ломать старые приложения на обновлении
- позже добавить вторую реализацию без переписывания всего API сразу

Это и есть нужный compatibility-first rollout.

## Что этот этап специально не требует от приложений

На этом этапе приложения не обязаны:

- менять `GetMaterialApp`
- переписывать все routes
- убирать `Bindings`
- переписывать контроллеры
- мигрировать все экраны на новый state management

Если бы это требовалось, значит shell seam был бы реализован слишком агрессивно и нарушал бы главную цель программы.

## Связь с дальнейшими этапами

`TASK02` создает safe seam для shell/environment зависимостей.

После этого можно переходить к:

- `TASK03`: status/reactive contract
- `TASK04`: small controller capability interfaces

Но уже без необходимости держать shell-доступ размазанным по `Get.*` call sites во всех пакетах.
