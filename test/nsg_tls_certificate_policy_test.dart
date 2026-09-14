import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsg_data/nsg_data.dart';

/// Регресс на NSG-SOFT/futbolista-tasks#2000.
///
/// Сетевой слой на всех не-веб платформах отключал проверку TLS-сертификата:
/// в трёх местах стоял `badCertificateCallback = (...) => true` под одним лишь
/// условием `!kIsWeb`, без отладочного гарда. Релизные мобильные и десктопные
/// сборки принимали ЛЮБОЙ предъявленный сертификат — включая запросы
/// авторизации, где уходит токен.
///
/// Тест поднимает настоящий HTTPS-сервер на петле с САМОПОДПИСАННЫМ
/// сертификатом и ходит на него боевыми методами провайдера. На старом коде
/// «релизные» проверки зелёными быть не могут: запрос там проходит.
///
/// Сертификат выписан на CN=localhost / SAN 127.0.0.1 и действует до 2126 г.,
/// поэтому тест не протухнет: он падает из-за НЕИЗВЕСТНОГО УДОСТОВЕРИТЕЛЯ,
/// а не из-за срока или несовпадения имени.
const _selfSignedCert = '''
-----BEGIN CERTIFICATE-----
MIIDJzCCAg+gAwIBAgIUC+DnTisd1oibwqEz7LG6Ab7xpIYwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MDkwODEzMzAzNFoYDzIxMjYw
ODE1MTMzMDM0WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQDaCfq3FMpm8N1ZYsxoyDRimeVspBO97KSXQKByYZsT
XGwRpl6nTHXIOqgplIfa4O7SzRL8djfPNCtnhvB2ZGm4c83nJkfgwHTBX24vSEZ3
tbJd5KLbu8LfNL361lRvEOn812pqSxJGtT5lp5ISaAIH+R6wQ0o+pgDY1OKccRJE
Lj1FZY9ptLEFGjNfaAwiU/amk9AVtRtzG4HHu1/lEW4U9IUVzaBXreagKnQa98Rw
KeMQ1Te4+Px3lSICjDTiJL0OPSIMXb3RwX5YtEi3Gp/DB3eB06qXHLs4EOwdiQjd
1n0cwUYyo71ghsV8CKWRHc9AoTUBroVCDLZA1W/DxqinAgMBAAGjbzBtMB0GA1Ud
DgQWBBR4cXUCAfNaz7eXbg6rYezJ7fjtJDAfBgNVHSMEGDAWgBR4cXUCAfNaz7eX
bg6rYezJ7fjtJDAPBgNVHRMBAf8EBTADAQH/MBoGA1UdEQQTMBGCCWxvY2FsaG9z
dIcEfwAAATANBgkqhkiG9w0BAQsFAAOCAQEAeddoSUVmcqG4jfjgm3OVSbbCjNdQ
0GUYZ4v3eyUB2YD9LemN+ArzIPSQjYp/5/tAivTucpND5tz2eP8P8mppSZ5vfK3+
5j7e61chbbpifp+Cw+XulNrx/TaiJaNgDw9IvSeXZnRglcDQl0WDF+y0kzI7vm/M
9AsJnE8JDCktNHVQnHeGxPHlgtBdyXRCEU/T5bQGFoPwdSMbAnhPUG7m3NPsd3j6
L/130913+QwWmbGhXwn2YXAowhg8unmkFHgLVZc5hSUbm9ecgoThao31znLTXsf7
B48AgBHGQZ9n5Ci0PXnshYeNx9O1ltHrFcP7gel9OyS6Kx2e3t9/PtOm3Q==
-----END CERTIFICATE-----
''';

