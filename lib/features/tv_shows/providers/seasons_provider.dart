import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/season.dart';
import '../../database/providers/database_provider.dart';

part 'seasons_provider.g.dart';

@Riverpod(keepAlive: true)
class Seasons extends _$Seasons {
  @override
  Future<List<Season>> build(int showId) async {
    final db = ref.watch(databaseServiceProvider);
    final seasons = await db.getSeasonsForShow(showId);
    return seasons.map((map) => Season.fromMap(map)).toList();
  }
}

@Riverpod(keepAlive: true)
class SelectedSeason extends _$SelectedSeason {
  @override
  Season? build() => null;

  void select(Season season) => state = season;
} 