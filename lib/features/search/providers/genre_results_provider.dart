import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:debrid_player/features/search/providers/search_provider.dart' show searchResultsProvider;

final selectedGenreMovieProvider = StateProvider<Map<String, dynamic>?>((ref) => null); 