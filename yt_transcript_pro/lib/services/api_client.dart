import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://localhost:8000'});

  // === Project CRUD ===

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

  // === Transcript ===

  Future<Map<String, dynamic>> getTranscript(int projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/transcript'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load transcript');
    }
  }

  Future<String> getExportContent(int projectId, String format) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/export?format=$format'),
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to download transcript');
    }
  }

  // === Translation ===

  Future<Map<String, dynamic>> translateProject(
    int projectId,
    String targetLang,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/projects/$projectId/translate?target_lang=$targetLang',
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to translate project: ${response.body}');
    }
  }

  // === LLM Content Repurposing ===

  Future<Map<String, dynamic>> summarize(
    int projectId, {
    String style = 'concise',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/summarize?style=$style'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to summarize: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> extractKeyPoints(
    int projectId, {
    int count = 5,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/key-points?count=$count'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to extract key points: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> generateSocialContent(
    int projectId, {
    String platform = 'twitter',
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/projects/$projectId/social-content?platform=$platform',
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate social content: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> generateBlogPost(int projectId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/blog'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate blog: ${response.body}');
    }
  }

  // === TTS Dubbing ===

  Future<Map<String, dynamic>> generateDub(
    int projectId, {
    String lang = 'en',
    String gender = 'female',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/dub?lang=$lang&gender=$gender'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to generate dub: ${response.body}');
    }
  }

  String getDubDownloadUrl(
    int projectId, {
    String lang = 'en',
    String gender = 'female',
  }) {
    return '$baseUrl/projects/$projectId/dub/download?lang=$lang&gender=$gender';
  }

  Future<Map<String, dynamic>> getTtsVoices() async {
    final response = await http.get(Uri.parse('$baseUrl/tts/voices'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get TTS voices');
    }
  }

  // === Health ===

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Health check failed');
    }
  }
}
