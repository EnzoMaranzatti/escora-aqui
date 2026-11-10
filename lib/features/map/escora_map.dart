import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../core/theme/app_motion.dart';
import 'map_tiles.dart';

/// São José do Rio Preto — the pilot region.
const rioPreto = LatLng(-20.8113, -49.3758);

const mapBackground = Color(0xFFF4F1EC);

/// Map with the brand vector style. Tiles fade in once loaded; until then
/// (or offline) the warm background still shows the pins on top.
class EscoraMap extends StatelessWidget {
  const EscoraMap({
    super.key,
    required this.controller,
    this.initialCenter = rioPreto,
    this.initialZoom = 13,
    this.interactive = true,
    this.children = const [],
    this.onTap,
    this.onReady,
    this.onMoved,
    this.onGesture,
  });

  final MapController controller;
  final LatLng initialCenter;
  final double initialZoom;
  final bool interactive;
  final List<Widget> children;
  final VoidCallback? onTap;

  /// Called once the [controller] can be used.
  final VoidCallback? onReady;

  /// Camera moved (by gesture or code).
  final void Function(LatLng center, double zoom)? onMoved;

  /// A pessoa está mexendo no mapa com o dedo (arrastar ou pinçar). Serve
  /// para a tela sair da frente enquanto ela explora.
  final VoidCallback? onGesture;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: mapBackground,
        onTap: onTap == null ? null : (_, _) => onTap!(),
        onMapReady: onReady,
        onPositionChanged: onMoved == null && onGesture == null
            ? null
            : (cam, byHand) {
                onMoved?.call(cam.center, cam.zoom);
                if (byHand) onGesture?.call();
              },
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
      ),
      // Tiles in their own layer: animated pins on top don't repaint them.
      children: [
        const RepaintBoundary(child: _Tiles()),
        ...children,
      ],
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapTiles>(
      future: MapTiles.load(),
      builder: (context, snap) {
        final tiles = snap.data;
        return AnimatedOpacity(
          opacity: tiles == null ? 0 : 1,
          duration: AppMotion.slow,
          child: tiles == null
              ? const SizedBox.expand()
              : VectorTileLayer(
                  theme: tiles.theme,
                  tileProviders: tiles.providers,
                  maximumZoom: 18,
                  fileCacheTtl: const Duration(days: 14),
                ),
        );
      },
    );
  }
}

/// Slow figure-eight used to make a static map feel alive. Applied as a
/// translation of an overscanned, already rendered map instead of moving
/// the camera, so the vector tiles aren't redrawn every frame.
Offset mapDrift(double t, {double amp = 22}) {
  final a = t * 2 * math.pi;
  return Offset(amp * math.sin(2 * a) / 2, amp * .7 * math.sin(a));
}

/// Extra map drawn around the visible box so [mapDrift] never shows an edge.
const mapOverscan = 32.0;

/// Smooth camera moves for [MapController] (flutter_map only jumps).
/// Uses a "fly" arc: zooms out a little midway when travelling far.
class MapMover {
  MapMover(this.controller, TickerProvider vsync)
    : _c = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 1600));

  final MapController controller;
  final AnimationController _c;

  /// [offset] desloca o alvo na tela: `Offset(0, -100)` faz o ponto parar
  /// cem pixels acima do centro, que é onde sobra mapa quando há um cartão
  /// em cima da metade de baixo.
  Future<void> flyTo(
    LatLng dest,
    double zoom, {
    Duration? duration,
    Curve curve = AppMotion.glide,
    Offset offset = Offset.zero,
  }) async {
    final cam = controller.camera;
    final from = cam.center;
    final z0 = cam.zoom;
    final km = const Distance().as(LengthUnit.Kilometer, from, dest);
    final arc = (math.log(km + 1) / math.ln10 * .9).clamp(0.0, 3.0);

    _c.duration = duration ?? Duration(milliseconds: (900 + arc * 450).round());
    void tick() {
      final t = curve.transform(_c.value);
      final lat = from.latitude + (dest.latitude - from.latitude) * t;
      final lng = from.longitude + (dest.longitude - from.longitude) * t;
      final z = z0 + (zoom - z0) * t - arc * math.sin(math.pi * t);
      // O deslocamento entra junto com a viagem: aplicado de uma vez, o
      // primeiro quadro daria um salto.
      controller.move(LatLng(lat, lng), z, offset: offset * t);
    }

    _c.addListener(tick);
    try {
      await _c.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Interrupted by a newer move.
    } finally {
      _c.removeListener(tick);
    }
  }

  /// Corta a viagem em andamento. Sem isto, um `fitCamera` disparado no meio
  /// de um voo é desfeito pelo quadro seguinte da animação.
  void stop() => _c.stop();

  void dispose() => _c.dispose();
}
