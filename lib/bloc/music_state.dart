import 'package:equatable/equatable.dart';

abstract class MusicState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MusicInitial extends MusicState {}

class MusicLoading extends MusicState {}

class MusicLoaded extends MusicState {
  final List songs;
  final Map? currentSong;
  final bool isPlaying;

  MusicLoaded({
    required this.songs,
    this.currentSong,
    this.isPlaying = false,
  });

  @override
  List<Object?> get props => [songs, currentSong, isPlaying];
}

class MusicError extends MusicState {
  final String message;
  MusicError(this.message);

  @override
  List<Object?> get props => [message];
}