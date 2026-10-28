import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../map/escora_map.dart';
import '../map/map_tiles.dart';
import '../map/pins.dart';
import '../institution/register/register_flow.dart';
import '../place/place_screen.dart';
import '../shared/help_ui.dart';
import '../signup/places_service.dart';

/// Tab "Mapa": verified points near the person, already filtered by the
/// onboarding choices. Reopens on the last position and filters.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static bool _tipSeen = false;
  static bool _welcomed = false;
  static bool _listMode = false;
  static bool _gpsClosed = false;

  final _map = MapController();
  late final _mover = MapMover(_map, this);
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  Place? _selected;
  bool _banner = !_welcomed;
  bool _tip = !_tipSeen;
  bool _emptyClosed = false;
  bool _slowLoad = false;
  bool _offline = false;
  bool _locating = false;
  Timer? _offlineTimer;

  LatLng get _here => onboarding.position ?? store.center;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    _search.addListener(() => setState(() {}));
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus && !_listMode) setState(() => _listMode = true);
    });
    _welcomed = true;
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) setState(() => _banner = false);
    });
    // "Buscando pontos…" only if the map takes more than a second.
    var loaded = false;
    MapTiles.load().whenComplete(() {
      loaded = true;
      if (mounted && _slowLoad) setState(() => _slowLoad = false);
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !loaded) setState(() => _slowLoad = true);
    });
    _checkConnection();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _offlineTimer?.cancel();
    _mover.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    if (_selected != null && !_selected!.onMap) _selected = null;
    setState(() {});
  }

  Future<void> _checkConnection() async {
    var ok = true;
    try {
      final r = await InternetAddress.lookup('tiles.openfreemap.org').timeout(const Duration(seconds: 4));
      ok = r.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _offline = !ok);
    _offlineTimer?.cancel();
    // While offline, try again by itself ("atualizamos sozinhos").
    if (!ok) _offlineTimer = Timer(const Duration(seconds: 8), _checkConnection);
  }

  // ── Filtering ─────────────────────────────────────────────
  bool get _filtered => store.filterTypes.isNotEmpty || store.filterCauses.isNotEmpty;

  List<Place> _nearby() => store.verifiedPlaces.where((p) => p.kmFrom(_here) <= store.radiusKm).toList();

  List<Place> get _visible {
    final types = store.filterTypes;
    final causes = store.filterCauses;
    final list = _nearby().where((p) {
      final pt = p.activeTypes.isEmpty ? p.accepts : p.activeTypes;
      if (types.isNotEmpty && !pt.any(types.contains)) return false;
      if (causes.isNotEmpty && !p.causes.any(causes.contains)) return false;
      return true;
    }).toList();
    final q = Fmt.fold(_search.text.trim());
    if (q.isNotEmpty) {
      list.retainWhere(
        (p) =>
            Fmt.fold(p.name).contains(q) ||
            p.causes.any((c) => Fmt.fold(c).contains(q)) ||
            Fmt.fold(p.typeLabel).contains(q) ||
            p.openGoals.any((g) => Fmt.fold(g.quantity).contains(q)),
      );
    }
    list.sort((a, b) => a.kmFrom(_here).compareTo(b.kmFrom(_here)));
    return list;
  }

  void _toggleType(HelpType t) {
    store.filterTypes.contains(t) ? store.filterTypes.remove(t) : store.filterTypes.add(t);
    _afterFilter();
  }

  void _afterFilter() {
    _emptyClosed = false;
    if (_selected != null && !_visible.contains(_selected)) _selected = null;
    store.touch();
  }

  void _clearFilters() {
    store.filterTypes.clear();
    store.filterCauses.clear();
    _afterFilter();
  }

  void _widen() {
    const steps = [5.0, 10.0, 20.0, 50.0];
    store.radiusKm = steps.firstWhere((s) => s > store.radiusKm, orElse: () => store.radiusKm * 2);
    _mover.flyTo(_here, store.radiusKm >= 20 ? 11 : 12.4);
    store.touch();
  }

  Future<void> _pickCauses() async {
    await showAppSheet<void>(context, builder: (_) => const _CausesSheet());
    _afterFilter();
  }

  void _select(Place p) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = p;
      _tip = false;
      _tipSeen = true;
    });
    if (!_listMode) {
      _mover.flyTo(
        p.point,
        _map.camera.zoom.clamp(14, 16),
        duration: const Duration(milliseconds: 700),
        curve: AppMotion.smooth,
      );
    }
  }

  Future<void> _enableLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      final (city, uf) = await PlacesService.describe(p);
      onboarding.setPlace(city: city, uf: uf, position: p, fromGps: true);
      if (mounted) _mover.flyTo(p, 13.6);
    } catch (_) {
      // Keep the city center.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final visible = _visible;
    final searching = _search.text.trim().isNotEmpty;
    final noResults = visible.isEmpty && !searching && (_filtered || _nearby().isEmpty);
    final tipTarget = visible.isEmpty ? null : visible.first;
    final bottomBar = pad.bottom + 86;

    final banners = <Widget>[
      if (_offline)
        NoticeBanner(
          key: const ValueKey('offline'),
          tone: Tone.neutral,
          icon: PhosphorIconsRegular.wifiSlash,
          title: 'Você está sem internet.',
          text: 'O mapa pode estar desatualizado. Quando a conexão voltar, atualizamos sozinhos.',
          action: 'Tentar de novo',
          onAction: _checkConnection,
          elevated: true,
        )
      else if (!onboarding.fromGps && !_gpsClosed)
        NoticeBanner(
          key: const ValueKey('gps'),
          tone: Tone.info,
          icon: PhosphorIconsRegular.navigationArrow,
          text: 'Sua localização está desligada. Mostrando pontos de ${onboarding.city ?? 'São José do Rio Preto'}.',
          action: _locating ? 'Ativando…' : 'Ativar localização',
          onAction: _locating ? null : _enableLocation,
          onClose: () => setState(() => _gpsClosed = true),
          elevated: true,
        )
      else if (_banner)
        _Welcome(name: store.name, onClose: () => setState(() => _banner = false)),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: EscoraMap(
              controller: _map,
              initialCenter: store.mapCenter ?? _here,
              initialZoom: store.mapZoom ?? 13.4,
              onMoved: (c, z) {
                store.mapCenter = c;
                store.mapZoom = z;
              },
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() => _selected = null);
              },
              children: [
                MarkerLayer(
                  markers: [
                    Marker(point: _here, width: 80, height: 80, child: const UserDot()),
                    for (final (k, p) in visible.indexed)
                      Marker(
                        key: ValueKey(p.id),
                        point: p.point,
                        width: PhotoPin.width,
                        height: PhotoPin.height,
                        alignment: Alignment.topCenter,
                        child: PopIn(
                          delay: Duration(milliseconds: 200 + 60 * k),
                          alignment: Alignment.bottomCenter,
                          child: Semantics(
                            button: true,
                            label: '${p.name}, a ${Fmt.km(p.kmFrom(_here))}',
                            child: GestureDetector(
                              onTap: () => _select(p),
                              child: PhotoPin(place: p, selected: _selected == p),
                            ),
                          ),
                        ),
                      ),
                    if (_tip && tipTarget != null && !_listMode && onboarding.fromGps)
                      Marker(
                        point: tipTarget.point,
                        width: 240,
                        height: 150,
                        alignment: Marker.computePixelAlignment(
                          width: 240,
                          height: 150,
                          left: 120,
                          top: 150 + PhotoPin.height + 6,
                        ),
                        child: _Tip(
                          onDone: () => setState(() {
                            _tip = false;
                            _tipSeen = true;
                          }),
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                    TextSourceAttribution('OpenFreeMap'),
                  ],
                ),
              ],
            ),
          ),

          // List view covers the map under the controls.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_listMode,
              child: AnimatedOpacity(
                opacity: _listMode ? 1 : 0,
                duration: AppMotion.medium,
                child: _ListView(
                  places: visible,
                  here: _here,
                  topInset: pad.top + 120,
                  bottomInset: bottomBar + (_selected == null ? 16 : 250),
                  query: searching ? _search.text.trim() : null,
                  selected: _selected,
                  onTap: _select,
                  empty: noResults ? _NoPoints(onClear: _filtered ? _clearFilters : null, onWiden: _widen) : null,
                ),
              ),
            ),
          ),

          // Top controls.
          Positioned(
            top: pad.top + 8,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(controller: _search, focus: _searchFocus),
                      ),
                      const SizedBox(width: 8),
                      _ViewToggle(
                        list: _listMode,
                        onChanged: (v) {
                          FocusScope.of(context).unfocus();
                          setState(() => _listMode = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final t in HelpType.values) ...[
                        ChoiceChipPill(
                          label: t.label,
                          icon: t.icon,
                          color: t.color,
                          selected: store.filterTypes.contains(t),
                          elevated: true,
                          onTap: () => _toggleType(t),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ChoiceChipPill(
                        label: store.filterCauses.isEmpty ? 'Causas' : 'Causas (${store.filterCauses.length})',
                        selected: store.filterCauses.isNotEmpty,
                        elevated: true,
                        trailing: PhosphorIconsBold.caretDown,
                        onTap: _pickCauses,
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: AppMotion.slow,
                  curve: AppMotion.smooth,
                  alignment: Alignment.topCenter,
                  child: banners.isEmpty || _listMode
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Reveal(
                            key: banners.first.key,
                            delay: const Duration(milliseconds: 250),
                            child: banners.first,
                          ),
                        ),
                ),
                if (_listMode && _offline)
                  Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: banners.first),
              ],
            ),
          ),

          // Empty map state.
          if (!_listMode && noResults && !_emptyClosed)
            Positioned(
              left: 24,
              right: 24,
              top: 0,
              bottom: bottomBar,
              child: Center(
                child: Reveal(
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _NoPoints(
                      onClear: _filtered ? _clearFilters : null,
                      onWiden: _widen,
                      onClose: () => setState(() => _emptyClosed = true),
                    ),
                  ),
                ),
              ),
            ),

          // Counter + center button.
          if (!_listMode)
            AnimatedPositioned(
              duration: AppMotion.slow,
              curve: AppMotion.smooth,
              left: 12,
              right: 12,
              bottom: bottomBar + (_selected == null ? 14 : 300),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child: _slowLoad
                        ? const _Pill(key: ValueKey('loading'), loading: true, text: 'Buscando pontos perto de você…')
                        : visible.isEmpty
                        ? const SizedBox.shrink()
                        : _Pill(
                            key: ValueKey(visible.length),
                            text: visible.length == 1
                                ? '1 ponto perto de você'
                                : '${visible.length} pontos perto de você',
                          ),
                  ),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Centralizar no meu local',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: () => _mover.flyTo(_here, 13.6),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cinza900.withValues(alpha: .12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(PhosphorIconsFill.navigationArrow, size: 21, color: AppColors.petroleo600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Point card.
          AnimatedPositioned(
            duration: AppMotion.slow,
            curve: AppMotion.smooth,
            left: 12,
            right: 12,
            bottom: _selected == null ? -340 : bottomBar + 8,
            child: _selected == null
                ? const SizedBox(height: 240)
                : PlaceCard(
                    key: ValueKey(_selected!.id),
                    place: _selected!,
                    from: _here,
                    onOpen: () => context.push(PlaceScreen(placeId: _selected!.id)),
                    onClose: () => setState(() => _selected = null),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(PhosphorIconsRegular.magnifyingGlass, size: 19, color: AppColors.cinza600),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.petroleo600,
              style: AppType.body(color: AppColors.cinza900, size: 15.5),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar instituição ou causa',
                hintStyle: AppType.body(color: AppColors.cinza500, size: 15.5),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Limpar busca',
              onPressed: controller.clear,
              icon: const Icon(PhosphorIconsFill.xCircle, size: 18, color: AppColors.cinza400),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// "Mapa · Lista" switch.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.list, required this.onChanged});

  final bool list;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, IconData icon, bool on, bool value) => Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) HapticFeedback.selectionClick();
          onChanged(value);
        },
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          width: 42,
          height: 40,
          decoration: BoxDecoration(color: on ? AppColors.petroleo600 : null, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: on ? AppColors.white : AppColors.cinza700),
        ),
      ),
    );
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          item('Mapa', PhosphorIconsRegular.mapTrifold, !list, false),
          item('Lista', PhosphorIconsRegular.listBullets, list, true),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, this.loading = false});

  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.petroleo600),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: AppColors.petroleo500, shape: BoxShape.circle),
            ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppType.label(size: 13.5, color: AppColors.cinza800).copyWith(fontFeatures: tabular),
          ),
        ],
      ),
    );
  }
}

