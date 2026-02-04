import 'dart:convert';
import 'package:flutter/services.dart';

class DictionaryService {
  Map<String, dynamic>? _data;

  Future<void> load() async {
    final String response = await rootBundle.loadString('assets/json/kibushi_backend_final.json');
    _data = json.decode(response);
  }

  // Méthode pour obtenir une phrase d'invitation (prompt)
  String getRandomPrompt() {
    if (_data == null || !_data!.containsKey('prompts')) return "Akori adakeli ?";
    final List prompts = _data!['prompts'];
    return (prompts..shuffle()).first['text'] ?? "Akori adakeli ?";
  }
}
