///Класс, хранящий доступные для подключения адреса серверов, разделенные на группы
///Например, рабочий, тестовый
///И мотоды для работы с ними
class NsgServerParams {
  NsgServerParams(this.serverGroups, this.currentServer);

  ///Map - адрес сервера - имя
  Map<String, String> serverGroups;
  String currentServer;

  ///Проверяет, содержится ли имя сервера в списке доступных серверов
  bool contains(String name) {
    return serverGroups[name] != null;
  }

  ///Проверяет соответствие имени и адреса сервера
  bool serverIs(String name) {
    return name == serverGroups[currentServer];
  }
}
