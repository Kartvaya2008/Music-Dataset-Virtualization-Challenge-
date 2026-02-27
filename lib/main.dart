import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ─────────────────────────────────────────────
// THEME SYSTEM
// ─────────────────────────────────────────────

class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF111111);
  static const card = Color(0xFF1A1A2E);
  static const accent = Color(0xFF8A2BE2);
  static const highlight = Color(0xFFFF2E9F);
  static const progress = Color(0xFFFFD84D);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9E9E9E);
  static const border = Color(0xFF2A2A3E);
}

ThemeData buildNeonDarkTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.highlight,
    surface: AppColors.surface,
    onPrimary: Colors.white,
    onSurface: AppColors.textPrimary,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.textSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 10,
  ),
  cardTheme: CardThemeData(
    color: AppColors.card,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: AppColors.accent,
    inactiveTrackColor: AppColors.border,
    thumbColor: AppColors.progress,
    overlayColor: AppColors.accent.withOpacity(0.2),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary),
    trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.accent.withOpacity(0.5) : AppColors.border),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIconColor: AppColors.accent,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
  ),
);

ThemeData buildLightTheme() => ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
  useMaterial3: true,
);

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  final String previewUrl;
  final int duration;
  final String genre;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    required this.previewUrl,
    required this.duration,
    required this.genre,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['trackId'].toString(),
    title: json['trackName'] ?? 'Unknown Title',
    artist: json['artistName'] ?? 'Unknown Artist',
    album: json['collectionName'] ?? 'Unknown Album',
    artworkUrl: json['artworkUrl100'] ?? '',
    previewUrl: json['previewUrl'] ?? '',
    duration: json['trackTimeMillis'] ?? 0,
    genre: json['primaryGenreName'] ?? 'Unknown',
  );

  Map<String, dynamic> toMap() => {
    'trackId': int.tryParse(id) ?? 0,
    'trackName': title,
    'artistName': artist,
    'collectionName': album,
    'artworkUrl100': artworkUrl,
    'previewUrl': previewUrl,
    'trackTimeMillis': duration,
    'primaryGenreName': genre,
  };
}

class TrackDetails {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final String releaseDate;
  final int duration;
  final String artworkUrl;

  const TrackDetails({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.releaseDate,
    required this.duration,
    required this.artworkUrl,
  });

  factory TrackDetails.fromJson(Map<String, dynamic> json) => TrackDetails(
    id: json['trackId'].toString(),
    title: json['trackName'] ?? 'Unknown Title',
    artist: json['artistName'] ?? 'Unknown Artist',
    album: json['collectionName'] ?? 'Unknown Album',
    genre: json['primaryGenreName'] ?? 'Unknown',
    releaseDate: json['releaseDate']?.split('T')[0] ?? 'Unknown',
    duration: json['trackTimeMillis'] ?? 0,
    artworkUrl: (json['artworkUrl100'] ?? '').replaceAll('100x100', '600x600'),
  );
}

// ─────────────────────────────────────────────
// AUDIO SERVICE (Singleton)
// ─────────────────────────────────────────────

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer player = AudioPlayer();
  Track? currentTrack;
  bool isPlaying = false;

  final StreamController<Track?> _trackController = StreamController.broadcast();
  final StreamController<bool> _playingController = StreamController.broadcast();

  Stream<Track?> get trackStream => _trackController.stream;
  Stream<bool> get playingStream => _playingController.stream;

  Future<void> play(Track track) async {
    if (track.previewUrl.isEmpty) return;
    await player.stop();
    await player.play(UrlSource(track.previewUrl));
    currentTrack = track;
    isPlaying = true;
    _trackController.add(track);
    _playingController.add(true);
    player.onPlayerStateChanged.listen((state) {
      isPlaying = state == PlayerState.playing;
      _playingController.add(isPlaying);
    });
  }

  Future<void> pause() async {
    await player.pause();
    isPlaying = false;
    _playingController.add(false);
  }

  Future<void> resume() async {
    await player.resume();
    isPlaying = true;
    _playingController.add(true);
  }

  Future<void> togglePlay() async {
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }
}

