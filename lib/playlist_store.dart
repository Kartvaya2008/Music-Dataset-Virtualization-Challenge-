// playlist_store.dart
import 'dart:collection';

class PlaylistStore {
  static final List<Map<String, dynamic>> _likedSongs = [];

  static UnmodifiableListView<Map<String, dynamic>> get likedSongs =>
      UnmodifiableListView(_likedSongs);

  static void addSong(Map<String, dynamic> song) {
    if (!_likedSongs.any((s) => s['trackId'] == song['trackId'])) {
      _likedSongs.add(song);
    }
  }

  static void removeSong(Map<String, dynamic> song) {
    _likedSongs.removeWhere((s) => s['trackId'] == song['trackId']);
  }

  static bool isLiked(Map<String, dynamic> song) {
    return _likedSongs.any((s) => s['trackId'] == song['trackId']);
  }
}