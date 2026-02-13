import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // API 基础地址
  static const String _baseUrl = 'http://8.152.197.205';
  
  final StorageService _storage = StorageService();

  String get baseUrl => _baseUrl;

  // GET 请求
  Future<dynamic> get(String url) async {
    final fullUrl = '$_baseUrl$url';
    print('[API GET] $fullUrl');
    
    try {
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: _headers(),
      );
      return _handleResponse(response);
    } catch (e) {
      print('[API ERROR] GET $url: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // POST 请求
  Future<dynamic> post(String url, {Map<String, dynamic>? data}) async {
    final fullUrl = '$_baseUrl$url';
    print('[API POST] $fullUrl');
    print('[API DATA] $data');
    
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: _headers(),
        body: data != null ? jsonEncode(data) : null,
      );
      print('[API RESPONSE BODY] ${response.body}');
      return _handleResponse(response);
    } catch (e) {
      print('[API ERROR] POST $url: $e');
      throw Exception('网络请求失败: $e');
    }
  }

  // 文件上传
  Future<dynamic> uploadFile(String url, File file, {String field = 'file'}) async {
    final fullUrl = '$_baseUrl$url';
    print('[API UPLOAD] $fullUrl');
    
    try {
      final request = http.MultipartRequest('POST', Uri.parse(fullUrl));
      
      // 添加认证头
      final token = _storage.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // 添加文件
      final multipartFile = await http.MultipartFile.fromPath(
        field,
        file.path,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } catch (e) {
      print('[API ERROR] UPLOAD $url: $e');
      throw Exception('文件上传失败: $e');
    }
  }

  // 构建请求头
  Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final token = _storage.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  // 处理响应
  dynamic _handleResponse(http.Response response) {
    print('[API RESPONSE] Status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final body = jsonDecode(response.body);
        return body;
      } catch (e) {
        return response.body;
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }
}