// ─────────────────────────────────────────────
// PLAYLIST STORE
// ─────────────────────────────────────────────

class PlaylistStore {
  static final List<Track> _likedTracks = [];
  static final StreamController<List<Track>> _controller = StreamController.broadcast();

  static Stream<List<Track>> get stream => _controller.stream;
  static List<Track> get tracks => List.unmodifiable(_likedTracks);

  static void toggle(Track track) {
    if (isLiked(track)) {
      _likedTracks.removeWhere((t) => t.id == track.id);
    } else {
      _likedTracks.add(track);
    }
    _controller.add(List.unmodifiable(_likedTracks));
  }

  static bool isLiked(Track track) => _likedTracks.any((t) => t.id == track.id);
}

// ─────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────

class MusicRepository {
  static const int _limit = 100;
  static const int _maxLoad = 50000;
  final List<String> _queries = List.generate(26, (i) => String.fromCharCode(97 + i));

  int get queryCount => _queries.length;
  String queryAt(int i) => _queries[i];
  int get limit => _limit;
  int get maxLoad => _maxLoad;

  Future<List<Track>> fetchTracks({required String query, required int offset}) async {
    final url = 'https://itunes.apple.com/search?term=$query&entity=song&limit=$_limit&offset=$offset';
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return await compute(_parseTracks, response.body);
    }
    throw Exception('Failed to load songs: ${response.statusCode}');
  }
}

// Top-level function required for compute isolate
List<Track> _parseTracks(String body) {
  final data = json.decode(body) as Map<String, dynamic>;
  final results = data['results'] as List? ?? [];
  return results
      .whereType<Map<String, dynamic>>()
      .map(Track.fromJson)
      .toList();
}

// ─────────────────────────────────────────────
// BLOC — Events
// ─────────────────────────────────────────────

abstract class MusicEvent {}

class FetchInitialSongs extends MusicEvent {
  final String query;
  FetchInitialSongs({this.query = 'a'});
}

class LoadMoreSongs extends MusicEvent {}

class SearchQuery extends MusicEvent {
  final String query;
  SearchQuery(this.query);
}

// ─────────────────────────────────────────────
// BLOC — States
// ─────────────────────────────────────────────

abstract class MusicState {}

class MusicInitial extends MusicState {}
class MusicLoading extends MusicState {}

class MusicLoaded extends MusicState {
  final List<Track> tracks;
  final bool hasMore;
  final int offset;
  final int queryPointer;
  final Set<String> loadedIds;
  final int totalLoaded;
  final String currentQuery;
  final bool isLoadingMore;

  MusicLoaded({
    required this.tracks,
    required this.hasMore,
    required this.offset,
    required this.queryPointer,
    required this.loadedIds,
    required this.totalLoaded,
    required this.currentQuery,
    this.isLoadingMore = false,
  });

