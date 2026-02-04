import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<String?> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/kibushi_temp.wav';
        
        // Suppression du fichier précédent s'il existe
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }

        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _recorder.start(config, path: path);
        return path;
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
    return null;
  }

  Future<String?> stopRecording() async {
    try {
      return await _recorder.stop();
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
    return null;
  }

  void dispose() {
    _recorder.dispose();
  }
}

void debugPrint(String s) => print('🦅 baby-recorder: $s');
