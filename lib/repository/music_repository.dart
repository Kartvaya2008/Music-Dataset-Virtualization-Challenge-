import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicRepository {

  Future<List> fetchSongs() async {
    final response = await http.get(
      Uri.parse("https://itunes.apple.com/search?term=a&entity=song&limit=20")
    );

    final data = jsonDecode(response.body);
    return data["results"];
  }

  Future<List> searchSongs(String query) async {
    final response = await http.get(
      Uri.parse("https://itunes.apple.com/search?term=$query&entity=song&limit=20")
    );

    final data = jsonDecode(response.body);
    return data["results"];
  }
}