class _NoPoints extends StatelessWidget {
  const _NoPoints({required this.onClear, required this.onWiden, this.onClose});

  final VoidCallback? onClear;
  final VoidCallback onWiden;

  /// Only on the map; in the list, the message stays in place of the list.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        EmptyState(
          compact: true,
          icon: PhosphorIconsRegular.funnelSimpleX,
          title: 'Nenhum ponto com esses filtros perto de você.',
          text: 'Tente tirar um filtro ou aumentar a distância.',
          primary: onClear == null ? null : 'Limpar filtros',
          onPrimary: onClear,
          secondary: 'Aumentar a distância',
          onSecondary: onWiden,
        ),
        if (onClose != null)
          Positioned(
            top: 0,
            right: -8,
            child: IconButton(
              tooltip: 'Fechar',
              onPressed: onClose,
              icon: const Icon(PhosphorIconsRegular.x, size: 18, color: AppColors.cinza600),
            ),
          ),
      ],
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.places,
    required this.here,
    required this.topInset,
    required this.bottomInset,
    required this.onTap,
    required this.selected,
    this.query,
    this.empty,
  });

  final List<Place> places;
  final LatLng here;
  final double topInset;
  final double bottomInset;
  final ValueChanged<Place> onTap;
  final Place? selected;
  final String? query;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cinza50,
      child: places.isEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, bottomInset),
              child: query != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nada encontrado para "$query". Confira o nome ou busque por uma causa, como "alimentos".',
                          textAlign: TextAlign.center,
                          style: AppType.body(size: 15.5),
                        ),
                        if (store.myPoint == null) ...[const SizedBox(height: 24), const RegisterHint()],
                      ],
                    )
                  : empty,
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(12, topInset, 12, bottomInset),
              itemCount: places.length + (store.myPoint == null ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == places.length) {
                  return const Padding(padding: EdgeInsets.only(top: 16), child: RegisterHint());
                }
                final p = places[i];
                final g = p.nextGoal;
                final on = p == selected;
                return Pressable(
                  onTap: () => onTap(p),
                  scale: .985,
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: on ? AppColors.petroleo600 : AppColors.cinza100, width: on ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        PlaceThumb(place: p, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: AppType.label(
                                  color: AppColors.cinza900,
                                  size: 15.5,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ['a ${Fmt.km(p.kmFrom(here))}', g?.headline ?? 'Sem metas abertas agora'].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.body(size: 13.5).copyWith(fontFeatures: tabular),
                              ),
                            ],
                          ),
                        ),
                        const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza400),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Invite for institutions at the end of the map list and on an empty