  MusicLoaded copyWith({
    List<Track>? tracks,
    bool? hasMore,
    int? offset,
    int? queryPointer,
    Set<String>? loadedIds,
    int? totalLoaded,
    String? currentQuery,
    bool? isLoadingMore,
  }) => MusicLoaded(
    tracks: tracks ?? this.tracks,
    hasMore: hasMore ?? this.hasMore,
    offset: offset ?? this.offset,
    queryPointer: queryPointer ?? this.queryPointer,
    loadedIds: loadedIds ?? this.loadedIds,
    totalLoaded: totalLoaded ?? this.totalLoaded,
    currentQuery: currentQuery ?? this.currentQuery,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

class MusicError extends MusicState {
  final String message;
  MusicError(this.message);
}

// ─────────────────────────────────────────────
// BLOC — Logic
// ─────────────────────────────────────────────

class MusicBloc extends Bloc<MusicEvent, MusicState> {
  final MusicRepository _repo;

  MusicBloc(this._repo) : super(MusicInitial()) {
    on<FetchInitialSongs>(_onFetch);
    on<LoadMoreSongs>(_onLoadMore);
    on<SearchQuery>(_onSearch);
  }

  Future<void> _onFetch(FetchInitialSongs event, Emitter<MusicState> emit) async {
    emit(MusicLoading());
    try {
      final tracks = await _repo.fetchTracks(query: event.query, offset: 0);
      final ids = tracks.map((t) => t.id).toSet();
      emit(MusicLoaded(
        tracks: tracks,
        hasMore: tracks.length == _repo.limit,
        offset: _repo.limit,
        queryPointer: 0,
        loadedIds: ids,
        totalLoaded: tracks.length,
        currentQuery: event.query,
      ));
    } catch (e) {
      emit(MusicError(e.toString()));
    }
  }

  Future<void> _onLoadMore(LoadMoreSongs event, Emitter<MusicState> emit) async {
    if (state is! MusicLoaded) return;
    final s = state as MusicLoaded;
    if (!s.hasMore || s.isLoadingMore) return;

    emit(s.copyWith(isLoadingMore: true));
    try {
      String query = s.currentQuery;
      int offset = s.offset;
      int qp = s.queryPointer;

      final results = await _repo.fetchTracks(query: query, offset: offset);

      if (results.isEmpty) {
        qp++;
        if (qp >= _repo.queryCount) {
          emit(s.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }
        final nextResults = await _repo.fetchTracks(query: _repo.queryAt(qp), offset: 0);
        final newIds = Set<String>.from(s.loadedIds);
        final newTracks = List<Track>.from(s.tracks);
        for (final t in nextResults) {
          if (!newIds.contains(t.id)) {
            newTracks.add(t);
            newIds.add(t.id);
          }
        }
        final total = s.totalLoaded + nextResults.length;
        emit(s.copyWith(
          tracks: newTracks,
          loadedIds: newIds,
          offset: _repo.limit,
          queryPointer: qp,
          totalLoaded: total,
          hasMore: total < _repo.maxLoad && qp + 1 < _repo.queryCount,
          currentQuery: _repo.queryAt(qp),
          isLoadingMore: false,
        ));
      } else {
        final newIds = Set<String>.from(s.loadedIds);
        final newTracks = List<Track>.from(s.tracks);
        for (final t in results) {
          if (!newIds.contains(t.id)) {
            newTracks.add(t);
            newIds.add(t.id);
          }
        }
        final total = s.totalLoaded + results.length;
        emit(s.copyWith(
          tracks: newTracks,
          loadedIds: newIds,
          offset: offset + _repo.limit,
          totalLoaded: total,
          hasMore: total < _repo.maxLoad && results.length == _repo.limit,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(s.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSearch(SearchQuery event, Emitter<MusicState> emit) async {
    if (event.query.trim().isEmpty) {
      add(FetchInitialSongs());
      return;
    }
    emit(MusicLoading());
    try {
      final tracks = await _repo.fetchTracks(query: event.query.trim(), offset: 0);
      final ids = tracks.map((t) => t.id).toSet();
      emit(MusicLoaded(
        tracks: tracks,
        hasMore: tracks.length == _repo.limit,
        offset: _repo.limit,
        queryPointer: 0,
        loadedIds: ids,
        totalLoaded: tracks.length,
        currentQuery: event.query.trim(),
      ));
    } catch (e) {
      emit(MusicError(e.toString()));
    }
  }
}

// ─────────────────────────────────────────────
// INTERNET CHECKER
// ─────────────────────────────────────────────

Future<bool> hasInternet() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────

void main() {
  runApp(
    BlocProvider(
      create: (_) => MusicBloc(MusicRepository())..add(FetchInitialSongs()),
      child: const NeonMusicApp(),
    ),
  );
}

class NeonMusicApp extends StatefulWidget {
  const NeonMusicApp({super.key});

  static _NeonMusicAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_NeonMusicAppState>()!;

  @override
  State<NeonMusicApp> createState() => _NeonMusicAppState();
}

class _NeonMusicAppState extends State<NeonMusicApp> {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme(bool value) => setState(() => _isDarkMode = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? buildNeonDarkTheme() : buildLightTheme(),
      home: const LoginScreen(),
      routes: {'/home': (_) => const HomeScreen()},
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _continueAsGuest() => Navigator.pushReplacementNamed(context, '/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D1A), AppColors.background, Color(0xFF0D0D1A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [AppColors.accent, Color(0xFF3D0070)]),
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.6), blurRadius: 30, spreadRadius: 5)],
                    ),
                    child: const Icon(Icons.headphones_rounded, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text('NEON BEATS', style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary, letterSpacing: 4,
                  )),
                  const SizedBox(height: 6),
                  const Text('Premium Music Streaming', style: TextStyle(
                    color: AppColors.accent, fontSize: 14, letterSpacing: 1,
                  )),
                  const SizedBox(height: 50),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _NeonTextField(
                          controller: _emailCtrl,
                          hint: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter email';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _NeonTextField(
                          controller: _passCtrl,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textSecondary),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        _NeonButton(label: 'SIGN IN', onTap: _login),
                        const SizedBox(height: 16),
                        _GhostButton(label: 'Continue as Guest', onTap: _continueAsGuest),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Create Account', style: TextStyle(color: AppColors.highlight)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN (Navigation Shell)
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _audio = AudioService();

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeTab(),
      const MusicListScreen(),
      const PlaylistTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: screens),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: StreamBuilder<Track?>(
              stream: _audio.trackStream,
              builder: (context, _) {
                if (_audio.currentTrack == null) return const SizedBox.shrink();
                return _MiniPlayer(audio: _audio);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music_rounded), label: 'Songs'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  final _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      context.read<MusicBloc>().add(LoadMoreSongs());
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.read<MusicBloc>().add(SearchQuery(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: BlocBuilder<MusicBloc, MusicState>(
            builder: (ctx, state) {
              if (state is MusicLoading) {
                return const Center(child: _NeonLoader());
              }
              if (state is MusicError) {
                return _ErrorView(message: state.message,
                  onRetry: () => ctx.read<MusicBloc>().add(FetchInitialSongs()));
              }
              if (state is MusicLoaded) {
                return _buildGrid(state);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.background.withOpacity(0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi, Welcome Back 🔥', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Listen to Your\nFavourite Music', style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 22,
                    fontWeight: FontWeight.w900, height: 1.2,
                  )),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: AppColors.accent, size: 14),
                    SizedBox(width: 4),
                    Text('GUEST', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search songs, artists...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch('');
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(MusicLoaded state) {
    final tracks = state.tracks;
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: tracks.length + (state.isLoadingMore ? 2 : 0),
      itemBuilder: (ctx, i) {
        if (i >= tracks.length) return const _LoadingCard();
        return _TrackCard(
          track: tracks[i],
          onTap: () => _audio.play(tracks[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MUSIC LIST SCREEN (A-Z with sticky headers)
// ─────────────────────────────────────────────

class MusicListScreen extends StatefulWidget {
  const MusicListScreen({super.key});
  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen> {
  List<Track> _tracks = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  int _qp = 0;
  int _total = 0;
  final Set<String> _ids = {};
  final List<String> _queries = List.generate(26, (i) => String.fromCharCode(97 + i));
  final _scroll = ScrollController();
  final _audio = AudioService();
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkAndFetch();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500 && !_loading) {
        _fetchSongs();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkAndFetch() async {
    final online = await hasInternet();
    if (!mounted) return;
    setState(() => _isOffline = !online);
    if (online) _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final query = _queries[_qp];
      final url = 'https://itunes.apple.com/search?term=$query&entity=song&limit=100&offset=$_offset';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final parsed = await compute(_parseTracks, resp.body);
        if (parsed.isEmpty) {
          _qp++;
          _offset = 0;
          if (_qp >= _queries.length) _hasMore = false;
        } else {
          final newTracks = <Track>[];
          for (final t in parsed) {
            if (!_ids.contains(t.id)) {
              newTracks.add(t);
              _ids.add(t.id);
            }
          }
          _tracks.addAll(newTracks);
          _offset += 100;
          _total += newTracks.length;
          if (_total >= 50000) _hasMore = false;
        }
        setState(() {});
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Map<String, List<Track>> _grouped() {
    final map = <String, List<Track>>{};
    for (final t in _tracks) {
      final l = t.title.isEmpty ? '#' : (RegExp(r'[A-Za-z]').hasMatch(t.title[0]) ? t.title[0].toUpperCase() : '#');
      map.putIfAbsent(l, () => []).add(t);
    }
    final sorted = map.keys.toList()..sort();
    return {for (final k in sorted) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return _NoInternetScreen(onRetry: _checkAndFetch);
    }
    if (_tracks.isEmpty && _loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: _NeonLoader()),
      );
    }
    final grouped = _grouped();
    final letters = grouped.keys.toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Songs Library (${_total})')),
      body: ListView.builder(
        controller: _scroll,
        itemCount: letters.length + (_loading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i >= letters.length) {
            return const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: _NeonLoader()),
            );
          }
          final letter = letters[i];
          final group = grouped[letter]!;
          return StickyHeader(
            header: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF3D0070)]),
              ),
              child: Text(letter, style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2,
              )),
            ),
            content: Column(
              children: group.map((t) => _TrackListTile(
                track: t,
                audio: _audio,
                onTap: () => Navigator.push(ctx, _slideRoute(TrackDetailsScreen(track: t))),
              )).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLAYLIST / FAVORITES TAB
// ─────────────────────────────────────────────

class PlaylistTab extends StatelessWidget {
  const PlaylistTab({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    return StreamBuilder<List<Track>>(
      stream: PlaylistStore.stream,
      initialData: PlaylistStore.tracks,
      builder: (ctx, snap) {
        final tracks = snap.data ?? [];
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Favorites (${tracks.length})'),
          ),
          body: tracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border_rounded, size: 70, color: AppColors.accent.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text('No favorites yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Like songs to add them here', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: tracks.length,
                  itemBuilder: (ctx, i) => _TrackListTile(
                    track: tracks[i],
                    audio: audio,
                    onTap: () => Navigator.push(ctx, _slideRoute(TrackDetailsScreen(track: tracks[i]))),
                  ),
                ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
        child: Column(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [AppColors.accent.withOpacity(0.3), Colors.transparent]),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.accent, AppColors.highlight]),
                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Guest User', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Text('GUEST MODE', style: TextStyle(
                color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2,
              )),
            ),
            const SizedBox(height: 30),
            _ProfileInfoCard(),
            const SizedBox(height: 20),
            _LockedFeatureCard(
              icon: Icons.download_rounded,
              title: 'Offline Downloads',
              subtitle: 'Download and play songs offline',
            ),
            const SizedBox(height: 12),
            _LockedFeatureCard(
              icon: Icons.sync_rounded,
              title: 'Sync Account',
              subtitle: 'Sync your library across devices',
            ),
            const SizedBox(height: 20),
            _NeonButton(
              label: 'CREATE ACCOUNT',
              onTap: () => _showUpgradeDialog(context),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.push(context, _slideRoute(const SettingsScreen())),
              icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
              label: const Text('Settings', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Session Info', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          _infoRow(Icons.person_outline, 'Username', 'Guest User'),
          const Divider(color: AppColors.border, height: 20),
          _infoRow(Icons.email_outlined, 'Email', 'Not set'),
          const Divider(color: AppColors.border, height: 20),
          _infoRow(Icons.storage_rounded, 'Storage', 'Temporary (Session only)'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LockedFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LockedFeatureCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showUpgradeDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.highlight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.highlight, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _bass = 0, _mid = 0, _treble = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = NeonMusicApp.of(context).isDarkMode;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionLabel('DISPLAY'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Enable neon dark theme',
            trailing: Switch(
              value: isDark,
              onChanged: (v) => NeonMusicApp.of(context).toggleTheme(v),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('EQUALIZER'),
          const SizedBox(height: 10),
          _EqSlider(label: 'Bass', value: _bass, onChanged: (v) => setState(() => _bass = v)),
          _EqSlider(label: 'Mid', value: _mid, onChanged: (v) => setState(() => _mid = v)),
          _EqSlider(label: 'Treble', value: _treble, onChanged: (v) => setState(() => _treble = v)),
          const SizedBox(height: 20),
          _SectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Clear session and return to login',
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _EqSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _EqSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Slider(value: value, min: -10, max: 10, divisions: 20, onChanged: onChanged),
          ),
          SizedBox(
            width: 32,
            child: Text('${value.toInt()}', style: const TextStyle(color: AppColors.progress, fontSize: 12), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRACK DETAILS SCREEN
// ─────────────────────────────────────────────

class TrackDetailsScreen extends StatefulWidget {
  final Track track;
  const TrackDetailsScreen({super.key, required this.track});
  @override
  State<TrackDetailsScreen> createState() => _TrackDetailsScreenState();
}

class _TrackDetailsScreenState extends State<TrackDetailsScreen> {
  TrackDetails? _details;
  String? _lyrics;
  bool _loadingDetails = true;
  bool _loadingLyrics = true;
  String? _lyricsError;
  bool _isOffline = false;
  final _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final online = await hasInternet();
    if (!mounted) return;
    if (!online) {
      setState(() { _isOffline = true; _loadingDetails = false; _loadingLyrics = false; });
      return;
    }
    _fetchDetails();
    _fetchLyrics();
  }

  Future<void> _fetchDetails() async {
    try {
      final resp = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=${widget.track.id}'),
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if ((data['resultCount'] ?? 0) > 0) {
          setState(() {
            _details = TrackDetails.fromJson(data['results'][0]);
            _loadingDetails = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingDetails = false);
  }

  Future<void> _fetchLyrics() async {
    try {
      final url = Uri.parse(
        'https://lrclib.net/api/get-cached'
        '?track_name=${Uri.encodeComponent(widget.track.title)}'
        '&artist_name=${Uri.encodeComponent(widget.track.artist)}'
        '&album_name=${Uri.encodeComponent(widget.track.album)}'
        '&duration=0',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final data = jsonDecode(resp.body);
        setState(() {
          _lyrics = data['syncedLyrics'] ?? data['plainLyrics'] ?? 'No lyrics available';
          _loadingLyrics = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() { _lyrics = null; _lyricsError = 'Lyrics not found'; _loadingLyrics = false; });
  }

  String _fmtMs(int ms) {
    if (ms <= 0) return '0:00';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) return _NoInternetScreen(onRetry: () => setState(() {
      _isOffline = false;
      _loadingDetails = true;
      _loadingLyrics = true;
      _init();
    }));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Details'),
        actions: [
          StreamBuilder<List<Track>>(
            stream: PlaylistStore.stream,
            initialData: PlaylistStore.tracks,
            builder: (ctx, _) {
              final liked = PlaylistStore.isLiked(widget.track);
              return IconButton(
                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? AppColors.highlight : AppColors.textSecondary),
                onPressed: () => PlaylistStore.toggle(widget.track),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 40, spreadRadius: 5)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    (_details?.artworkUrl ?? widget.track.artworkUrl).replaceAll('100x100', '400x400'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.card,
                      child: const Icon(Icons.music_note_rounded, size: 80, color: AppColors.accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Info
            if (_loadingDetails)
              const Center(child: _NeonLoader())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_details?.title ?? widget.track.title,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_details?.artist ?? widget.track.artist,
                    style: const TextStyle(color: AppColors.accent, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_details?.album ?? widget.track.album,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(Icons.timer_rounded, _fmtMs(_details?.duration ?? widget.track.duration)),
                      _InfoChip(Icons.category_rounded, _details?.genre ?? widget.track.genre),
                      if (_details?.releaseDate != null)
                        _InfoChip(Icons.calendar_today_rounded, _details!.releaseDate),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),
            // Play Button
            if (widget.track.previewUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: _NeonButton(
                  label: 'PLAY PREVIEW',
                  icon: Icons.play_arrow_rounded,
                  onTap: () {
                    _audio.play(widget.track);
                  },
                ),
              ),
            const SizedBox(height: 24),
            // Lyrics
            const Text('Lyrics', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loadingLyrics)
              const Center(child: _NeonLoader())
            else if (_lyricsError != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(_lyricsError!, style: const TextStyle(
                    color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                ),
              )
            else if (_lyrics != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _lyrics!.replaceAll(RegExp(r'\[\d+:\d+\.\d+\]'), '').trim(),
                  style: const TextStyle(color: AppColors.textPrimary, height: 1.8, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI PLAYER
// ─────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final AudioService audio;
  const _MiniPlayer({required this.audio});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, _slideRoute(FullPlayerScreen(audio: audio))),
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.card, AppColors.surface]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 20, spreadRadius: -5),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                audio.currentTrack?.artworkUrl ?? '',
                width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48, height: 48, color: AppColors.card,
                  child: const Icon(Icons.music_note_rounded, color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(audio.currentTrack?.title ?? '',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(audio.currentTrack?.artist ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            StreamBuilder<bool>(
              stream: audio.playingStream,
              initialData: audio.isPlaying,
              builder: (ctx, snap) {
                final playing = snap.data ?? false;
                return IconButton(
                  icon: Icon(
                    playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    size: 36, color: AppColors.accent,
                  ),
                  onPressed: audio.togglePlay,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FULL PLAYER SCREEN
// ─────────────────────────────────────────────

class FullPlayerScreen extends StatefulWidget {
  final AudioService audio;
  const FullPlayerScreen({super.key, required this.audio});
  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rotCtrl;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _isPlaying = widget.audio.isPlaying;

    widget.audio.player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    widget.audio.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    widget.audio.player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s == PlayerState.playing);
      if (s == PlayerState.playing) {
        _rotCtrl.repeat();
      } else {
        _rotCtrl.stop();
      }
    });
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.audio.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppColors.card, AppColors.background, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    const Column(
                      children: [
                        Text('NOW PLAYING', style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10, letterSpacing: 2)),
                      ],
                    ),
                    const Spacer(),
                    StreamBuilder<List<Track>>(
                      stream: PlaylistStore.stream,
                      initialData: PlaylistStore.tracks,
                      builder: (ctx, _) {
                        final liked = PlaylistStore.isLiked(track);
                        return IconButton(
                          icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: liked ? AppColors.highlight : AppColors.textSecondary),
                          onPressed: () => PlaylistStore.toggle(track),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Rotating Disc
              RotationTransition(
                turns: _rotCtrl,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 50, spreadRadius: 10),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      track.artworkUrl.replaceAll('100x100', '400x400'),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.card,
                        child: const Icon(Icons.music_note_rounded, size: 80, color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    Text(track.title,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(track.artist,
                      style: const TextStyle(color: AppColors.accent, fontSize: 16),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Wave animation bar
              _WaveBar(isPlaying: _isPlaying),
              const SizedBox(height: 20),
              // Seek bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Slider(
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0),
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      onChanged: (v) => widget.audio.player.seek(Duration(seconds: v.toInt())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(_fmt(_duration), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 40, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: widget.audio.togglePlay,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [AppColors.accent, AppColors.highlight]),
                        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 20)],
                      ),
                      child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 40, color: AppColors.textSecondary),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WAVE ANIMATION
// ─────────────────────────────────────────────

class _WaveBar extends StatefulWidget {
  final bool isPlaying;
  const _WaveBar({required this.isPlaying});
  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  final int _bars = 30;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _ctrls = List.generate(_bars, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + rng.nextInt(400)),
      );
      if (widget.isPlaying) ctrl.repeat(reverse: true);
      return ctrl;
    });
  }

  @override
  void didUpdateWidget(_WaveBar old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      for (final c in _ctrls) {
        if (widget.isPlaying) {
          c.repeat(reverse: true);
        } else {
          c.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_bars, (i) {
          return AnimatedBuilder(
            animation: _ctrls[i],
            builder: (ctx, _) {
              final h = 8.0 + (_ctrls[i].value * 35.0);
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i % 3 == 0 ? AppColors.accent : i % 3 == 1 ? AppColors.highlight : AppColors.progress,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────

class _TrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  const _TrackCard({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      track.artworkUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.music_note_rounded, size: 40, color: AppColors.accent),
                      ),
                    ),
                    // Play overlay
                    Positioned(
                      bottom: 8, right: 8,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withOpacity(0.9),
                          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(track.artist,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackListTile extends StatelessWidget {
  final Track track;
  final AudioService audio;
  final VoidCallback onTap;
  const _TrackListTile({required this.track, required this.audio, required this.onTap});

  String _fmt(int ms) {
    if (ms <= 0) return '0:00';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                track.artworkUrl, width: 52, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52, height: 52, color: AppColors.card,
                  child: const Icon(Icons.music_note_rounded, color: AppColors.accent, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmt(track.duration), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(width: 4),
            StreamBuilder<List<Track>>(
              stream: PlaylistStore.stream,
              initialData: PlaylistStore.tracks,
              builder: (ctx, _) {
                final liked = PlaylistStore.isLiked(track);
                return IconButton(
                  icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? AppColors.highlight : AppColors.textSecondary, size: 20),
                  onPressed: () {
                    PlaylistStore.toggle(track);
                    audio.play(track);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonLoader extends StatelessWidget {
  const _NeonLoader();
  @override
  Widget build(BuildContext context) => const CircularProgressIndicator(
    color: AppColors.accent,
    strokeWidth: 3,
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(child: _NeonLoader()),
  );
}

class _NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _NeonButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.accent, AppColors.highlight]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.accent.withOpacity(0.5)),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(
            color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ),
    );
  }
}

class _NeonTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _NeonTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.accent),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 60, color: AppColors.highlight),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _NeonButton(label: 'RETRY', onTap: onRetry),
        ],
      ),
    ),
  );
}

class _NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoInternetScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: AppColors.highlight.withOpacity(0.3)),
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 60, color: AppColors.highlight),
              ),
              const SizedBox(height: 24),
              const Text('NO INTERNET CONNECTION', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Check your connection and try again', style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 30),
              _NeonButton(label: 'RETRY', onTap: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// UPGRADE DIALOG
// ─────────────────────────────────────────────

void _showUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.accent, AppColors.highlight]),
                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20)],
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Upgrade to Premium', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'Create playlists, download songs, and access exclusive features.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _NeonButton(label: 'CREATE ACCOUNT', onTap: () => Navigator.pop(ctx)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// ROUTE HELPER
// ─────────────────────────────────────────────

PageRouteBuilder _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, a, __) => page,
  transitionsBuilder: (_, a, __, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
    ),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 280),
);