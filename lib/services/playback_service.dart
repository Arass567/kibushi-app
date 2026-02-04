import 'package:audioplayers/audioplayers.dart';

class PlaybackService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playLocalFile(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  Future<void> playAsset(String assetPath) async {
    await _player.play(AssetSource(assetPath));
  }

  void dispose() {
    _player.dispose();
  }
}
