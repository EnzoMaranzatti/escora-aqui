import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../core/assets.dart';

/// Free vector tiles from OpenFreeMap (OpenStreetMap data, no API key,
/// no usage limits), drawn with our own brand style in
/// `assets/map/escora_style.json`.
class MapTiles {
  MapTiles._(this.theme, this.providers);

  final vtr.Theme theme;
  final TileProviders providers;

  static const _tileJson = 'https://tiles.openfreemap.org/planet';

  /// Used if the TileJSON lookup fails. OpenFreeMap publishes dated
  /// snapshots; the TileJSON always points to the newest one.
  static const _fallbackTiles = 'https://tiles.openfreemap.org/planet/20261004_113936_pt/{z}/{x}/{y}.pbf';

  static Future<MapTiles>? _cache;

  static Future<MapTiles> load() => _cache ??= _load();

  static Future<MapTiles> _load() async {
    final style = jsonDecode(await rootBundle.loadString(MapAssets.style)) as Map<String, dynamic>;
    final theme = vtr.ThemeReader().read(style);

    var url = _fallbackTiles;
    try {
      final res = await http.get(Uri.parse(_tileJson)).timeout(const Duration(seconds: 6));
      final tiles = (jsonDecode(res.body) as Map<String, dynamic>)['tiles'] as List;
      url = tiles.first as String;
    } catch (_) {
      // Keep the fallback snapshot.
    }

    return MapTiles._(
      theme,
      TileProviders({'openmaptiles': NetworkVectorTileProvider(urlTemplate: url, maximumZoom: 14)}),
    );
  }
}
