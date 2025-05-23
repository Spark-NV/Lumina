import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:debrid_player/features/sync/services/wikidata_service.dart';
import 'package:debrid_player/features/sync/services/database_service.dart';
import 'package:debrid_player/features/sync/services/simkl_service.dart';
import 'package:debrid_player/features/sync/services/trakt_service.dart';

class TMDBService {
  final String _apiKey;
  final DatabaseService _databaseService;
  final SimklSyncService? _simklService;
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/original';

  TMDBService(this._apiKey, this._databaseService, this._simklService);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async {
    developer.log(
      'Fetching movie details',
      name: 'TMDBService',
      error: {'tmdbId': tmdbId},
    );
    
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$tmdbId?append_to_response=credits,images'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      Map<String, dynamic>? collectionData;
      List<Map<String, dynamic>> wikidataCollections = [];
      
      if (data['belongs_to_collection'] != null) {
        developer.log(
          'Movie belongs to collection',
          name: 'TMDBService',
          error: {
            'tmdbId': tmdbId,
            'collectionId': data['belongs_to_collection']['id'],
            'collectionName': data['belongs_to_collection']['name'],
          },
        );
        
        try {
          collectionData = await getCollectionDetails(data['belongs_to_collection']['id']);
        } catch (e) {
          developer.log(
            'Failed to fetch TMDB collection details',
            name: 'TMDBService',
            error: {
              'tmdbId': tmdbId,
              'collectionId': data['belongs_to_collection']['id'],
              'error': e.toString(),
            },
          );
        }
      }

      if (data['imdb_id'] != null) {
        try {
          final wikidataService = WikidataService();
          wikidataCollections = await wikidataService.getCollectionsForMovie(data['imdb_id']);
          
          developer.log(
            'Found Wikidata collections',
            name: 'TMDBService',
            error: {
              'tmdbId': tmdbId,
              'imdbId': data['imdb_id'],
              'collectionsCount': wikidataCollections.length,
              'collections': wikidataCollections,
            },
          );

          final dbService = DatabaseService();
          await dbService.insertWikidataCollections(wikidataCollections);
        } catch (e, st) {
          developer.log(
            'Error processing Wikidata collections',
            name: 'TMDBService',
            error: {
              'tmdbId': tmdbId,
              'imdbId': data['imdb_id'],
              'error': e.toString(),
            },
            stackTrace: st,
          );
        }
      }

      developer.log(
        'Raw genres data from TMDB',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'rawGenres': data['genres'],
        },
      );

      String title = data['title'] ?? '';
      String originalTitle = title;
      
      if (title.isEmpty) {
        developer.log(
          'Empty title',
          name: 'TMDBService',
          error: {'tmdbId': tmdbId},
          level: 900,
        );
        throw Exception('No valid title found for movie $tmdbId');
      }

      final genres = (data['genres'] as List?)?.map((genre) => {
        'id': genre['id'],
        'name': genre['name'],
      }).toList() ?? [];

