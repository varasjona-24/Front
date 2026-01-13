import 'package:dio/dio.dart';
import '../../config/api_config.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    print('🌐 ApiConfig.baseUrl = ${ApiConfig.baseUrl}');
    dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return dio.post<T>(path, data: data);
  }
}