const _selfSignedKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDaCfq3FMpm8N1Z
YsxoyDRimeVspBO97KSXQKByYZsTXGwRpl6nTHXIOqgplIfa4O7SzRL8djfPNCtn
hvB2ZGm4c83nJkfgwHTBX24vSEZ3tbJd5KLbu8LfNL361lRvEOn812pqSxJGtT5l
p5ISaAIH+R6wQ0o+pgDY1OKccRJELj1FZY9ptLEFGjNfaAwiU/amk9AVtRtzG4HH
u1/lEW4U9IUVzaBXreagKnQa98RwKeMQ1Te4+Px3lSICjDTiJL0OPSIMXb3RwX5Y
tEi3Gp/DB3eB06qXHLs4EOwdiQjd1n0cwUYyo71ghsV8CKWRHc9AoTUBroVCDLZA
1W/DxqinAgMBAAECggEAE7l0uCc7VYCopYjDMR9wuGgaUcUDZtpc3An5Tx+hUGkQ
pbAak/aIw9T6mCMFqeP7TDqdDcBWtXnktfgxEfoXePDmSZOJoRKyp+Oi1h2AXR1P
cMsEKJidvQ91DZdiCqzJs258A/hH7k7rFssdSGj8S2MFRwYaAKeHysByF5uVqXEn
+DSpOeG4mLMtSmujwz7kcs2a08Q0meVYyHrLVGuTuOzaIZ6K0vLDaLfy7OdbfN7o
5rEg4mu7y9X+3DqZex1WHNMhyPYPU+TmP4hWLjp9fHXlHor9GuDDuBoMcmw+20Y2
cNlXcSv5I6o+NaGpQA7tVN/UqPDdXRfxSKhWP7qnUQKBgQD0pf65l9EGQmvMo5qz
avMCU75+lDSEP1ApUSaK2WMwygDRS4bG+2ooUsjB9tPcue8QWK7bbEAD4VkSfbqu
H0tWlgY8HvZg5ZWXNPCfDaijPSl7XUpOcZgtN7/KHUTlmBgF8vtOvaURTuZKhOxF
R6hveosEGD5YTJ6mdVv8tVEK7QKBgQDkJ+jjpJEkzD+LT2FNXWu723Pc1PBpOcFi
hGrP1yJx82MISZmXdf0r+R82yD2uW+FHEEO9wxhydaDXbsMspHGoWviT0t5/pCqL
NIWNr4Th/4SBWT2FsQYRqbUzT22t5qxI22zjV3wjzu0O7yvapHluO7dqp0cy8rmj
pWfv0KxLYwKBgQDVvjlgmR1MJLfeIIpGewg5XkUuffmsGUzF7FqKMQeSVsqEEUJ9
kqba+AjiPe44CFKvq2uJ1XfQbA/QMfzpp/nAem6UFFEZszwQ0XXw4JQXmpYlbApB
oslbqDtuMEhDd7B1cibSUqpnBtH5BU0P8l1cmGngd/XwW3C46gwmK5vUuQKBgQCz
Qrg0xARWSTRUHJZy1sfi3dX22EfcJUjQQwI5MusZZQWWaV2IJ2g3uJDR1hrAd+hU
kW7oFfWLWOh628f1t26lvHQ6kR/IYhAbN7UHUbSybLSLfLZd6GzAS/rWyb1/ORJ8
XAr9xKsA54BSj5CBRWEzPzApWC0U1qkM7tTvE6GLyQKBgQDXEc1/D4Np0Jw55Rw4
4QVdX1mDvxc5yGmdL9IBp8Dwsrcv9xAJuLG3KYzRMixrzPVA2J+NCqvUCTVfTRDb
QTSngI4LX6i8ymWTrpwJXN/ValgifHS9ywkSv1/vLyKMZBJnT/oXPWEvq40+pqwa
eLs0I47A5FC1QitWscsRqX7UrQ==
-----END PRIVATE KEY-----
''';

void main() {
  group('проверка TLS-сертификата', () {
    late HttpServer server;
    late NsgDataProvider provider;
    late String host;
    late String baseUrl;

    setUp(() async {
      final context = SecurityContext()
        ..useCertificateChainBytes(utf8.encode(_selfSignedCert))
        ..usePrivateKeyBytes(utf8.encode(_selfSignedKey));

      server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
      server.listen((HttpRequest request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        await request.response.close();
      });

      host = InternetAddress.loopbackIPv4.address;
      baseUrl = 'https://$host:${server.port}';
      provider = NsgDataProvider(
        applicationName: 'test_app',
        applicationVersion: '1.0.0',
        firebaseToken: '',
        availableServers: NsgServerParams({baseUrl: 'main'}, baseUrl),
      );
      provider.serverUri = baseUrl;
    });

    tearDown(() async {
      await server.close(force: true);
      // Статики общие на процесс — иначе послабление протечёт в соседний тест.
      NsgDataProvider.allowBadCertificateHosts.clear();
      NsgDataProvider.debugBuildOverride = null;
      NsgDataProvider.allowBadCertificateInDebug = true;
    });

    /// Отказ должен быть именно сертификатным, а не «сервер не поднялся».
    void expectCertificateRefusal(NsgApiException e) {
      final message = e.error.message ?? '';
      expect(message, matches(RegExp('handshake|certificate', caseSensitive: false)),
          reason: 'ждали отказ по сертификату, а получили: $message');
    }

    group('релизная сборка', () {
      setUp(() => NsgDataProvider.debugBuildOverride = false);

      test('baseRequest рвёт соединение с самоподписанным сертификатом', () async {
        // На СТАРОМ коде здесь возвращался {"ok":true} — сертификат принимался.
        try {
          final result = await provider.baseRequest(url: '$baseUrl/ping', method: 'GET');
          fail('самоподписанный сертификат приняли в релизе, ответ: $result');
        } on NsgApiException catch (e) {
          expectCertificateRefusal(e);
        }
      });

      test('baseRequestList рвёт соединение с самоподписанным сертификатом', () async {
        try {
          final result = await provider.baseRequestList(url: '$baseUrl/ping', method: 'GET');
          fail('самоподписанный сертификат приняли в релизе, ответ: $result');
        } on NsgApiException catch (e) {
          expectCertificateRefusal(e);
        }
      });

      test('imageRequest рвёт соединение с самоподписанным сертификатом', () async {
        // Третья копия блока жила именно здесь — без этого теста её пропустили бы.
        try {
          final Uint8List bytes = await provider.imageRequest(url: '$baseUrl/logo.png');
          fail('самоподписанный сертификат приняли в релизе, байт: ${bytes.length}');
        } on NsgApiException catch (e) {
          expectCertificateRefusal(e);
        }
      });

      test('хост из allowBadCertificateHosts по-прежнему пускают', () async {
        NsgDataProvider.allowBadCertificateHosts.add(host);

        final result = await provider.baseRequest(url: '$baseUrl/ping', method: 'GET');
        expect(result, {'ok': true},
            reason: 'стенд на самоподписанном сертификате остаётся рабочим — точечно');
      });

      test('послабление точечное: соседний хост не наследует доверие', () {
        NsgDataProvider.allowBadCertificateHosts.add(host);

        expect(NsgDataProvider.shouldAcceptBadCertificate(host, isDebugBuild: false), isTrue);
        expect(NsgDataProvider.shouldAcceptBadCertificate('data1.futbolista.me', isDebugBuild: false), isFalse,
            reason: 'боевой адрес проверяется в том же самом релизе');
      });
    });

    group('отладочная сборка', () {
      test('самоподписанный сертификат принимается — режим разработки сохранён', () async {
        NsgDataProvider.debugBuildOverride = true;

        final result = await provider.baseRequest(url: '$baseUrl/ping', method: 'GET');
        expect(result, {'ok': true});
      });

      test('allowBadCertificateInDebug=false включает проверку и в отладке', () async {
        NsgDataProvider.debugBuildOverride = true;
        NsgDataProvider.allowBadCertificateInDebug = false;

        try {
          final result = await provider.baseRequest(url: '$baseUrl/ping', method: 'GET');
          fail('проверку не включили, ответ: $result');
        } on NsgApiException catch (e) {
          expectCertificateRefusal(e);
        }
      });
    });
  });

  group('shouldAcceptBadCertificate — решение по хосту', () {
    tearDown(() {
      NsgDataProvider.allowBadCertificateHosts.clear();
      NsgDataProvider.debugBuildOverride = null;
      NsgDataProvider.allowBadCertificateInDebug = true;
    });

    test('релиз без списка — отказ (значение по умолчанию)', () {
      expect(NsgDataProvider.shouldAcceptBadCertificate('data1.futbolista.me', isDebugBuild: false), isFalse);
      expect(NsgDataProvider.shouldAcceptBadCertificate('test.futbolista.me', isDebugBuild: false), isFalse);
    });

    test('отладка без списка — принимаем', () {
      expect(NsgDataProvider.shouldAcceptBadCertificate('data1.futbolista.me', isDebugBuild: true), isTrue);
    });

    test('имя хоста сверяется без учёта регистра', () {
      NsgDataProvider.allowBadCertificateHosts.add('stand.local');

      expect(NsgDataProvider.shouldAcceptBadCertificate('STAND.local', isDebugBuild: false), isTrue);
      expect(NsgDataProvider.shouldAcceptBadCertificate('stand.local.evil.com', isDebugBuild: false), isFalse,
          reason: 'совпадение целиком, а не по префиксу');
    });

    test('список пуст по умолчанию — молчаливого доверия нет ни у кого', () {
      expect(NsgDataProvider.allowBadCertificateHosts, isEmpty);
    });
  });
}
