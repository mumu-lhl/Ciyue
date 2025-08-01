import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:talker_dio_logger/talker_dio_logger.dart";

import "app_globals.dart" show talker;

class AppHttp {
  static final Dio dio = _build();

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        contentType: "application/json",
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(
      TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(
          printRequestData: kDebugMode,
          printResponseData: false,
          printRequestHeaders: false,
          printResponseHeaders: false,
          printErrorData: true,
        ),
      ),
    );

    return dio;
  }

  static Future<Response<dynamic>> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return dio.get(
      url,
      queryParameters: query,
      options: headers != null ? Options(headers: headers) : null,
      cancelToken: cancelToken,
    );
  }

  static Future<Response<dynamic>> post(
    String url, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return dio.post(
      url,
      data: data,
      queryParameters: query,
      options: headers != null ? Options(headers: headers) : null,
      cancelToken: cancelToken,
    );
  }

  static Future<Response<dynamic>> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return dio.delete(
      url,
      data: data,
      queryParameters: query,
      options: headers != null ? Options(headers: headers) : null,
      cancelToken: cancelToken,
    );
  }
}
