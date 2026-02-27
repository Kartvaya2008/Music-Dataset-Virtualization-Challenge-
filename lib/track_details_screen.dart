import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ Add connectivity
import 'network_checker.dart';

class TrackDetailsScreen extends StatefulWidget {
  final Map song;

  const TrackDetailsScreen({super.key, required this.song});

  @override
  State<TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends State<TrackDetailsScreen> {
  bool isLoading = true;
  bool noInternet = false; // ✅ Same isOffline flag
  bool isOffline = false; // ✅ Same as noInternet

  Map? lyricsData;

  @override
  void initState() {
    super.initState();
    checkConnection(); // ✅ Call connection check first
  }

  // ✅ Same checkConnection() logic
  Future<void> checkConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        isOffline = true;
        noInternet = true;
        isLoading = false;
      });
    } else {
      setState(() {
        isOffline = false;
        noInternet = false;
      });
      fetchLyrics(); // ✅ Proceed to fetch lyrics if online
    }
  }

  Future<void> fetchLyrics() async {
    try {
      final track = widget.song["trackName"] ?? "";
      final artist = widget.song["artistName"] ?? "";
      final album = widget.song["collectionName"] ?? "";

      final url = Uri.parse(
        "https://lrclib.net/api/get-cached?track_name=$track&artist_name=$artist&album_name=$album",
      );

      final response = await http.get(url);

      // 🔥 STEP 3 — API response check karo
      if (response.body.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      if (response.statusCode == 200) {
        // 🔥 STEP 4 — JSON decode safe karo
        final decoded = jsonDecode(response.body);
        
        if (decoded == null || decoded.isEmpty) {
          setState(() => isLoading = false);
          return;
        }

        setState(() {
          lyricsData = decoded;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } on SocketException {
      setState(() {
        noInternet = true;
        isOffline = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;

    return Scaffold(
      appBar: AppBar(title: const Text("Track Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())

            : noInternet || isOffline // ✅ Use both flags
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          "NO INTERNET CONNECTION",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ),
                  )

                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Center(
                          child: song["artworkUrl100"] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    song["artworkUrl100"],
                                    height: 150,
                                    width: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 150,
                                        width: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.music_note, size: 50),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  height: 150,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.music_note, size: 50),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // 🔥 STEP 2 — Details data show karte time fix
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Track: ${song["trackName"] ?? "Not available"}",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text("Artist: ${song["artistName"] ?? "Not available"}",
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text("Album: ${song["collectionName"] ?? "Not available"}",
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text("Genre: ${song["primaryGenreName"] ?? "Not available"}",
                                    style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "Lyrics",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 10),

                        // ⭐ BEST FIX — Safe lyrics display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: lyricsData == null
                              ? const Text("Lyrics not available", 
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                              : Text(lyricsData!["plainLyrics"] ?? "Lyrics not available",
                                  style: const TextStyle(height: 1.5)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}