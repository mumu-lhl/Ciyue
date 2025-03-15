import 'dart:convert';

import 'package:dio/dio.dart';

class AI {
  final String provider;
  final String model;
  final String apikey;
  late final AIProvider aiProvider;

  AI({
    required this.provider,
    required this.model,
    required this.apikey,
  }) {
    if (provider == 'openai') {
      aiProvider = OpenAICompatibleProvider(
        apikey: apikey,
        model: model,
        apiUrl: OpenAICompatibleProvider.defaultApiUrl,
      );
    } else if (provider == 'gemini') {
      aiProvider = GeminiProvider(apikey: apikey, model: model);
    } else if (provider == 'deepseek') {
      aiProvider = OpenAICompatibleProvider(
        apikey: apikey,
        model: model,
        apiUrl: 'https://api.deepseek.com/chat/completions',
      );
    }
  }

  Future<String> request(String prompt) async {
    return aiProvider.request(prompt);
  }
}

abstract class AIProvider {
  Future<String> request(String prompt);
}

class GeminiProvider extends AIProvider {
  GeminiProvider({required this.apikey, required this.model});

  final String apikey;
  final String model;

  static const String apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent";

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
    final formattedApiUrl = apiUrl.replaceFirst('{model}', model);

    final params = {'key': apikey};

    final headers = {
      'Content-Type': 'application/json',
    };
    final data = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    };

    try {
      final response = await dio.post(
        formattedApiUrl,
        queryParameters: params,
        options: Options(headers: headers),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception(
            'Failed to fetch response from Gemini API. Status code: ${response.statusCode}, body: ${response.data}');
      }
    } catch (e) {
      throw Exception('Error requesting Gemini API: $e');
    }
  }
}

class OpenAICompatibleProvider extends AIProvider {
  static const String defaultApiUrl =
      "https://api.openai.com/v1/chat/completions";

  final String apikey;
  final String model;
  final String apiUrl;

  OpenAICompatibleProvider({
    required this.apikey,
    required this.model,
    required this.apiUrl,
  });

  @override
  Future<String> request(String prompt) async {
    final dio = Dio();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apikey',
    };
    final data = {
      "model": model,
      "messages": [
        {"role": "user", "content": prompt}
      ]
    };

    try {
      final response = await dio.post(
        apiUrl,
        options: Options(headers: headers),
        data: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final decodedResponse = response.data;
        return decodedResponse['choices'][0]['message']['content'];
      } else {
        throw Exception(
            'Failed to fetch response from OpenAI API. Status code: ${response.statusCode}, body: ${response.data}');
      }
    } catch (e) {
      throw Exception('Error requesting OpenAI API: $e');
    }
  }
}