      developer.log(
        'Processed genres data',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'genresCount': genres.length,
          'genres': genres,
        },
      );

      final movieData = {
        'tmdb_id': tmdbId,
        'imdb_id': data['imdb_id'],
        'original_title': title,
        'title': title,
        'overview': data['overview'],
        'release_date': data['release_date'],
        'revenue': data['revenue'],
        'runtime': data['runtime'],
        'vote_average': data['vote_average'],
        'collection_id': data['belongs_to_collection']?['id'],
        'collection_name': data['belongs_to_collection']?['name'],
        'genres': genres,
        'cast': (data['credits']['cast'] as List?)
            ?.take(7)
            .map((actor) => {
                  'id': actor['id'],
                  'name': actor['name'],
                })
            .toList() ?? [],
        'collection': collectionData,
        'wikidata_collections': wikidataCollections,
      };

      developer.log(
        'Final movie data with genres',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'title': title,
          'genresCount': movieData['genres'].length,
          'genres': movieData['genres'],
        },
      );

      developer.log(
        'Processed movie data',
        name: 'TMDBService',
        error: {'tmdbId': tmdbId, 'title': title},
      );

      if (data['poster_path'] != null) {
        await downloadImage(
          data['poster_path'],
          'movies/posters',
          tmdbId.toString(),
        );
      }

      if (data['backdrop_path'] != null) {
        await downloadImage(
          data['backdrop_path'],
          'movies/backdrops',
          tmdbId.toString(),
        );
      }

      developer.log('Processing actor images');
      for (final actor in data['credits']['cast'].take(10)) {
        if (actor['profile_path'] != null) {
          await downloadActorImage(actor);
        }
      }

      return movieData;
    } else {
      developer.log(
        'Failed to fetch movie details',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'statusCode': response.statusCode,
          'response': response.body,
        },
        level: 1000,
      );
      throw Exception('Failed to fetch movie details');
    }
  }

  Future<Map<String, dynamic>> fetchTVShowDetails(int tmdbId) async {
    developer.log(
      'Fetching TV show details',
      name: 'TMDBService',
      error: {'tmdbId': tmdbId},
    );
    
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tmdbId?append_to_response=external_ids,credits'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      String name = data['name'] ?? '';
      String originalName = name;
      
      if (name.isEmpty) {
        developer.log(
          'Empty name',
          name: 'TMDBService',
          error: {'tmdbId': tmdbId},
          level: 900,
        );
        throw Exception('No valid name found for TV show $tmdbId');
      }

      int? tvdbId;
      if (data['external_ids'] != null && data['external_ids']['tvdb_id'] != null) {
        tvdbId = data['external_ids']['tvdb_id'];
      }

      final List<Map<String, dynamic>> processedSeasons = [];
      final numberOfSeasons = data['number_of_seasons'] as int;
      
      developer.log(
        'Processing seasons',
        name: 'TMDBService',
        error: {
          'showName': name,
          'numberOfSeasons': numberOfSeasons,
        },
      );

      for (var seasonNum = 1; seasonNum <= numberOfSeasons; seasonNum++) {
        try {
          final seasonData = await getSeasonDetails(tmdbId, seasonNum);
          if (seasonData['episodes'] == null) continue;

          final List<Map<String, dynamic>> processedEpisodes = [];
          for (final episode in seasonData['episodes']) {
            processedEpisodes.add({
              'id': tmdbId,
              'tmdb_id': tmdbId,
              'show_id': tmdbId,
              'episode_number': episode['episode_number'],
              'name': episode['name'] ?? '',
              'overview': episode['overview'] ?? '',
              'still_path': episode['still_path'],
              'air_date': episode['air_date'],
              'runtime': episode['runtime'],
              'season_number': seasonNum,
            });
          }

          processedSeasons.add({
            'id': tmdbId,
            'tmdb_id': tmdbId,
            'show_id': tmdbId,
            'season_number': seasonNum,
            'name': seasonData['name'] ?? 'Season $seasonNum',
            'overview': seasonData['overview'] ?? '',
            'air_date': seasonData['air_date'],
            'poster_path': seasonData['poster_path'],
            'episodes': processedEpisodes,
          });

          developer.log(
            'Processed season',
            name: 'TMDBService',
            error: {
              'seasonNumber': seasonNum,
              'episodeCount': processedEpisodes.length,
            },
          );

          await Future.delayed(const Duration(milliseconds: 250));
        } catch (e) {
          developer.log(
            'Failed to process season',
            name: 'TMDBService',
            error: {
              'seasonNumber': seasonNum,
              'error': e.toString(),
            },
            level: 900,
          );
          continue;
        }
      }

      final showData = {
        'tmdb_id': tmdbId,
        'original_name': originalName,
        'name': name,
        'overview': data['overview'],
        'first_air_date': data['first_air_date'],
        'number_of_episodes': data['number_of_episodes'],
        'total_episodes_count': data['number_of_episodes'],
        'number_of_seasons': data['number_of_seasons'],
        'tvdb_id': tvdbId,
        'is_anime': 0,
        'seasons': processedSeasons,
        'cast': (data['credits']['cast'] as List?)
            ?.take(7)
            .map((actor) => {
                  'id': actor['id'],
                  'name': actor['name'],
                  'profile_path': actor['profile_path'],
                })
            .toList() ?? [],
        'last_updated': DateTime.now().toIso8601String(),
      };

      if (data['poster_path'] != null) {
        await downloadImage(
          data['poster_path'],
          'tv/posters',
          tmdbId.toString(),
        );
      }

      if (data['backdrop_path'] != null) {
        await downloadImage(
          data['backdrop_path'],
          'tv/backdrops',
          tmdbId.toString(),
        );
      }

      for (final actor in showData['cast']) {
        await downloadActorImage(actor);
      }

      developer.log(
        'Processed TV show data',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'name': name,
          'tvdbId': tvdbId,
          'seasonCount': processedSeasons.length,
          'totalEpisodes': data['number_of_episodes'],
        },
      );

      return showData;
    } else {
      developer.log(
        'Failed to fetch TV show details',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'statusCode': response.statusCode,
          'response': response.body,
        },
        level: 1000,
      );
      throw Exception('Failed to fetch TV show details');
    }
  }

  Future<Map<String, dynamic>> getSeasonDetails(int showId, int seasonNumber) async {
    developer.log(
      'Fetching season details',
      name: 'TMDBService',
      error: {'showId': showId, 'seasonNumber': seasonNumber},
    );
    
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$showId/season/$seasonNumber'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      developer.log(
        'Failed to fetch season details',
        name: 'TMDBService',
        error: {
          'showId': showId,
          'seasonNumber': seasonNumber,
          'statusCode': response.statusCode,
          'response': response.body,
        },
        level: 1000,
      );
      throw Exception('Failed to fetch season details');
    }
  }

  Future<String?> downloadImage(String path, String type, String id, [String imageType = 'poster']) async {
    return _downloadImage(path, type, id, imageType);
  }

  Future<String?> _downloadImage(String path, String type, String id, String imageType) async {
    if (path.isEmpty) return null;
    
    try {
      if (await _imageExists(type, id, imageType)) {
        developer.log(
          'Image already exists, skipping download',
          name: 'TMDBService',
          error: {
            'type': type,
            'id': id,
            'imageType': imageType,
          },
        );
        
        final metadataDir = Directory('/storage/emulated/0/Debrid_Player/metadata/$type/$id');
        final fileName = type == 'actors' 
            ? '$id.webp'
            : type.contains('backdrop') 
                ? 'backdrop.webp' 
                : 'poster.webp';
        return '${metadataDir.path}/$fileName';
      }

      final url = 'https://image.tmdb.org/t/p/original$path';
      
      developer.log(
        'Downloading image',
        name: 'TMDBService',
        error: {'url': url, 'type': type, 'id': id},
      );
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final metadataDir = Directory('/storage/emulated/0/Debrid_Player/metadata/$type/$id');
        await metadataDir.create(recursive: true);
        
        final fileName = type == 'actors' 
            ? '$id.webp'
            : type.contains('backdrop') 
                ? 'backdrop.webp' 
                : 'poster.webp';
            
        final file = File('${metadataDir.path}/$fileName');
        final compressedImage = await FlutterImageCompress.compressWithList(
          response.bodyBytes,
          format: CompressFormat.webp,
          quality: 75,
        );

        await file.writeAsBytes(compressedImage);
        
        developer.log(
          'Image downloaded and compressed',
          name: 'TMDBService',
          error: {
            'path': file.path,
            'originalSize': response.bodyBytes.length,
            'compressedSize': compressedImage.length,
          },
        );
        return file.path;
      } else {
        developer.log(
          'Failed to download image',
          name: 'TMDBService',
          error: {
            'url': url,
            'statusCode': response.statusCode,
          },
          level: 1000,
        );
        return null;
      }
    } catch (e, st) {
      developer.log(
        'Image download error',
        name: 'TMDBService',
        error: {'url': path, 'error': e.toString()},
        stackTrace: st,
        level: 1000,
      );
      return null;
    }
  }

  Future<void> downloadActorImage(Map<String, dynamic> actor) async {
    if (actor['profile_path'] == null) {
      developer.log(
        'Skipping actor image - no profile path',
        name: 'TMDBService',
        error: {'actorId': actor['id'], 'actorName': actor['name']},
      );
      return;
    }

    try {
      final actorImagesDir = Directory('/storage/emulated/0/Debrid_Player/metadata/actors');
      await actorImagesDir.create(recursive: true);
      
      final actorImageFile = File('${actorImagesDir.path}/${actor['id']}/${actor['id']}.webp');

      if (!await actorImageFile.exists()) {
        developer.log(
          'Downloading new actor image',
          name: 'TMDBService',
          error: {'actorName': actor['name'], 'profilePath': actor['profile_path']},
        );
        await downloadImage(
          actor['profile_path'],
          'actors',
          actor['id'].toString(),
        );
      } else {
        developer.log(
          'Actor image already exists',
          name: 'TMDBService',
          error: {'actorName': actor['name']},
        );
      }
    } catch (e, st) {
      developer.log(
        'Error downloading actor image',
        name: 'TMDBService',
        error: {'actorName': actor['name'], 'error': e.toString()},
        stackTrace: st,
        level: 900,
      );
    }
  }

  Future<Map<String, dynamic>> getCollectionDetails(int collectionId) async {
    developer.log(
      'Fetching collection details',
      name: 'TMDBService',
      error: {'collectionId': collectionId},
    );
    
    final response = await http.get(
      Uri.parse('$_baseUrl/collection/$collectionId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'collection_id': data['id'],
        'name': data['name'],
        'overview': data['overview'],
        'parts': (data['parts'] as List?)?.map((movie) => {
          'tmdb_id': movie['id'],
          'title': movie['title'],
          'release_date': movie['release_date'],
        }).toList() ?? [],
      };
    } else {
      developer.log(
        'Failed to fetch collection details',
        name: 'TMDBService',
        error: {
          'collectionId': collectionId,
          'statusCode': response.statusCode,
          'response': response.body,
        },
        level: 1000,
      );
      throw Exception('Failed to fetch collection details');
    }
  }

  Future<void> syncWithSimkl() async {
    if (_simklService == null) {
      developer.log(
        'SIMKL service is not available for sync',
        name: 'TMDBService',
        level: 900,
      );
      return;
    }
    
    final syncsBeforeDelete = 5;
    
    final existingMovieIds = await _databaseService.getMovieTmdbIds();
    final existingShowIds = await _databaseService.getTVShowTmdbIds();

    final simklMovies = await _simklService.getCompletedMovies();
    final simklShows = await _simklService.getCompletedTVShows();

    developer.log(
      'Starting sync check',
      name: 'TMDBService',
      error: {
        'existingMovies': existingMovieIds.length,
        'existingShows': existingShowIds.length,
        'simklMovies': simklMovies.length,
        'simklShows': simklShows.length,
      },
    );

    final simklMovieIds = simklMovies
        .where((m) => m['tmdb_id'] != null)
        .map((m) => m['tmdb_id'] as int)
        .toSet();
    final simklShowIds = simklShows
        .where((s) => s['tmdb_id'] != null)
        .map((s) => s['tmdb_id'] as int)
        .toSet();

    final markedMovies = await _databaseService.getItemsMarkedForDeletion('movie', 1);
    final markedShows = await _databaseService.getItemsMarkedForDeletion('tv', 1);

    developer.log(
      'Found marked items',
      name: 'TMDBService',
      error: {
        'markedMovies': markedMovies.length,
        'markedShows': markedShows.length,
      },
    );

    for (final movie in markedMovies) {
      final movieId = movie['tmdb_id'] as int;
      if (!simklMovieIds.contains(movieId)) {
        await _databaseService.incrementDeletionSync('movie', movieId);
        developer.log(
          'Incremented movie deletion counter',
          name: 'TMDBService',
          error: {
            'movieId': movieId,
            'title': movie['original_title'],
            'currentCount': movie['deletion_syncs'],
          },
        );
      }
    }

    for (final show in markedShows) {
      final showId = show['tmdb_id'] as int;
      if (!simklShowIds.contains(showId)) {
        await _databaseService.incrementDeletionSync('tv', showId);
        developer.log(
          'Incremented show deletion counter',
          name: 'TMDBService',
          error: {
            'showId': showId,
            'title': show['original_name'],
            'currentCount': show['deletion_syncs'],
          },
        );
      }
    }

    for (final movieId in existingMovieIds) {
      if (!simklMovieIds.contains(movieId)) {
        final isMarked = markedMovies.any((m) => m['tmdb_id'] == movieId);
        if (!isMarked) {
          await _databaseService.markForDeletion('movie', movieId);
          developer.log(
            'Marked movie for deletion',
            name: 'TMDBService',
            error: {'movieId': movieId},
          );
        }
      } else {
        await _databaseService.clearDeletionMark('movie', movieId);
      }
    }

    for (final showId in existingShowIds) {
      if (!simklShowIds.contains(showId)) {
        final isMarked = markedShows.any((s) => s['tmdb_id'] == showId);
        if (!isMarked) {
          await _databaseService.markForDeletion('tv', showId);
          developer.log(
            'Marked show for deletion',
            name: 'TMDBService',
            error: {'showId': showId},
          );
        }
      } else {
        await _databaseService.clearDeletionMark('tv', showId);
      }
    }

    final moviesToDelete = await _databaseService.getItemsMarkedForDeletion(
      'movie',
      syncsBeforeDelete,
    );
    final showsToDelete = await _databaseService.getItemsMarkedForDeletion(
      'tv',
      syncsBeforeDelete,
    );

    developer.log(
      'Found items ready for deletion',
      name: 'TMDBService',
      error: {
        'moviesToDelete': moviesToDelete.length,
        'showsToDelete': showsToDelete.length,
      },
    );

    for (final movie in moviesToDelete) {
      final movieId = movie['tmdb_id'] as int;
      await _databaseService.deleteMovie(movieId);
      developer.log(
        'Deleted movie after $syncsBeforeDelete syncs',
        name: 'TMDBService',
        error: {
          'movieId': movieId,
          'title': movie['original_title'],
          'syncCount': movie['deletion_syncs'],
        },
      );
    }

    for (final show in showsToDelete) {
      final showId = show['tmdb_id'] as int;
      await _databaseService.deleteShowData(showId);
      developer.log(
        'Deleted TV show after $syncsBeforeDelete syncs',
        name: 'TMDBService',
        error: {
          'showId': showId,
          'title': show['original_name'],
          'syncCount': show['deletion_syncs'],
        },
      );
    }
  }

  Future<void> syncWithTrakt(TraktSyncService traktService) async {
    if (traktService == null) {
      developer.log(
        'Trakt service is not available for sync',
        name: 'TMDBService',
        level: 900,
      );
      return;
    }
    
    final syncsBeforeDelete = 5;
    
    final existingMovieIds = await _databaseService.getMovieTmdbIds();
    final existingShowIds = await _databaseService.getTVShowTmdbIds();

    final traktMovies = await traktService.getCompletedMovies();
    final traktShows = await traktService.getCompletedTVShows();

    developer.log(
      'Starting Trakt sync check',
      name: 'TMDBService',
      error: {
        'existingMovies': existingMovieIds.length,
        'existingShows': existingShowIds.length,
        'traktMovies': traktMovies.length,
        'traktShows': traktShows.length,
      },
    );

    final traktMovieIds = traktMovies
        .where((m) => m['tmdb_id'] != null)
        .map((m) => m['tmdb_id'] as int)
        .toSet();
    final traktShowIds = traktShows
        .where((s) => s['tmdb_id'] != null)
        .map((s) => s['tmdb_id'] as int)
        .toSet();

    final markedMovies = await _databaseService.getItemsMarkedForDeletion('movie', 1);
    final markedShows = await _databaseService.getItemsMarkedForDeletion('tv', 1);

    developer.log(
      'Found marked items for Trakt sync',
      name: 'TMDBService',
      error: {
        'markedMovies': markedMovies.length,
        'markedShows': markedShows.length,
      },
    );

    for (final movie in markedMovies) {
      final movieId = movie['tmdb_id'] as int;
      if (!traktMovieIds.contains(movieId)) {
        await _databaseService.incrementDeletionSync('movie', movieId);
        developer.log(
          'Incremented movie deletion counter for Trakt',
          name: 'TMDBService',
          error: {
            'movieId': movieId,
            'title': movie['original_title'],
            'currentCount': movie['deletion_syncs'],
          },
        );
      }
    }

    for (final show in markedShows) {
      final showId = show['tmdb_id'] as int;
      if (!traktShowIds.contains(showId)) {
        await _databaseService.incrementDeletionSync('tv', showId);
        developer.log(
          'Incremented show deletion counter for Trakt',
          name: 'TMDBService',
          error: {
            'showId': showId,
            'title': show['original_name'],
            'currentCount': show['deletion_syncs'],
          },
        );
      }
    }

    for (final movieId in existingMovieIds) {
      if (!traktMovieIds.contains(movieId)) {
        final isMarked = markedMovies.any((m) => m['tmdb_id'] == movieId);
        if (!isMarked) {
          await _databaseService.markForDeletion('movie', movieId);
          developer.log(
            'Marked movie for deletion in Trakt sync',
            name: 'TMDBService',
            error: {'movieId': movieId},
          );
        }
      } else {
        await _databaseService.clearDeletionMark('movie', movieId);
      }
    }

    for (final showId in existingShowIds) {
      if (!traktShowIds.contains(showId)) {
        final isMarked = markedShows.any((s) => s['tmdb_id'] == showId);
        if (!isMarked) {
          await _databaseService.markForDeletion('tv', showId);
          developer.log(
            'Marked show for deletion in Trakt sync',
            name: 'TMDBService',
            error: {'showId': showId},
          );
        }
      } else {
        await _databaseService.clearDeletionMark('tv', showId);
      }
    }

    final moviesToDelete = await _databaseService.getItemsMarkedForDeletion(
      'movie',
      syncsBeforeDelete,
    );
    final showsToDelete = await _databaseService.getItemsMarkedForDeletion(
      'tv',
      syncsBeforeDelete,
    );

    developer.log(
      'Found items ready for deletion in Trakt sync',
      name: 'TMDBService',
      error: {
        'moviesToDelete': moviesToDelete.length,
        'showsToDelete': showsToDelete.length,
      },
    );

    for (final movie in moviesToDelete) {
      final movieId = movie['tmdb_id'] as int;
      await _databaseService.deleteMovie(movieId);
      developer.log(
        'Deleted movie after $syncsBeforeDelete Trakt syncs',
        name: 'TMDBService',
        error: {
          'movieId': movieId,
          'title': movie['original_title'],
          'syncCount': movie['deletion_syncs'],
        },
      );
    }

    for (final show in showsToDelete) {
      final showId = show['tmdb_id'] as int;
      await _databaseService.deleteShowData(showId);
      developer.log(
        'Deleted TV show after $syncsBeforeDelete Trakt syncs',
        name: 'TMDBService',
        error: {
          'showId': showId,
          'title': show['original_name'],
          'syncCount': show['deletion_syncs'],
        },
      );
    }
  }

  Future<Map<String, dynamic>> getTVShowDetails(int tmdbId) async {
    return fetchTVShowDetails(tmdbId);
  }

  Future<Map<String, dynamic>> fetchMovieDetails(int tmdbId) async {
    return await getMovieDetails(tmdbId);
  }

  Future<bool> _imageExists(String type, String id, String imageType) async {
    final metadataDir = Directory('/storage/emulated/0/Debrid_Player/metadata/$type/$id');
    final fileName = type == 'actors' 
        ? '$id.webp'
        : type.contains('backdrop') 
            ? 'backdrop.webp' 
            : 'poster.webp';
            
    final file = File('${metadataDir.path}/$fileName');
    return file.exists();
  }

  Future<Map<String, dynamic>> getEpisodeCount(int tmdbId) async {
    developer.log(
      'Fetching episode count',
      name: 'TMDBService',
      error: {'tmdbId': tmdbId},
    );
    
    final response = await http.get(
      Uri.parse('$_baseUrl/tv/$tmdbId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'number_of_episodes': data['number_of_episodes'],
      };
    } else {
      developer.log(
        'Failed to fetch episode count',
        name: 'TMDBService',
        error: {
          'tmdbId': tmdbId,
          'statusCode': response.statusCode,
          'response': response.body,
        },
        level: 1000,
      );
      throw Exception('Failed to fetch episode count');
    }
  }
} 