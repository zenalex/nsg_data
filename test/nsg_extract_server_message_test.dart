import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data_provider.dart';

/// Жалоба организаторов 04.08.2026: при регистрации команд показывалось
/// «400 ||| Internet connection error», хотя связь была в порядке — сервер
/// ответил 400 с конкретной причиной, а клиент её выбрасывал.
///
/// Корень: у DioException с ответом сервера `error` == null, тело лежит в
/// `response.data`. Прежний код брал `e.error?.toString() ?? 'Internet
/// connection error'` и всегда попадал в фолбэк.
void main() {
  group('nsgExtractServerMessage', () {
    test('обычный ответ сервера с message', () {
      expect(nsgExtractServerMessage({'message': 'Команда уже зарегистрирована'}),
          'Команда уже зарегистрирована');
    });

    test('другие написания ключа — сервер отвечает по-разному', () {
      expect(nsgExtractServerMessage({'Message': 'A'}), 'A');
      expect(nsgExtractServerMessage({'error': 'B'}), 'B');
      expect(nsgExtractServerMessage({'Error': 'C'}), 'C');
      expect(nsgExtractServerMessage({'error_description': 'D'}), 'D');
      expect(nsgExtractServerMessage({'title': 'E'}), 'E');
    });

    test('приоритет — message раньше остальных', () {
      expect(nsgExtractServerMessage({'title': 'поздний', 'message': 'ранний'}), 'ранний');
    });

    test('тело — простая строка', () {
      expect(nsgExtractServerMessage('Registration is closed'), 'Registration is closed');
    });

    test('пустое и бессодержательное → null, чтобы сработал прежний фолбэк', () {
      expect(nsgExtractServerMessage(null), isNull);
      expect(nsgExtractServerMessage(''), isNull);
      expect(nsgExtractServerMessage('   '), isNull);
      expect(nsgExtractServerMessage({}), isNull);
      expect(nsgExtractServerMessage({'message': '   '}), isNull);
      expect(nsgExtractServerMessage({'unknown': 'x'}), isNull);
    });

    test('не строковые значения не подхватываются', () {
      expect(nsgExtractServerMessage({'message': 42}), isNull);
      expect(nsgExtractServerMessage({'message': null}), isNull);
    });

    test('строка обрезается по краям', () {
      expect(nsgExtractServerMessage({'message': '  есть  '}), 'есть');
    });
  });
}
