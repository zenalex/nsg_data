///Маркерный интерфейс параметров окна авторизации.
///
///Сами параметры и вся визуальная часть логина живут в пакете `nsg_login`
///(`NsgLoginParams implements NsgLoginParamsInterface`). Здесь остаётся только
///интерфейс, чтобы слой данных мог типизировать параметры, не зная о виджетах.
interface class NsgLoginParamsInterface {}
