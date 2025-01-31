///Класс, хранящий доступные для подключения адреса серверов, разделенные на группы
///Например, рабочий, тестовый
///И мотоды для работы с ними
class NsgServerParams {
  NsgServerParams(this.serverGroups, this.currentServer, {this.controlServers = const []});

  ///Список управляющих серверов. Используется для запроса адресов актуальных серверов
  List<String> controlServers;

  ///Map - адрес сервера - имя группы (main/test etc)
  Map<String, String> serverGroups;
  String currentServer;

  ///Map - группа серверов / токен пользователя
  ///для того, чтобы сохранять на клиенте токены сразу для нескольких серверов
  Map<String, String> groupToken = {};

  ///Проверяет, содержится ли адрес сервера в списке доступных серверов
  bool contains(String name) {
    return serverGroups[name] != null;
  }

  ///Проверяет соответствие имени uheggs и адреса сервера
  bool serverIs(String name) {
    return name == serverGroups[currentServer];
  }

  ///Вернуть имя группы серверов по адресу
  String groupNameByAddress(String serverAddress) {
    return serverGroups[serverAddress] ?? '';
  }
}