/// search: "is your place missing? register it".
class RegisterHint extends StatelessWidget {
  const RegisterHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => openRegister(context),
      scale: .985,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.petroleo50, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const IconTile(icon: PhosphorIconsFill.storefront, color: AppColors.petroleo600, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sua instituição não está aqui?',
                    style: AppType.label(
                      color: AppColors.petroleo900,
                      size: 15.5,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cadastre o ponto de apoio e mostre o que vocês precisam.',
                    style: AppType.body(size: 13.5, color: AppColors.petroleo800),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.petroleo600),
          ],
        ),
      ),
    );
  }
}

/// Card shown when a pin or a list row is tapped.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.from, required this.onOpen, this.onClose});

  final Place place;
  final LatLng from;
  final VoidCallback onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final g = place.nextGoal;
    final more = place.openGoals.length - 1;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 200) onClose?.call();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.cinza900.withValues(alpha: .14), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Seal(),
                const SizedBox(width: 8),
                Text('a ${Fmt.km(place.kmFrom(from))} de você', style: AppType.body(size: 13.5)),
                const Spacer(),
                if (more > 0) StatusTag('+$more ${more == 1 ? 'meta' : 'metas'}', tone: Tone.neutral),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                PlaceThumb(place: place, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text(place.name, style: AppType.title().copyWith(fontSize: 22))),
              ],
            ),
            const SizedBox(height: 8),
            if (g == null)
              Text('${place.name} não tem metas abertas agora.', style: AppType.body(size: 15))
            else ...[
              Row(
                children: [
                  TypeTag(g.type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label(
                        color: AppColors.cinza900,
                        size: 15.5,
                      ).copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Motivo: ${g.reason}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body(size: 14.5, color: AppColors.cinza700),
              ),
              const SizedBox(height: 12),
              GoalBar(value: g.type == HelpType.voluntariado ? g.enrolled / g.target : g.progress),
              const SizedBox(height: 6),
              Text(
                g.type == HelpType.voluntariado ? '${g.enrolled} de ${g.target.round()}' : g.progressLabel,
                style: AppType.body(size: 13).copyWith(fontFeatures: tabular),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryButton(label: 'Ver o que precisa', onPressed: onOpen),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.name, required this.onClose});

  final String name;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final who = name == 'você' ? '' : ', $name';
    return Container(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.petroleo50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.petroleo100),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pronto$who. Estes são os pontos que precisam do que você escolheu.',
              style: AppType.body(color: AppColors.petroleo800, size: 14),
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: onClose,
            icon: const Icon(PhosphorIconsRegular.x, size: 18, color: AppColors.petroleo800),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return PopIn(
      delay: const Duration(milliseconds: 1600),
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(color: AppColors.cinza900, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Toque num ponto para ver o que ele precisa e por quê.',
                  style: AppType.body(color: AppColors.white, size: 14),
                ),
                TextButton(
                  onPressed: onDone,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 32)),
                  child: Text('Entendi', style: AppType.label(color: AppColors.ocre200, size: 14)),
                ),
              ],
            ),
          ),
          CustomPaint(size: const Size(16, 8), painter: _Arrow()),
        ],
      ),
    );
  }
}

class _Arrow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      Path()
        ..lineTo(s.width, 0)
        ..lineTo(s.width / 2, s.height)
        ..close(),
      Paint()..color = AppColors.cinza900,
    );
  }

  @override
  bool shouldRepaint(_Arrow old) => false;
}

/// Causes filter: chips, applied on close.
class _CausesSheet extends StatefulWidget {
  const _CausesSheet();

  @override
  State<_CausesSheet> createState() => _CausesSheetState();
}

class _CausesSheetState extends State<_CausesSheet> {
  late final _picked = {...store.filterCauses};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Causas', style: AppType.title().copyWith(fontSize: 22)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in causes)
              ChoiceChipPill(
                label: c,
                selected: _picked.contains(c),
                onTap: () => setState(() => _picked.contains(c) ? _picked.remove(c) : _picked.add(c)),
              ),
          ],
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Aplicar',
          icon: null,
          onPressed: () {
            store.filterCauses
              ..clear()
              ..addAll(_picked);
            Navigator.pop(context);
          },
        ),
        if (_picked.isNotEmpty) GhostButton(label: 'Limpar filtros', onPressed: () => setState(_picked.clear)),
      ],
    );
  }
}
