import 'package:dio/dio.dart';

class NsgApiError {
  NsgApiError({this.code, this.message, this.errorType});
  final DioErrorType? errorType;
  final int? code;
  final String? message;
}
