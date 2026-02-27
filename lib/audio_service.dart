import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();

  factory AudioService() => _instance;

  AudioService._internal();

  final AudioPlayer player = AudioPlayer();

  Map<String, dynamic>? currentSong;
  bool isPlaying = false;

  Future<void> play(Map<String, dynamic> song) async {
    final url = song["previewUrl"];
    if (url == null || url.toString().isEmpty) return;

    await player.stop();
    await player.play(UrlSource(url));

    currentSong = song;
    isPlaying = true;
  }

  Future<void> pause() async {
    await player.pause();
    isPlaying = false;
  }

  Future<void> resume() async {
    await player.resume();
    isPlaying = true;
  }
}