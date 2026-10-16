import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/svg_icon.dart';
import '../map/escora_map.dart';
import '../map/institution.dart';
import '../map/pins.dart';

/// Screen 4. Real map of Rio Preto: pins with "what's missing" chips pop
/// in one by one, then a loop highlights one place at a time with a card
/// and a route drawn from "você está aqui". The map drifts slowly, and
/// tapping a pin highlights it right away.
class WelcomeMapVisual extends StatefulWidget {
  const WelcomeMapVisual({super.key, required this.active});

  final bool active;

  @override
  State<WelcomeMapVisual> createState() => _WelcomeMapVisualState();
}

class _WelcomeMapVisualState extends State<WelcomeMapVisual> with TickerProviderStateMixin {
  final _map = MapController();
  final _places = sampleInstitutions(rioPreto);
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 28));
  late final AnimationController _route = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _ready = false;
  bool _started = false;
  int? _focus;
  int _tick = 0;
  Timer? _loop;
  DateTime _pausedUntil = DateTime(0);

  static const _zoom = 13.3;
  static const _cardWidth = 232.0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(WelcomeMapVisual old) {
    super.didUpdateWidget(old);
    if (widget.active && !_started) _start();
    if (widget.active) {
      _drift.repeat();
    } else {
      _drift.stop();
    }
  }

  void _start() {
    _started = true;
    _drift.repeat();
    // First highlight after every pin has landed.
    _loop = Timer.periodic(const Duration(milliseconds: 3400), (_) => _advance());
  }

  void _advance() {
    if (!mounted || !widget.active || !_ready || DateTime.now().isBefore(_pausedUntil)) return;
    _tick++;
    // Only highlight places whose card fits on screen.
    final cam = _map.camera;
    // Visible box: the map is drawn with an overscan margin around it.
    final size = Size(cam.nonRotatedSize.width - mapOverscan * 2, cam.nonRotatedSize.height - mapOverscan * 2);
    const halfW = _cardWidth / 2;
    final fits = [
      for (var i = 0; i < _places.length; i++)
        if (i != _focus)
          if (cam.latLngToScreenOffset(_places[i].point) - _shift case final p
              when p.dx > halfW - 24 && p.dx < size.width - halfW + 24 && p.dy > 190 && p.dy < size.height - 70)
            i,
    ];
    if (fits.isEmpty) return;
    _select(fits[_tick % fits.length]);
  }

  /// Where the overscanned map currently sits, relative to the visible box.
  Offset get _shift => const Offset(mapOverscan, mapOverscan) - mapDrift(_drift.value);

  void _select(int? i) {
    setState(() => _focus = i);
    if (i != null) _route.forward(from: 0);
  }

  void _tap(int i) {
    _pausedUntil = DateTime.now().add(const Duration(seconds: 6));
    _select(_focus == i ? null : i);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _drift.dispose();
    _route.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = [
      for (var i = 0; i < _places.length; i++)
        if (i != _focus) i,
      ?_focus,
    ];
    final focus = _focus;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -mapOverscan,
                top: -mapOverscan,
                right: -mapOverscan,
                bottom: -mapOverscan,
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, child) => Transform.translate(offset: mapDrift(_drift.value), child: child),
                  child: RepaintBoundary(
                    child: EscoraMap(
                      controller: _map,
                      initialZoom: _zoom,
                      interactive: false,
                      onReady: () => _ready = true,
                      children: [
                        if (_started && focus != null)
                          AnimatedBuilder(
                            animation: _route,
                            builder: (context, _) => PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints(
                                    rioPreto,
                                    _places[focus].point,
                                    AppMotion.smooth.transform(_route.value),
                                  ),
                                  strokeWidth: 4,
                                  color: AppColors.terracota600,
                                  borderStrokeWidth: 2.5,
                                  borderColor: AppColors.white,
                                  strokeCap: StrokeCap.round,
                                ),
                              ],
                            ),
                          ),
                        if (_started)
                          MarkerLayer(
                            markers: [
                              const Marker(
                                point: rioPreto,
                                width: 72,
                                height: 72,
                                child: PopIn(child: UserDot()),
                              ),
                              for (final i in order)
                                Marker(
                                  key: ValueKey(i),
                                  point: _places[i].point,
                                  width: 130,
                                  height: 66,
                                  alignment: Marker.computePixelAlignment(
                                    width: 130,
                                    height: 66,
                                    left: 65,
                                    top: PlacePin.size / 2 + 1.5,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 1.5),
                                    child: PopIn(
                                      delay: Duration(milliseconds: 250 + 110 * i),
                                      alignment: Alignment.topCenter,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: GestureDetector(
                                          onTap: () => _tap(i),
                                          child: PlacePin(
                                            icon: _places[i].kind.icon,
                                            color: AppColors.terracota600,
                                            label: _places[i].tag,
                                            selected: _focus == i,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        // Cards sit in their own layer so they always cover every pin.
                        if (_started)
                          IgnorePointer(
                            child: MarkerLayer(
                              markers: [
                                for (var i = 0; i < _places.length; i++)
                                  Marker(
                                    point: _places[i].point,
                                    width: _cardWidth + 24,
                                    height: 200,
                                    alignment: Alignment.topCenter,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: PlacePin.size / 2 + 10),
                                        child: AnimatedSwitcher(
                                          duration: AppMotion.slow,
                                          switchInCurve: AppMotion.pop,
                                          switchOutCurve: Curves.easeInCubic,
                                          transitionBuilder: (child, a) => FadeTransition(
                                            opacity: a,
                                            child: ScaleTransition(
                                              scale: a,
                                              alignment: Alignment.bottomCenter,
                                              child: child,
                                            ),
                                          ),
                                          child: _focus == i
                                              ? _PlaceCard(place: _places[i], key: ValueKey('card$i'))
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Soft white at the top so the progress bar reads over the map.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .22],
                colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
        ),
        // White fade into the content panel (Figma "Rectangle" gradient).
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [.8, 1],
                colors: [Color(0x00FFFFFF), AppColors.white],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gentle curve from [a] to [b], cut at [t] so it can be drawn in.
List<LatLng> _routePoints(LatLng a, LatLng b, double t) {
  final dLat = b.latitude - a.latitude;
  final dLng = b.longitude - a.longitude;
  // Control point pushed sideways from the midpoint.
  final c = LatLng(a.latitude + dLat / 2 - dLng * .25, a.longitude + dLng / 2 + dLat * .25);
  const steps = 40;
  final n = (steps * t).ceil();
  return [
    for (var k = 0; k <= n; k++)
      if (math.min(k / steps, t) case final u)
        LatLng(
          (1 - u) * (1 - u) * a.latitude + 2 * (1 - u) * u * c.latitude + u * u * b.latitude,
          (1 - u) * (1 - u) * a.longitude + 2 * (1 - u) * u * c.longitude + u * u * b.longitude,
        ),
  ];
}

/// Floating card for the highlighted place: who, how far, what's missing
/// and how much of the goal is already covered.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({super.key, required this.place});

  final Institution place;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _WelcomeMapVisualState._cardWidth,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .16), blurRadius: 28, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.terracota600, shape: BoxShape.circle),
                    child: SvgIcon(place.kind.icon, size: 17, color: AppColors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: AppType.cardTitle(size: 13.5, color: AppColors.cinza900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              formatKm(place.kmFrom(rioPreto)),
                              style: AppType.body(size: 11, color: AppColors.cinza500).copyWith(height: 1),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.terracota50,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                place.primaryType.label,
                                style: AppType.strong(size: 10, color: AppColors.terracota600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                place.need,
                style: AppType.body(size: 11.5, color: AppColors.cinza700).copyWith(height: 1.35),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: place.progress),
                duration: const Duration(milliseconds: 1100),
                curve: AppMotion.smooth,
                builder: (context, v, _) => Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          color: AppColors.terracota600,
                          backgroundColor: AppColors.cinza100,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(v * 100).round()}% da meta', style: AppType.strong(size: 10, color: AppColors.cinza700)),
                  ],
                ),
              ),
            ],
          ),
        ),
        CustomPaint(size: const Size(16, 8), painter: _StemPainter()),
      ],
    );
  }
}

/// Little triangle that points the card at its pin.
class _StemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_StemPainter old) => false;
}
