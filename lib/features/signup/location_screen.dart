import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/step_progress.dart';
import '../../core/widgets/svg_icon.dart';
import '../map/escora_map.dart';
import '../map/institution.dart';
import '../map/pins.dart';
import '../onboarding/onboarding_state.dart';
import 'city_sheet.dart';
import 'help_type_screen.dart';
import 'places_service.dart';

/// Screens 7 and 8 (step 1 of 5).
///
/// Before locating, the map scans Rio Preto: a radar pulse loops at the
/// center and the "you" pin hops. After "Usar minha localização" (or a
/// city picked in the sheet), the camera flies there, the radius opens
/// and nearby institutions pop in with their distance.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with TickerProviderStateMixin {
  final _map = MapController();
  late final _mover = MapMover(_map, this);
  late final AnimationController _radius = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  late final AnimationController _drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 30));

  static const _radiusMeters = 2600.0;

  bool _locating = false;

  /// Completes once FlutterMap has rendered and the controller is usable.
  final _mapReady = Completer<void>();
  LatLng? _here;

  /// The camera reached [_here] and the pin has dropped onto it.
  bool _landed = false;
  List<Institution> _near = const [];

  int? _selected;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final saved = onboarding.position;
    if (saved != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPlace(saved));
    } else {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _mover.dispose();
    _radius.dispose();
    _float.dispose();
    _sweep.dispose();
    _drop.dispose();
    _drift.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() {
      _locating = true;
      _notice = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fail('Não encontramos sua localização agora. Escolha sua cidade na lista para continuar.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        await _chooseCity(denied: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      final (city, uf) = await PlacesService.describe(p);
      onboarding.setPlace(city: city, uf: uf, position: p, fromGps: true);
      if (!mounted) return;
      setState(() => _locating = false);
      HapticFeedback.mediumImpact();
      await _showPlace(p);
    } catch (_) {
      _fail('Não encontramos sua localização agora. Escolha sua cidade na lista para continuar.');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _locating = false;
      _notice = msg;
    });
  }

  Future<void> _chooseCity({bool denied = false}) async {
    final r = await showCitySheet(context, permissionDenied: denied);
    if (!mounted || r == null) return;
    switch (r) {
      case UseMyLocation():
        await _useLocation();
      case PickedCity(:final city, :final uf, :final point):
        onboarding.setPlace(city: city, uf: uf, position: point, fromGps: false);
        await _showPlace(point);
    }
  }

  Future<void> _showPlace(LatLng p) async {
    final all = sampleInstitutions(p)..sort((a, b) => a.kmFrom(p).compareTo(b.kmFrom(p)));
    setState(() {
      _here = p;
      _landed = false;
      _near = [];
      _selected = null;
      _notice = null;
    });
    _radius.value = 0;
    await _mapReady.future;
    if (!mounted) return;
    await _mover.flyTo(p, 13.2);
    if (!mounted) return;
    _drift.stop();
    setState(() => _landed = true);
    _drop.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _radius.forward();
    setState(() => _near = all.where((i) => i.kmFrom(p) * 1000 <= _radiusMeters * 1.3).toList());
  }

  void _continue() => context.push(const HelpTypeScreen());

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final located = _here != null;
    final city = onboarding.city;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxHeight < 740;
            final mapH = box.maxHeight * (compact ? 380 : 428) / 844;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: mapH + 24,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -mapOverscan,
                          top: -mapOverscan,
                          right: -mapOverscan,
                          bottom: -mapOverscan,
                          // While searching, the rendered map wanders slowly;
                          // once located it eases back to rest.
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: located ? 0 : 1),
                            duration: AppMotion.slow,
                            curve: AppMotion.smooth,
                            builder: (context, amp, child) => AnimatedBuilder(
                              animation: _drift,
                              builder: (context, child) =>
                                  Transform.translate(offset: mapDrift(_drift.value) * amp, child: child),
                              child: child,
                            ),
                            child: RepaintBoundary(child: _buildMap(located)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: mapH - 60,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00FFFFFF), AppColors.white],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: mapH,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: AppColors.white,
                    padding: EdgeInsets.fromLTRB(16, compact ? 20 : 32, 16, AppSpacing.bottom + pad.bottom),
                    child: Column(
                      children: [
                        const Spacer(),
                        SwapText(
                          located ? 'Você está em $city?' : 'Onde você está localizado?',
                          style: AppType.display(size: compact ? 26 : 32),
                        ),
                        const SizedBox(height: 8),
                        SwapText(
                          _notice ??
                              (located
                                  ? (_near.isEmpty
                                        ? 'Preparando tudo para você'
                                        : '${_near.length} pontos de apoio perto de você')
                                  : 'Usamos sua localização só para mostrar os pontos mais perto. Você pode trocar a cidade quando quiser.'),
                          style: AppType.body(
                            color: _notice != null ? AppColors.erroTexto : AppColors.cinza600,
                            size: compact ? 15 : 16,
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: located ? 'Continuar' : 'Usar minha localização',
                          icon: located ? Ic.arrowRight : Ic.pinWhite,
                          loading: _locating,
                          onPressed: located ? _continue : _useLocation,
                        ),
                        const SizedBox(height: 6),
                        GhostButton(
                          label: located ? 'Trocar cidade' : 'Escolher cidade',
                          icon: Ic.mapPin,
                          onPressed: _chooseCity,
                        ),
                      ],
                    ),
                  ),
                ),
                // Soft white at the top so the progress bar reads over the map.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: pad.top + 90,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: pad.top + 6,
                  left: 16,
                  right: 16,
                  child: TweenAnimationBuilder<double>(
                    // Step 1 of 5: the first segment fills on arrival.
                    tween: Tween(begin: -1, end: 0),
                    duration: const Duration(milliseconds: 900),
                    curve: AppMotion.smooth,
                    builder: (context, v, _) => SegmentProgress(
                      count: StepProgress.steps,
                      position: v,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(bool located) {
    final here = _here ?? rioPreto;
    return EscoraMap(
      controller: _map,
      initialZoom: 12.4,
      interactive: _landed,
      onReady: () {
        if (!_mapReady.isCompleted) _mapReady.complete();
      },
      onTap: () => setState(() => _selected = null),
      children: [
        if (located)
          AnimatedBuilder(
            animation: _radius,
            builder: (context, _) {
              final r = AppMotion.smooth.transform(_radius.value) * _radiusMeters;
              return CircleLayer(
                circles: [
                  CircleMarker(
                    point: here,
                    radius: r,
                    useRadiusInMeter: true,
                    color: AppColors.petroleo500.withValues(alpha: .08),
                    borderColor: AppColors.petroleo300,
                    borderStrokeWidth: 1.2,
                  ),
                ],
              );
            },
          ),
        MarkerLayer(
          markers: [
            // Radar sweep while searching; fades out once the pin lands.
            Marker(
              point: here,
              width: 260,
              height: 260,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _landed ? 0 : 1,
                  duration: AppMotion.slow,
                  child: _Radar(sweep: _sweep),
                ),
              ),
            ),
            for (final (i, place) in _near.indexed)
              Marker(
                key: ValueKey(place.name),
                point: place.point,
                width: 220,
                height: 66,
                alignment: Marker.computePixelAlignment(
                  width: 220,
                  height: 66,
                  left: 110,
                  top: PlacePin.size / 2 + 1.5,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 1.5),
                  child: PopIn(
                    delay: Duration(milliseconds: 250 + 120 * i),
                    alignment: Alignment.topCenter,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = _selected == i ? null : i),
                        child: PlacePin(
                          icon: place.kind.icon,
                          color: AppColors.terracota600,
                          label: _selected == i ? place.name : formatKm(place.kmFrom(here)),
                          selected: _selected == i,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Marker(
              point: here,
              width: 160,
              height: 120,
              alignment: Marker.computePixelAlignment(width: 160, height: 120, left: 80, top: 117),
              child: IgnorePointer(
                child: _YouPin(float: _float, drop: _drop, landed: _landed),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rotating radar sweep with a faint ring, drawn around the "you" pin.
class _Radar extends StatelessWidget {
  const _Radar({required this.sweep});

  final Animation<double> sweep;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sweep,
      builder: (context, _) => CustomPaint(painter: _RadarPainter(sweep.value)),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = AppColors.petroleo500.withValues(alpha: .06));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.petroleo300.withValues(alpha: .6),
    );
    canvas.drawCircle(
      c,
      r * .55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.petroleo300.withValues(alpha: .35),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    final start = t * 2 * math.pi;
    canvas.drawArc(
      rect,
      start - 1.1,
      1.1,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 1.1,
          colors: [AppColors.petroleo500.withValues(alpha: 0), AppColors.petroleo500.withValues(alpha: .22)],
          transform: GradientRotation(start - 1.1),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

/// Petróleo location pin. Floats softly while we look for the user, then
/// drops onto the spot with a small bounce and a ripple.
class _YouPin extends StatelessWidget {
  const _YouPin({required this.float, required this.drop, required this.landed});

  final Animation<double> float;
  final Animation<double> drop;
  final bool landed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([float, drop]),
      builder: (context, _) {
        // Height above the ground, in points.
        final double h;
        if (landed) {
          h = 14 * (1 - Curves.bounceOut.transform(drop.value));
        } else {
          h = 10 + 5 * math.sin(float.value * 2 * math.pi);
        }
        final air = (h / 15).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            if (landed) const Positioned(bottom: -38, child: Pulse(color: AppColors.petroleo500, size: 96)),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Once landed, the title already asks it; the chip steps aside.
                AnimatedOpacity(
                  opacity: landed ? 0 : 1,
                  duration: AppMotion.medium,
                  child: Transform.translate(
                    offset: Offset(0, -h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cinza900.withValues(alpha: .12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text('Você está aqui?', style: AppType.strong(size: 11, color: AppColors.cinza800)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Transform.translate(offset: Offset(0, -h), child: const SvgIcon(Ic.pinUser, size: 34)),
                // Contact shadow shrinks and fades while the pin is in the air.
                Container(
                  width: 16 - 8 * air,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.cinza900.withValues(alpha: .22 - .12 * air),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
