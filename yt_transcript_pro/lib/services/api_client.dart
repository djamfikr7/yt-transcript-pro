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

  Future<void> deleteProject(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/projects/$id'));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete project: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadFile(
    String filePath,
    String fileName,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/projects/upload'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload file: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> runDiarization(int projectId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/diarize'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Diarization failed: ${response.body}');
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

  // === Semantic Search ===

  Future<Map<String, dynamic>> searchTranscripts(
    String query, {
    int topK = 10,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'top_k': topK}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Search failed: ${response.body}');
    }
  }

  // === Social Clips ===

  Future<Map<String, dynamic>> generateClips(
    int projectId, {
    int duration = 30,
    int count = 3,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/projects/$projectId/clips?duration=$duration&count=$count',
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Clip generation failed: ${response.body}');
    }
  }

  String getClipDownloadUrl(int projectId, String clipName) {
    return '$baseUrl/projects/$projectId/clips/$clipName';
  }
}
