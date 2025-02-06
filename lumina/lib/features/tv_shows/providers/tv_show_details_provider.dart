import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer' as developer;
import '../models/tv_show.dart';
import '../../sync/services/database_service.dart';

part 'tv_show_details_provider.g.dart';

@riverpod
Future<TVShow> tvShowDetails(TvShowDetailsRef ref, int tmdbId) async {
  final db = DatabaseService();
  final showData = await db.getTVShow(tmdbId);
  
  if (showData == null) {
    developer.log(
      'TV Show not found',
      name: 'tvShowDetailsProvider',
      error: {'tmdbId': tmdbId},
      level: 1000,
    );
    throw Exception('TV Show not found');
  }
  
  developer.log(
    'Retrieved TV Show data',
    name: 'tvShowDetailsProvider',
    error: {'tmdbId': tmdbId, 'data': showData},
  );
  
  final show = TVShow.fromMap(showData);
  
  developer.log(
    'Created TVShow object',
    name: 'tvShowDetailsProvider',
    error: {
      'tmdbId': show.tmdbId,
      'posterPath': show.posterPath,
      'posterFilePath': show.posterFile?.path,
      'posterFileExists': show.posterFile?.existsSync(),
    },
  );
  
  return show;
} 