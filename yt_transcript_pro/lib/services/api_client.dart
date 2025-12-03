import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://localhost:8000'});

  Future<Map<String, dynamic>> createProject(String url) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create project: ${response.body}');
    }
  }

  Future<List<dynamic>> getProjects() async {
    final response = await http.get(Uri.parse('$baseUrl/projects'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load projects');
    }
  }

  Future<Map<String, dynamic>> getProject(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$id'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load project');
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Health check failed');
    }
  }
}
