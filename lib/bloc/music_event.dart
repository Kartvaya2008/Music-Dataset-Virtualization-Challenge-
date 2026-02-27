import 'package:equatable/equatable.dart';

abstract class MusicEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchSongs extends MusicEvent {}

class SearchSongs extends MusicEvent {
  final String query;
  SearchSongs(this.query);

  @override
  List<Object?> get props => [query];
}

class PlaySong extends MusicEvent {
  final Map song;
  PlaySong(this.song);

  @override
  List<Object?> get props => [song];
}