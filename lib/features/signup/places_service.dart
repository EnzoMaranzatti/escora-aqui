import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class BrState {
  const BrState(this.uf, this.name);

  final String uf;
  final String name;
}

/// States and cities from IBGE's public API (free, no key), plus
/// geocoding through the phone's native geocoder (also free).
abstract final class PlacesService {
  static const _base = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  static final _geocoder = Geocoding();
  static List<BrState>? _states;
  static final _cities = <String, List<String>>{};

  /// Offline fallback: the pilot region.
  static const _pilot = ['Bady Bassitt', 'Cedral', 'Mirassol', 'São José do Rio Preto'];

  static Future<List<BrState>> states() async {
    if (_states != null) return _states!;
    try {
      final res = await http.get(Uri.parse('$_base/estados?orderBy=nome')).timeout(const Duration(seconds: 8));
      final list = jsonDecode(res.body) as List;
      return _states = [for (final s in list) BrState(s['sigla'] as String, s['nome'] as String)];
    } catch (_) {
      return const [BrState('SP', 'São Paulo')];
    }
  }

  static Future<List<String>> cities(String uf) async {
    if (_cities[uf] != null) return _cities[uf]!;
    try {
      final res = await http
          .get(Uri.parse('$_base/estados/$uf/municipios?orderBy=nome'))
          .timeout(const Duration(seconds: 8));
      final list = jsonDecode(res.body) as List;
      return _cities[uf] = [for (final c in list) c['nome'] as String];
    } catch (_) {
      return uf == 'SP' ? _pilot : const [];
    }
  }

  static Future<LatLng?> locate(String city, String uf) async {
    try {
      final r = await _geocoder.locationFromAddress('$city, $uf, Brasil');
      if (r.isEmpty) return null;
      return LatLng(r.first.latitude, r.first.longitude);
    } catch (_) {
      return null;
    }
  }

  /// City name and UF for a coordinate, best effort.
  static Future<(String city, String? uf)> describe(LatLng p) async {
    try {
      final r = await _geocoder.placemarkFromCoordinates(p.latitude, p.longitude);
      if (r.isNotEmpty) {
        final m = r.first;
        final city = [
          m.subAdministrativeArea,
          m.locality,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).firstOrNull;
        if (city != null) return (city, _uf(m.administrativeArea));
      }
    } catch (_) {}
    return ('sua região', null);
  }

  static String? _uf(String? area) {
    if (area == null) return null;
    if (area.length == 2) return area.toUpperCase();
    final match = _states?.where((s) => s.name == area);
    return (match == null || match.isEmpty) ? null : match.first.uf;
  }
}
