import 'package:flutter_bloc/flutter_bloc.dart';
import 'music_event.dart';
import 'music_state.dart';
import '../repository/music_repository.dart';

class MusicBloc extends Bloc<MusicEvent, MusicState> {
  final MusicRepository repository;

  MusicBloc(this.repository) : super(MusicInitial()) {
    on<FetchSongs>(_onFetchSongs);
    on<SearchSongs>(_onSearchSongs);
    on<PlaySong>(_onPlaySong);
  }

  Future<void> _onFetchSongs(
      FetchSongs event, Emitter<MusicState> emit) async {
    emit(MusicLoading());
    try {
      final songs = await repository.fetchSongs();
      emit(MusicLoaded(songs: songs));
    } catch (e) {
      emit(MusicError("Failed to fetch songs"));
    }
  }

  Future<void> _onSearchSongs(
      SearchSongs event, Emitter<MusicState> emit) async {
    emit(MusicLoading());
    final songs = await repository.searchSongs(event.query);
    emit(MusicLoaded(songs: songs));
  }

  void _onPlaySong(
      PlaySong event, Emitter<MusicState> emit) {
    if (state is MusicLoaded) {
      final current = state as MusicLoaded;
      emit(MusicLoaded(
        songs: current.songs,
        currentSong: event.song,
        isPlaying: true,
      ));
    }
  }
}