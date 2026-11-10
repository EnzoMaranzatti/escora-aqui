import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// O caminho entre a pessoa e um ponto de apoio: o traçado para desenhar no
/// mapa, mais a distância e o tempo para escrever na tela.
class Trip {
  const Trip({required this.points, required this.km, required this.minutes, required this.real});

  final List<LatLng> points;
  final double km;
  final int minutes;

  /// `false` quando o serviço de rotas não respondeu: aí o traçado é a linha
  /// reta entre os dois lugares e o mapa a desenha pontilhada, para ninguém
  /// confundir com uma rota de verdade.
  final bool real;

  String get label => real
      ? '$minutes min de carro · ${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km'
      : 'em linha reta · ${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}

/// Rotas pelo OSRM público (gratuito, sem chave, mesmos dados do
/// OpenStreetMap que o mapa já usa). Só vão as duas coordenadas da viagem:
/// nenhum dado da conta sai daqui. Se o serviço falhar ou o telefone estiver
/// sem internet, devolvemos a linha reta — a tela nunca fica sem resposta.
abstract final class TripService {
  static const _base = 'https://router.project-osrm.org/route/v1/driving';
  static const _distance = Distance();
  static final _cache = <String, Trip>{};

  /// Velocidade média de cidade, para estimar o tempo quando não há rota.
  static const _kmPerHour = 22;

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(3)},${a.longitude.toStringAsFixed(3)}'
      '>${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  static Trip? cached(LatLng from, LatLng dest) => _cache[_key(from, dest)];

  static Future<Trip> between(LatLng from, LatLng dest) async {
    final key = _key(from, dest);
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final url = Uri.parse(
        '$_base/${from.longitude},${from.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 7));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) throw const FormatException('sem rota');
      final route = routes.first as Map<String, dynamic>;
      final coords = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      final points = <LatLng>[];
      for (final c in coords) {
        final pair = c as List;
        points.add(LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()));
      }
      if (points.length < 2) throw const FormatException('traçado curto');
      return _cache[key] = Trip(
        points: points,
        km: (route['distance'] as num) / 1000,
        minutes: ((route['duration'] as num) / 60).ceil().clamp(1, 999),
        real: true,
      );
    } catch (_) {
      return _cache[key] = _straight(from, dest);
    }
  }

  static Trip _straight(LatLng from, LatLng dest) {
    final km = _distance.as(LengthUnit.Kilometer, from, dest);
    return Trip(points: [from, dest], km: km, minutes: (km / _kmPerHour * 60).ceil().clamp(1, 999), real: false);
  }
}
