// Сужение полей ДОЧИТЫВАЕМЫХ объектов (#1383).
//
// Зачем: сужение основного объекта даёт немного - на списке матчей сам объект это 23%
// байт ответа, остальные 77% приезжают дочитанными ссылками. Сузить их можно точечной
// записью в neededFields ("teamHomeId.name"), сервер такую запись понимает.
//
// Здесь проверяется клиентская половина: по какому пути определяется тип референта и
// какие его поля считаются непрочитанными. Ошибка в эту сторону тихая и неприятная -
// поле, которое на самом деле пришло, помечается пустым, и экран получает defaultValue
// вместо данных. Поэтому отдельно закреплён случай, когда сужать нельзя: до типа ведёт
// ещё один путь дочитывания, по которому сервер пришлёт объект целиком.

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/models/nsg_server_params.dart';
import 'package:nsg_data/nsg_data.dart';

class RefPhoto extends NsgDataItem {
  static const nameId = 'id';
  static const namePath = 'path';
  static const nameSize = 'size';

  @override
  String get typeName => 'RefPhoto';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(namePath), primaryKey: false);
    addField(NsgDataIntField(nameSize), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => RefPhoto();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class RefTeam extends NsgDataItem {
  static const nameId = 'id';
  static const nameName = 'name';
  static const nameCity = 'city';
  static const namePhotoId = 'photoId';

  @override
  String get typeName => 'RefTeam';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataStringField(nameName), primaryKey: false);
    addField(NsgDataStringField(nameCity), primaryKey: false);
    addField(NsgDataReferenceField<RefPhoto>(namePhotoId), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => RefTeam();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

class RefMatch extends NsgDataItem {
  static const nameId = 'id';
  static const nameTeamHomeId = 'teamHomeId';
  static const nameTeamAwayId = 'teamAwayId';

  @override
  String get typeName => 'RefMatch';

  @override
  void initialize() {
    addField(NsgDataStringField(nameId), primaryKey: true);
    addField(NsgDataReferenceField<RefTeam>(nameTeamHomeId), primaryKey: false);
    addField(NsgDataReferenceField<RefTeam>(nameTeamAwayId), primaryKey: false);
  }

  @override
  NsgDataItem getNewObject() => RefMatch();

  @override
  String get id => getFieldValue(nameId).toString();
  @override
  set id(String value) => setFieldValue(nameId, value);
}

/// Доступ к приватному расчёту через реальный вызов разбора ответа был бы честнее, но
/// требует провайдера и сети. Поэтому проверяем через разбор готового тела ответа.
Future<List> parse(Map<String, dynamic> response, List<String> loadReference, NsgDataRequestParams filter) {
  final request = NsgDataRequest<RefMatch>();
  return request.loadDataAndReferences(response, loadReference, '', filter: filter);
}

Map<String, dynamic> responseWithTeams() => <String, dynamic>{
      '_results_': [
        {'id': 'M1', 'teamHomeId': 'T1', 'teamAwayId': 'T2'},
      ],
      'refTeam': [
        {'id': 'T1', 'name': 'Спартак'},
        {'id': 'T2', 'name': 'ЦСКА'},
      ],
    };

void main() {
  setUpAll(() {
    final provider = NsgDataProvider(
      applicationName: 'test',
      firebaseToken: '',
      applicationVersion: '1.0',
      availableServers: NsgServerParams(<String, String>{}, ''),
      newTableLogic: true,
    );
    for (final item in <NsgDataItem>[RefMatch(), RefTeam(), RefPhoto()]) {
      if (!NsgDataClient.client.isRegistered(item.runtimeType)) {
        NsgDataClient.client.registerDataItem(item, remoteProvider: provider);
      }
    }
  });

  group('поля дочитываемых объектов', () {
    test('точечное поле помечает остальные поля референта непрочитанными', () async {
      final filter = NsgDataRequestParams()..neededFields = ['id', 'teamHomeId', 'teamAwayId', 'teamHomeId.id', 'teamHomeId.name'];
      await parse(responseWithTeams(), ['teamHomeId'], filter);

      final team = NsgDataClient.client.getItemsFromCache(RefTeam, 'T1')! as RefTeam;
      expect(team.getFieldValue(RefTeam.nameName), 'Спартак');
      expect(team.fieldValues.emptyFields.contains(RefTeam.nameCity), isTrue,
          reason: 'city не запрашивали — обращение к нему должно быть видно, а не молча вернуть пустоту');
      expect(team.fieldValues.emptyFields.contains(RefTeam.nameName), isFalse);
      expect(team.fieldValues.emptyFields.contains(RefTeam.nameId), isFalse);
    });

    test('без точечных полей разметки нет — объект пришёл целиком', () async {
      final filter = NsgDataRequestParams()..neededFields = ['id', 'teamHomeId'];
      await parse(responseWithTeams(), ['teamHomeId'], filter);

      final team = NsgDataClient.client.getItemsFromCache(RefTeam, 'T2')! as RefTeam;
      expect(team.fieldValues.emptyFields, isEmpty);
    });

    test('второй путь к тому же типу без сужения отменяет разметку', () async {
      // teamHomeId сужен, teamAwayId — нет. Тип в ответе один, объекты приедут полными
      // по второму пути, и пометить их пустыми значило бы соврать.
      final filter = NsgDataRequestParams()..neededFields = ['id', 'teamHomeId', 'teamAwayId', 'teamHomeId.id', 'teamHomeId.name'];
      final response = <String, dynamic>{
        '_results_': [
          {'id': 'M3', 'teamHomeId': 'T3', 'teamAwayId': 'T4'},
        ],
        'refTeam': [
          {'id': 'T3', 'name': 'Зенит'},
          {'id': 'T4', 'name': 'Динамо'},
        ],
      };
      await parse(response, ['teamHomeId', 'teamAwayId'], filter);

      final team = NsgDataClient.client.getItemsFromCache(RefTeam, 'T3')! as RefTeam;
      expect(team.fieldValues.emptyFields, isEmpty);
    });

    test('путь в две ссылки разрешается до конечного типа', () async {
      final filter = NsgDataRequestParams()..neededFields = ['id', 'teamHomeId', 'teamHomeId.id', 'teamHomeId.photoId', 'teamHomeId.photoId.path'];
      final response = responseWithTeams();
      response['refPhoto'] = [
        {'id': 'P1', 'path': '/img/1.png'},
      ];
      await parse(response, ['teamHomeId', 'teamHomeId.photoId'], filter);

      final photo = NsgDataClient.client.getItemsFromCache(RefPhoto, 'P1')! as RefPhoto;
      expect(photo.getFieldValue(RefPhoto.namePath), '/img/1.png');
      expect(photo.fieldValues.emptyFields.contains(RefPhoto.nameSize), isTrue,
          reason: 'size не запрашивали ни по одному пути');
    });
  });
}
