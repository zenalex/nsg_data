///Класс, хранящий доступные для подключения адреса серверов, разделенные на группы
///Например, рабочий, тестовый
///И мотоды для работы с ними
class NsgServerParams {
  NsgServerParams(this.serverGroups, this.currentServer);

  ///Map - адрес сервера - имя группы (main/test etc)
  Map<String, String> serverGroups;
  String currentServer;

  ///Map - группа серверов / токен пользователя
  ///для того, чтобы сохранять на клиенте токены сразу для нескольких серверов
  Map<String, String> groupToken = {};

  ///Производить автоматический выбор сервера из списка группы, если сейрер по умолчанию не доступен
  bool autoSelectServer = true;

  ///Запрашивать список доступных серверов у NsgAddressServer
  bool requestServerParams = true;

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
