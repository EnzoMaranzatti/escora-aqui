import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;

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
import '../../core/widgets/scaffolds.dart' show navBarAway;
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../map/escora_map.dart';
import '../map/map_tiles.dart';
import '../map/pins.dart';
import '../map/trip.dart';
import '../institution/register/register_flow.dart';
import '../place/place_screen.dart';
import '../shared/help_ui.dart';
import '../signup/places_service.dart';

/// Ferramenta de desenvolvimento (o tour): escrever o id de um ponto aqui
/// abre o cartão dele como se tivessem tocado no pino; com o prefixo
/// `route:`, também desenha o caminho. Fotografar o carrossel pelo
/// simulador exigiria acertar um pino de 24px com o mouse.
final mapDemo = ValueNotifier<String?>(null);

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

  /// O último ponto escolhido fica guardado para o painel ter o que desenhar
  /// enquanto desce da tela.
  Place? _last;

  /// O caminho até o ponto escolhido, e se ele está desenhado no mapa.
  Trip? _trip;
  bool _route = false;
  bool _tracing = false;

  /// A barra de abas está fora de cena porque a pessoa está no mapa.
  bool _away = false;
  Timer? _panTimer;

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
    mapDemo.addListener(_onDemo);
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
    mapDemo.removeListener(_onDemo);
    _offlineTimer?.cancel();
    _panTimer?.cancel();
    navBarAway.value = false;
    _mover.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    // Quando o banco responde, o store troca os objetos Place inteiros. Sem
    // reatar a seleção pelo id, o ponto aberto some do meio de um gesto e
    // leva a rota junto.
    final sel = _selected;
    if (sel != null) {
      final novo = store.places.where((p) => p.id == sel.id).firstOrNull;
      if (novo == null || !novo.onMap) {
        _clearSelection(quiet: true);
      } else {
        _selected = novo;
        _last = novo;
      }
    }
    setState(() {});
  }

  void _onDemo() {
    final v = mapDemo.value;
    if (v == null || !mounted) return;
    final route = v.startsWith('route:');
    final id = route ? v.substring(6) : v;
    final p = _visible.where((x) => x.id == id).firstOrNull ?? _visible.firstOrNull;
    if (p == null) return;
    _select(p);
    if (route && !_route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleRoute();
      });
    }
  }

  /// Enquanto a pessoa arrasta o mapa, a barra de abas sai de cena e as
  /// pastilhas descem: o mapa passa a ser a tela toda. Volta sozinha quando
  /// o dedo para — ninguém precisa saber que ela foi embora.
  void _panning() {
    if (!_away) {
      setState(() => _away = true);
      _syncBar();
    }
    _panTimer?.cancel();
    _panTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _away = false);
      _syncBar();
    });
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
    if (_selected != null && !_visible.contains(_selected)) _clearSelection(quiet: true);
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

  void _select(Place p) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = p;
      _last = p;
      _route = false;
      _trip = TripService.cached(_here, p.point);
      _tracing = false;
      _tip = false;
      _tipSeen = true;
    });
    _syncBar();
    if (_route && _trip == null) _trace(p);
    if (!_listMode) _frame(p);
  }

  void _clearSelection({bool quiet = false}) {
    void apply() {
      _selected = null;
      _route = false;
      _trip = null;
      _tracing = false;
    }

    quiet ? apply() : setState(apply);
    _syncBar();
  }

  /// A barra de abas sai de cena enquanto a pessoa arrasta o mapa e enquanto
  /// um cartão está aberto: o cartão ocupa o lugar dela, e quem quiser a
  /// barra de volta fecha o cartão.
  void _syncBar() {
    final off = _away || (_selected != null && !_listMode);
    if (navBarAway.value != off) navBarAway.value = off;
  }

  /// O cartão cobre a metade de baixo do mapa, então o que interessa tem de
  /// parar na faixa que sobra, não no centro da tela. [_subir] é o quanto o
  /// alvo precisa ficar acima do centro para cair no meio dessa faixa.
  double get _subir {
    final h = MediaQuery.sizeOf(context).height;
    final pad = MediaQuery.paddingOf(context);
    final topo = pad.top + 120;
    final base = h - (pad.bottom + PlaceSheet.body);
    return h / 2 - (topo + base) / 2;
  }

  /// O mapa anda junto com o dedo no cartão.
  ///
  /// Antes a câmera só voava quando a página terminava de virar: o cartão
  /// trocava na mão e o mapa ia atrás meio segundo depois, como se fossem
  /// duas telas diferentes. Aqui a posição sai da mesma fração de página que
  /// desenha o cartão, então os dois se movem no mesmo gesto. O zoom não
  /// entra na conta — quem arrasta está comparando pontos, não viajando.
  void _follow(double page, List<Place> visible) {
    if (_listMode || visible.length < 2) return;
    final a = visible[page.floor().clamp(0, visible.length - 1)];
    final b = visible[page.ceil().clamp(0, visible.length - 1)];
    if (identical(a, b)) {
      _mover.stop();
      _map.move(a.point, _map.camera.zoom, offset: Offset(0, -_subir));
      return;
    }
    final t = page - page.floorToDouble();
    _mover.stop();
    _map.move(
      LatLng(
        a.point.latitude + (b.point.latitude - a.point.latitude) * t,
        a.point.longitude + (b.point.longitude - a.point.longitude) * t,
      ),
      _map.camera.zoom,
      offset: Offset(0, -_subir),
    );
  }

  /// Põe o ponto escolhido no enquadramento: a rota inteira quando ela está
  /// desenhada, senão só o ponto, sem mudar o zoom que a pessoa escolheu.
  void _frame(Place p) {
    final t = _trip;
    if (_route && t != null && t.points.length > 1) {
      _mover.stop();
      final pad = MediaQuery.paddingOf(context);
      final alvo = CameraFit.coordinates(
        coordinates: t.points,
        // A faixa livre do mapa: abaixo da busca, acima do cartão.
        padding: EdgeInsets.fromLTRB(40, pad.top + 120, 40, pad.bottom + PlaceSheet.body + 24),
        maxZoom: 15.5,
      ).fit(_map.camera);
      // Meio nível a menos: a rota encostando nas bordas não deixa ver onde
      // ela passa.
      _map.move(alvo.center, alvo.zoom - 0.5);
      return;
    }
    // O arrasto do cartão já pode ter trazido a câmera até aqui: voar de
    // novo por cinquenta metros é o tranco que se via ao soltar o dedo.
    final zoom = _map.camera.zoom.clamp(14.0, 16.0);
    final km = const Distance().as(LengthUnit.Kilometer, _map.camera.center, p.point);
    if (km < .08 && (zoom - _map.camera.zoom).abs() < .01) return;
    // Perto, o voo é curto; longe, ele ganha tempo para a pessoa ver por
    // onde passou. Um tempo fixo faz o salto curto parecer arrastado e o
    // longo, um corte.
    _mover.stop();
    _mover.flyTo(
      p.point,
      zoom,
      duration: Duration(milliseconds: (420 + km * 150).clamp(420, 1000).round()),
      curve: AppMotion.smooth,
      offset: Offset(0, -_subir),
    );
  }

  Future<void> _trace(Place p) async {
    setState(() => _tracing = true);
    final t = await TripService.between(_here, p.point);
    if (!mounted || _selected?.id != p.id) return;
    setState(() {
      _trip = t;
      _tracing = false;
    });
    if (_route && !_listMode) _frame(p);
  }

  /// Um passo de zoom a partir de onde a câmera está agora. Passa pelo
  /// `MapMover` para o salto ser animado como o resto do mapa.
  void _zoomBy(double step) {
    final c = _map.camera;
    final alvo = (c.zoom + step).clamp(3.0, 18.0);
    if (alvo == c.zoom) return;
    _mover.stop();
    _mover.flyTo(c.center, alvo);
  }

  void _toggleRoute() {
    final p = _selected;
    if (p == null) return;
    HapticFeedback.selectionClick();
    setState(() => _route = !_route);
    if (!_route) return;
    if (_trip == null) {
      _trace(p);
    } else if (!_listMode) {
      _frame(p);
    }
  }

  Future<void> _openFilters() async {
    await showAppSheet<void>(context, builder: (_) => const _FiltersSheet());
    _afterFilter();
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
    final sel = _selected;
    final searching = _search.text.trim().isNotEmpty;
    final noResults = visible.isEmpty && !searching && (_filtered || _nearby().isEmpty);
    final tipTarget = visible.isEmpty ? null : visible.first;
    // Com o cartão aberto ou o dedo no mapa, a barra de abas sai de cena e
    // o que flutua desce com ela.
    final cardOpen = sel != null && !_listMode;
    final bottomBar = pad.bottom + (_away || cardOpen ? 18 : 86);

    // Durante a descida o painel ainda precisa de um ponto para desenhar.
    final shown = sel ?? _last;
    // Os pontos que o painel folheia. Quando o escolhido saiu da lista (um
    // filtro acabou de tirá-lo), ele vira a única página — e é essa lista,
    // não a visível, que o mapa tem de seguir, senão o arrasto leva a
    // câmera para o ponto errado.
    final sheetPlaces = shown == null
        ? const <Place>[]
        : _na(visible, shown) >= 0
        ? visible
        : [shown];
    // A altura do cartão é a do ponto que está na frente: sem meta ele é
    // uns 60 mais baixo do que com três. `PlaceSheet.body` continua sendo o
    // maior deles, que é o que o mapa usa para reservar lugar.
    final sheetH = shown == null ? PlaceSheet.body : PlaceSheet.heightFor(shown);
    final notice = _notice();
    // A lista começa abaixo do que estiver flutuando no topo.
    final topInset = pad.top + 20 + 48 + (_filtered ? 40 : 0) + (notice == null ? 0 : 52);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: EscoraMap(
              controller: _map,
              initialCenter: store.mapCenter ?? _here,
              initialZoom: store.mapZoom ?? 13.4,
              onGesture: _panning,
              onMoved: (c, z) {
                store.mapCenter = c;
                store.mapZoom = z;
              },
              onTap: () {
                FocusScope.of(context).unfocus();
                _clearSelection();
              },
              children: [
                // A rota entra antes dos pinos: linha por baixo, pino por cima.
                if (_route && _trip != null && sel != null) _TripLine(trip: _trip!, color: sel.primaryType.color),
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
                              child: PhotoPin(
                                place: p,
                                selected: sel?.id == p.id,
                                dimmed: sel != null && sel.id != p.id,
                              ),
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
                  topInset: topInset,
                  bottomInset: bottomBar + 60,
                  query: searching ? _search.text.trim() : null,
                  onTap: (p) => context.push(PlaceScreen(placeId: p.id)),
                  empty: noResults ? _NoPoints(onClear: _filtered ? _clearFilters : null, onWiden: _widen) : null,
                ),
              ),
            ),
          ),

          // Busca, filtros e o aviso da vez — uma linha de 48px e nada mais.
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
                      _ModeButton(
                        list: _listMode,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _listMode = !_listMode);
                          _syncBar();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(count: store.filterTypes.length + store.filterCauses.length, onTap: _openFilters),
                    ],
                  ),
                ),
                // Os quatro chips de antes viraram o botão acima: só o que
                // está ligado aparece, e cada um sai com um toque.
                AnimatedSize(
                  duration: AppMotion.medium,
                  curve: AppMotion.smooth,
                  alignment: Alignment.topCenter,
                  child: !_filtered
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _ActiveFilters(
                            onType: _toggleType,
                            onCause: (c) {
                              store.filterCauses.remove(c);
                              _afterFilter();
                            },
                            onClear: _clearFilters,
                          ),
                        ),
                ),
                AnimatedSize(
                  duration: AppMotion.slow,
                  curve: AppMotion.smooth,
                  alignment: Alignment.topCenter,
                  child: notice == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Reveal(key: notice.key, delay: const Duration(milliseconds: 250), child: notice),
                        ),
                ),
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

          // Zoom e centralizar: a única coisa que sobra flutuando no mapa.
          AnimatedPositioned(
            duration: AppMotion.slow,
            curve: AppMotion.smooth,
            left: 12,
            right: 12,
            bottom: cardOpen ? pad.bottom + sheetH + 24 : bottomBar + 14,
            child: Row(
              children: [
                const Spacer(),
                if (!_listMode)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapControl(
                        children: [
                          _MapControlButton(icon: PhosphorIconsBold.plus, label: 'Aproximar', onTap: () => _zoomBy(1)),
                          Container(width: 24, height: 1, color: AppColors.cinza100),
                          _MapControlButton(icon: PhosphorIconsBold.minus, label: 'Afastar', onTap: () => _zoomBy(-1)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _MapControl(
                        children: [
                          _MapControlButton(
                            icon: PhosphorIconsFill.navigationArrow,
                            label: 'Centralizar no meu local',
                            onTap: () => _mover.flyTo(_here, 13.6),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // O cartão do ponto: sobe de baixo e fica pairando sobre o mapa,
          // sem encostar nas bordas. Sai com o X ou com um puxão para baixo.
          AnimatedPositioned(
            duration: AppMotion.slow,
            curve: AppMotion.smooth,
            left: 12,
            right: 12,
            height: sheetH,
            bottom: cardOpen ? pad.bottom + 12 : -(sheetH + pad.bottom + 60),
            child: shown == null
                ? const SizedBox.shrink()
                : PlaceSheet(
                    places: sheetPlaces,
                    index: _na(visible, shown).clamp(0, visible.length),
                    from: _here,
                    bottomPad: 0,
                    trip: _trip,
                    route: _route,
                    tracing: _tracing,
                    onRoute: _toggleRoute,
                    onIndex: (i) {
                      if (i < visible.length && visible[i].id != _selected?.id) _select(visible[i]);
                    },
                    onScroll: (page) => _follow(page, sheetPlaces),
                    onOpen: (p) => context.push(PlaceScreen(placeId: p.id)),
                    onClose: _clearSelection,
                  ),
          ),
        ],
      ),
    );
  }

  /// Onde [p] está em [lista], pelo id — o store troca os objetos a cada
  /// recarga, então comparar as instâncias não serve.
  int _na(List<Place> lista, Place p) => lista.indexWhere((x) => x.id == p.id);

  /// O aviso da vez, numa faixa de uma linha. O de localização ocupava um
  /// quarto da tela e empurrava o mapa para baixo.
  Widget? _notice() {
    if (_slowLoad) {
      return const _SlimNotice(
        key: ValueKey('loading'),
        icon: PhosphorIconsRegular.mapPinArea,
        text: 'Buscando pontos perto de você…',
      );
    }
    if (_offline) {
      return _SlimNotice(
        key: const ValueKey('offline'),
        icon: PhosphorIconsRegular.wifiSlash,
        text: 'Sem internet. O mapa pode estar desatualizado.',
        action: 'Tentar',
        onAction: _checkConnection,
      );
    }
    if (!onboarding.fromGps && !_gpsClosed) {
      return _SlimNotice(
        key: const ValueKey('gps'),
        icon: PhosphorIconsRegular.navigationArrow,
        text: 'Mostrando ${onboarding.city ?? 'São José do Rio Preto'}.',
        action: _locating ? 'Ativando…' : 'Ativar',
        onAction: _locating ? null : _enableLocation,
        onClose: () => setState(() => _gpsClosed = true),
      );
    }
    if (_banner && !_listMode) {
      return _SlimNotice(
        key: const ValueKey('welcome'),
        tinted: true,
        icon: PhosphorIconsRegular.handshake,
        text: store.name == 'você'
            ? 'Pronto. Estes pontos precisam do que você escolheu.'
            : 'Pronto, ${store.name}. Estes pontos precisam do que você escolheu.',
        onClose: () => setState(() => _banner = false),
      );
    }
    return null;
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
          const Icon(PhosphorIconsBold.magnifyingGlass, size: 19, color: AppColors.cinza600),
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
                hintText: 'Buscar ponto ou causa',
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

/// Botão de filtros ao lado da busca. Substitui a fileira de quatro chips:
/// eles mostravam o catálogo inteiro de opções o tempo todo, e o catálogo
/// não é a notícia — os pontos são.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return Semantics(
      button: true,
      label: on ? 'Filtros, $count ativos' : 'Filtros',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: on ? AppColors.petroleo600 : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(PhosphorIconsBold.funnelSimple, size: 21, color: on ? AppColors.white : AppColors.cinza700),
              if (on)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: AppColors.ocre500,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.petroleo600, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: AppType.label(size: 9.5, color: AppColors.petroleo900).copyWith(height: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Os filtros ligados, em fila. Cada um sai com um toque, e o último chip
/// limpa tudo.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.onType, required this.onCause, required this.onClear});

  final ValueChanged<HelpType> onType;
  final ValueChanged<String> onCause;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget chip({required String label, required Color color, required VoidCallback onTap}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Tirar o filtro $label',
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Text(label, style: AppType.label(size: 13, color: AppColors.white)),
                const SizedBox(width: 4),
                const Icon(PhosphorIconsBold.x, size: 12, color: AppColors.white),
              ],
            ),
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final t in store.filterTypes) chip(label: t.label, color: t.color, onTap: () => onType(t)),
          for (final c in store.filterCauses) chip(label: c, color: AppColors.cinza700, onTap: () => onCause(c)),
          Pressable(
            onTap: onClear,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Text('Limpar', style: AppType.label(size: 13, color: AppColors.petroleo700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de uma linha. O banner grande dizia a mesma coisa em quatro vezes
/// o espaço, e no mapa o espaço é o conteúdo.
class _SlimNotice extends StatelessWidget {
  const _SlimNotice({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
    this.onClose,
    this.tinted = false,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  /// Fundo petróleo claro, para o aviso que é boa notícia.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final ink = tinted ? AppColors.petroleo800 : AppColors.cinza800;
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(
        color: tinted ? AppColors.petroleo50 : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon.bold, size: 16, color: tinted ? AppColors.petroleo600 : AppColors.cinza600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.body(size: 13.5, color: ink),
            ),
          ),
          if (action != null)
            Pressable(
              onTap: onAction,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: Text(
                  action!,
                  style: AppType.label(
                    size: 13.5,
                    color: onAction == null ? AppColors.cinza500 : AppColors.petroleo700,
                  ),
                ),
              ),
            ),
          if (onClose != null)
            IconButton(
              tooltip: 'Fechar',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(PhosphorIconsBold.x, size: 15, color: tinted ? AppColors.petroleo600 : AppColors.cinza500),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Passagem de mapa para lista, ao lado da busca. Em petróleo cheio porque
/// no branco sobre o mapa ela quase não existia.
class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.list, required this.onTap});

  final bool list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: list ? 'Ver no mapa' : 'Ver em lista',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.petroleo600,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .16), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                list ? PhosphorIconsBold.mapTrifold : PhosphorIconsBold.listBullets,
                size: 18,
                color: AppColors.white,
              ),
              const SizedBox(width: 6),
              Text(list ? 'Mapa' : 'Lista', style: AppType.label(size: 14, color: AppColors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rota desenhada no mapa: um contorno branco por baixo, para a linha não
/// se perder nas ruas, e o traço na cor do tipo de ajuda por cima. Ela se
/// desenha da pessoa até o ponto em vez de aparecer pronta.
class _TripLine extends StatefulWidget {
  const _TripLine({required this.trip, required this.color});

  final Trip trip;
  final Color color;

  @override
  State<_TripLine> createState() => _TripLineState();
}

class _TripLineState extends State<_TripLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();

  @override
  void didUpdateWidget(_TripLine old) {
    super.didUpdateWidget(old);
    if (old.trip != widget.trip) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final all = widget.trip.points;
        final n = (all.length * AppMotion.glide.transform(_c.value)).ceil().clamp(2, all.length);
        final shown = all.sublist(0, n);
        return PolylineLayer(
          polylines: [
            Polyline(
              points: shown,
              color: AppColors.white.withValues(alpha: .95),
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
            ),
            Polyline(
              points: shown,
              color: widget.color,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              strokeJoin: StrokeJoin.round,
              // Linha reta vira pontilhado: ninguém deve achar que a reta
              // entre dois pontos é uma rua.
              pattern: widget.trip.real ? const StrokePattern.solid() : const StrokePattern.dotted(spacingFactor: 1.6),
            ),
          ],
        );
      },
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
              icon: const Icon(PhosphorIconsBold.x, size: 18, color: AppColors.cinza600),
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
    this.query,
    this.empty,
  });

  final List<Place> places;
  final LatLng here;
  final double topInset;
  final double bottomInset;
  final ValueChanged<Place> onTap;
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
                return Pressable(
                  onTap: () => onTap(p),
                  scale: .985,
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cinza100),
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
                        const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.cinza400),
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
            const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.petroleo600),
          ],
        ),
      ),
    );
  }
}

/// Painel do ponto escolhido: sobe da borda de baixo, cobre a barra de abas
/// e sai com o X ou com um puxão para baixo. Dentro dele o conteúdo desliza
/// de lado entre os pontos da vizinhança, e o mapa vai junto: quem troca de
/// ponto é o dedo no cartão ou o toque no pino, sem setas no caminho.
class PlaceSheet extends StatefulWidget {
  const PlaceSheet({
    super.key,
    required this.places,
    required this.index,
    required this.from,
    required this.onIndex,
    required this.onOpen,
    required this.onClose,
    required this.bottomPad,
    this.trip,
    this.route = false,
    this.tracing = false,
    this.onRoute,
    this.onScroll,
  });

  /// Altura do painel sem a faixa do aparelho.
  /// Altura do painel sem a faixa do aparelho. A foto não está aqui — ela
  /// cresceu dentro do pino —, mas entraram o que o lugar faz e o baralho
  /// de metas, que é o que o cartão ganhou de altura. Os 16 a mais são a
  /// folga das cartas de trás: sem eles a meta da frente fica 2px menor do
  /// que o conteúdo dela e o Flutter risca o cartão de amarelo.
  static const body = 420.0;

  /// A caixa da meta: a carta da frente (124 é o que cabe o tipo, o que
  /// precisa, a barra e quantos ajudaram) mais a folga das cartas de trás.
  /// Sem meta aberta sobra a frase e o aviso, e aí a caixa é bem mais baixa.
  static double boxHeight(Place p) =>
      p.nextGoal == null ? 96 : 124 + 8.0 * ((p.openGoals.length - 1).clamp(0, 2));

  /// O cartão cresce com o que tem dentro. Com altura fixa, um ponto sem
  /// meta ganhava um vão de 60 entre a frase e o botão — a mesma moldura de
  /// quem tem três metas, com um terço do conteúdo. Os 272 são o que não
  /// muda: o botão da rota, o nome, o crachá, o que o ponto faz e o botão
  /// principal, com uns 4 de folga para o arredondamento das linhas.
  static double heightFor(Place p) => 272 + boxHeight(p);

  final List<Place> places;
  final int index;
  final LatLng from;
  final ValueChanged<int> onIndex;
  final ValueChanged<Place> onOpen;
  final VoidCallback onClose;
  final double bottomPad;
  final Trip? trip;
  final bool route;
  final bool tracing;
  final VoidCallback? onRoute;

  /// A página fracionária enquanto o dedo arrasta o cartão (2.4 = a 40% do
  /// caminho entre o terceiro e o quarto ponto). É o que deixa o mapa andar
  /// junto com o dedo em vez de saltar no fim do gesto.
  final ValueChanged<double>? onScroll;

  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

/// A física da troca de cartão. A do `PageView` é dura de propósito, para
/// listas longas; aqui há meia dúzia de pontos e o cartão é grande, então a
/// mola é um pouco mais solta e ele pousa com peso em vez de travar.
class _SheetPhysics extends PageScrollPhysics {
  const _SheetPhysics({super.parent});

  @override
  _SheetPhysics applyTo(ScrollPhysics? ancestor) => _SheetPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(mass: .42, stiffness: 118, ratio: 1.02);
}

class _PlaceSheetState extends State<PlaceSheet> {
  late final PageController _pages = PageController(initialPage: widget.index);

  /// O quanto o dedo já puxou o painel para baixo.
  double _dy = 0;

  /// A troca de página veio de fora (um pino tocado no mapa), e não do dedo
  /// no cartão. Nesse caso quem leva a câmera é o voo do pino: avisar a
  /// fração de página aqui faria os dois puxarem o mapa ao mesmo tempo.
  bool _fromParent = false;

  @override
  void initState() {
    super.initState();
    _pages.addListener(_onScroll);
  }

  void _onScroll() {
    if (_fromParent || !_pages.hasClients || !_pages.position.haveDimensions) return;
    final p = _pages.page;
    if (p != null) widget.onScroll?.call(p);
  }

  @override
  void didUpdateWidget(PlaceSheet old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index && _pages.hasClients && _pages.page?.round() != widget.index) {
      // Troca vinda do mapa: o cartão **salta** para a página certa em vez
      // de deslizar. Deslizando, tocar um pino a dezesseis posições dali
      // fazia dezesseis cartões passarem voando — pisca e não se lê nada.
      // Quem conta a viagem é o voo da câmera, não o cartão.
      _fromParent = true;
      _pages.jumpToPage(widget.index);
      _fromParent = false;
    }
  }

  @override
  void dispose() {
    _pages.removeListener(_onScroll);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.places;
    final i = widget.index.clamp(0, places.length - 1);
    final place = places[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => setState(() => _dy = (_dy + d.delta.dy).clamp(0.0, 400.0)),
      onVerticalDragEnd: (d) {
        final go = _dy > 80 || (d.primaryVelocity ?? 0) > 420;
        setState(() => _dy = 0);
        if (go) widget.onClose();
      },
      child: Transform.translate(
        offset: Offset(0, _dy),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .22), blurRadius: 30, offset: const Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: places.length,
                physics: const _SheetPhysics(),
                onPageChanged: widget.onIndex,
                itemBuilder: (context, k) {
                  final p = places[k];
                  final mine = k == i;
                  // O conteúdo anda mais devagar que a página e apaga nas
                  // bordas: a troca deixa de ser um corte e passa a ter
                  // profundidade, como as páginas de um mapa de verdade.
                  return AnimatedBuilder(
                    animation: _pages,
                    builder: (context, child) {
                      final page = _pages.hasClients && _pages.position.haveDimensions
                          ? (_pages.page ?? widget.index.toDouble())
                          : widget.index.toDouble();
                      final d = (page - k).clamp(-1.0, 1.0);
                      final f = d.abs();
                      return Opacity(
                        opacity: (1 - f * .9).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(d * 38, 0),
                          child: Transform.scale(scale: 1 - f * .04, child: child),
                        ),
                      );
                    },
                    // Cada página na altura do **seu** ponto, não na do
                    // cartão: no meio do gesto o cartão ainda está na altura
                    // do ponto anterior, e sem isto a página que entra sai
                    // comprimida e o Flutter risca o cartão de amarelo. O
                    // que passar do cartão fica cortado na borda.
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: PlaceSheet.heightFor(p),
                        child: SizedBox(
                          height: PlaceSheet.heightFor(p),
                          child: _SheetBody(
                            place: p,
                            from: widget.from,
                            bottomPad: widget.bottomPad,
                            trip: mine ? widget.trip : null,
                            route: mine && widget.route,
                            tracing: mine && widget.tracing,
                            onRoute: mine ? widget.onRoute : null,
                            onOpen: () => widget.onOpen(p),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Mesma margem (18), mesma altura (42), mesmo raio e ícone do
              // mesmo tamanho (19) do botão da rota, do outro lado do
              // cartão: os dois são o par de cantos do topo.
              Positioned(
                top: 14,
                right: 18,
                child: Semantics(
                  button: true,
                  label: 'Fechar',
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: widget.onClose,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.cinza50, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(PhosphorIconsBold.x, size: 19, color: AppColors.cinza700),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Semantics(label: place.name, child: const SizedBox.expand()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma página do painel: quem é o ponto, a meta da vez e o que fazer. A
/// foto não está aqui — ela cresceu dentro do pino, no mapa.
class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.place,
    required this.from,
    required this.bottomPad,
    required this.onOpen,
    this.trip,
    this.route = false,
    this.tracing = false,
    this.onRoute,
  });

  final Place place;
  final LatLng from;
  final double bottomPad;
  final VoidCallback onOpen;
  final Trip? trip;
  final bool route;
  final bool tracing;
  final VoidCallback? onRoute;

  @override
  Widget build(BuildContext context) {
    final metas = place.openGoals;
    final g = place.nextGoal;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomPad + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No canto de cima fica a rota, e não o ícone do tipo: o tipo já
          // está escrito embaixo e o pino do mapa já o mostra, enquanto a
          // rota é a única ação que divide espaço com o botão principal.
          if (onRoute != null)
            _RouteDot(trip: trip, on: route, loading: tracing, onTap: onRoute!)
          else
            const SizedBox(height: 42),
          const SizedBox(height: 12),
          Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.title().copyWith(fontSize: 21, height: 1.15),
          ),
          const SizedBox(height: 8),
          // Quem é o lugar: selo, distância e tipo. Ficavam depois do botão
          // e era o que sobrava para ler **depois** de já ter decidido —
          // nada deve vir depois da ação principal. Aqui em cima eles são o
          // crachá do nome, na letra miúda que lhes cabe.
          Row(
            children: [
              const Seal(size: 11),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'a ${Fmt.km(place.kmFrom(from))}  ·  ${place.typeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 12.5, color: AppColors.cinza500).copyWith(fontFeatures: tabular),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // O que o lugar faz, nas palavras de quem o cadastrou. Era a
          // informação que faltava: o nome e a meta dizem o que ele precisa,
          // não quem ele é.
          Text(
            place.about,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(size: 13.5, color: AppColors.cinza600).copyWith(height: 1.4),
          ),
          const SizedBox(height: 13),
          // A caixa tem a altura que o ponto pede — e o cartão foi cortado
          // na mesma medida (`PlaceSheet.heightFor`), então o que sobra para
          // o `Spacer` é só o arredondamento das linhas de texto. Altura
          // travada, e não um intervalo: a `Column` de dentro é `max`, então
          // com teto maior que o piso a caixa ia sempre para o teto e o
          // cartão estourava por baixo. Nada de `Flexible` também — com o
          // `Spacer` logo abaixo os dois repartiam o vão meio a meio e a
          // meta ficava com metade da caixa.
          SizedBox(
            height: PlaceSheet.boxHeight(place),
            child: _GoalDeck(place: place, metas: metas),
          ),
          const Spacer(),
          const SizedBox(height: 14),
          // Sem meta aberta, "Ver o que precisa" levava a uma tela que
          // repetia "sem metas abertas": o botão prometia o que não havia.
          PrimaryButton(label: g == null ? 'Conhecer o ponto' : 'Ver o que precisa', onPressed: onOpen),
        ],
      ),
    );
  }
}

/// A rota num disco, no canto de cima do cartão.
///
/// Era um botão de 56 de altura ao lado do principal, e os dois disputavam
/// a mesma linha: "Rota" e "Ver o que precisa" pareciam duas escolhas de
/// mesmo peso, quando uma é o caminho e a outra é a razão de ir. Em cima e
/// redondo, ele some do caminho de quem só quer doar e continua à mão.
class _RouteDot extends StatelessWidget {
  const _RouteDot({required this.trip, required this.on, required this.loading, required this.onTap});

  final Trip? trip;
  final bool on;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final showTrip = on && t != null;
    return Semantics(
      button: true,
      label: on ? 'Esconder o caminho' : 'Ver o caminho até aqui',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        // AnimatedSize mede o conteúdo e anima a largura. Animar `width`
        // direto no AnimatedContainer (42 -> null) faz o Flutter tentar
        // interpolar entre uma restrição finita e uma infinita: ele
        // desiste, o disco fica com 42 e a pílula transborda.
        child: AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.smooth,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            constraints: const BoxConstraints(minWidth: 42),
            decoration: BoxDecoration(
              color: on ? AppColors.petroleo600 : AppColors.petroleo50,
              borderRadius: BorderRadius.circular(21),
            ),
            // Sem `alignment`: um Container alinhado e sem largura cresce
            // até o limite do pai, e o disco virava uma barra atravessada
            // no topo do cartão. O `minWidth` chega na Row, que se centra
            // sozinha enquanto o disco continua do tamanho do conteúdo.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.petroleo600),
                  )
                else
                  Icon(
                    showTrip && t.real ? PhosphorIconsBold.car : PhosphorIconsBold.path,
                    size: 19,
                    color: on ? AppColors.white : AppColors.petroleo700,
                  ),
                // Ícone sozinho é adivinhação: o botão diz "Rota" até ter
                // caminho traçado, e então passa a dizer quanto tempo dá.
                if (!loading) ...[
                  const SizedBox(width: 7),
                  Text(
                    showTrip ? '${t.minutes} min' : 'Rota',
                    style: AppType.label(
                      size: 14,
                      color: on ? AppColors.white : AppColors.petroleo700,
                    ).copyWith(fontFeatures: tabular),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A meta da vez, e as outras espiando por baixo.
///
/// Antes as metas que sobravam viravam a frase "+2 metas abertas", no canto,
/// do tamanho de uma legenda — ninguém via. Empilhadas, elas ocupam espaço
/// físico no cartão: dá para ver que há mais sem ler nada.
///
/// E o baralho anda: um toque manda a carta de cima para o fim da pilha e
/// traz a meta seguinte, com o "2 de 3" dizendo onde se está. Era só
/// desenho — três cartas que não viravam —, e quem quisesse ver as outras
/// tinha de abrir o ponto. Arrastar não dá: o dedo na horizontal é do
/// mapa, que troca de ponto.
class _GoalDeck extends StatefulWidget {
  const _GoalDeck({required this.place, required this.metas});

  final Place place;

  /// As metas abertas do ponto, da que vence primeiro para a última.
  final List<Goal> metas;

  @override
  State<_GoalDeck> createState() => _GoalDeckState();
}

class _GoalDeckState extends State<_GoalDeck> {
  int _k = 0;

  /// No máximo duas cartas atrás: a terceira já não se distingue da sombra.
  int get _atras => (widget.metas.length - 1).clamp(0, 2);

  void _proxima() {
    HapticFeedback.selectionClick();
    setState(() => _k = (_k + 1) % widget.metas.length);
  }

  @override
  Widget build(BuildContext context) {
    final metas = widget.metas;
    if (metas.isEmpty) return _GoalCard(place: widget.place, goal: null);
    final k = _k % metas.length;
    // A carta troca no lugar: a que sai apaga descendo e a que entra sobe —
    // o mesmo caminho que a mão acabou de fazer. `passthrough` repassa as
    // medidas da caixa para a carta; com `expand` ela esticaria até o teto
    // da caixa e com o padrão (`loose`) encolheria para o conteúdo.
    final frente = AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.smooth,
      switchOutCurve: AppMotion.smooth,
      layoutBuilder: (atual, anteriores) => Stack(
        fit: StackFit.passthrough,
        children: [...anteriores, ?atual],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .05), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: _GoalCard(
        key: ValueKey(metas[k].id),
        place: widget.place,
        goal: metas[k],
        posicao: metas.length > 1 ? '${k + 1} de ${metas.length}' : null,
      ),
    );
    if (_atras == 0) return frente;
    return Semantics(
      button: true,
      label: 'Ver a próxima meta',
      child: Pressable(
        onTap: _proxima,
        scale: .98,
        child: Padding(
          padding: EdgeInsets.only(bottom: 8.0 * _atras),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var j = _atras; j >= 1; j--)
                Positioned(
                  left: 13.0 * j,
                  right: 13.0 * j,
                  top: 8.0 * j,
                  bottom: -8.0 * j,
                  // Mesma cor da carta da frente e borda em todas: brancas,
                  // as de trás sumiam no fundo do cartão.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.cinza50,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.cinza300),
                    ),
                  ),
                ),
              frente,
            ],
          ),
        ),
      ),
    );
  }
}

/// O bloco da meta: o que precisa, quanto falta e até quando. Separado do
/// nome por fundo, não por borda — é o fundo que dá o respiro.
class _GoalCard extends StatelessWidget {
  const _GoalCard({super.key, required this.place, required this.goal, this.posicao});

  final Place place;
  final Goal? goal;

  /// "2 de 3" quando o ponto tem mais de uma meta: sem isso o toque no
  /// baralho troca a carta e não se sabe em que altura da pilha se está.
  final String? posicao;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final progresso = g == null
        ? null
        : g.type == HelpType.voluntariado
        ? '${g.enrolled} de ${g.target.round()} vagas'
        : g.progressLabel;
    final ajudaram = g == null ? 0 : (g.type == HelpType.voluntariado ? g.enrolled : g.helpers);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cinza50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cinza300),
      ),
      child: g == null
          // Sem meta, a caixa é curta: a frase e, debaixo dela, o aviso na
          // mesma linha de texto. Era um botão de 40 solto num quadro com
          // duas linhas em cima — parecia um anúncio colado no meio do
          // cartão, e a caixa tinha a altura de uma meta que não existia.
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sem metas abertas agora.\nEste ponto segue recebendo visitas.',
                  style: AppType.body(size: 14, color: AppColors.cinza600).copyWith(height: 1.45),
                ),
                const SizedBox(height: 9),
                if (store.followed.contains(place.id))
                  const _AvisoLinha(label: 'Avisamos quando abrir uma meta.')
                else
                  _AvisoLinha(
                    label: 'Avisar quando abrir uma meta',
                    onTap: () {
                      store.follow(place.id);
                      HapticFeedback.mediumImpact();
                      Toast.show(context, 'Pronto. Avisamos quando ${place.name} abrir uma meta.');
                    },
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TypeTag(g.type),
                    const Spacer(),
                    Text(
                      posicao == null ? 'até ${Fmt.day(g.deadline)}' : '$posicao  ·  até ${Fmt.day(g.deadline)}',
                      style: AppType.body(size: 12.5, color: AppColors.cinza500).copyWith(fontFeatures: tabular),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  g.quantity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label(
                    color: AppColors.cinza900,
                    size: 15.5,
                  ).copyWith(fontWeight: FontWeight.w600, height: 1.3, fontFeatures: tabular),
                ),
                const SizedBox(height: 12),
                GoalBar(value: g.type == HelpType.voluntariado ? g.enrolled / g.target : g.progress),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Text(
                      progresso!,
                      style: AppType.strong(size: 13, color: AppColors.cinza700).copyWith(fontFeatures: tabular),
                    ),
                    const Spacer(),
                    if (ajudaram > 0)
                      Text(
                        '$ajudaram ${ajudaram == 1 ? 'pessoa ajudou' : 'pessoas ajudaram'}',
                        style: AppType.body(size: 12.5, color: AppColors.cinza500),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// O aviso de quando a meta abrir: sino e texto, numa linha. Sublinhado
/// quando há o que tocar, apagado depois de tocado — a mesma linha nos dois
/// estados, para a caixa não mudar de altura ao seguir o ponto.
class _AvisoLinha extends StatelessWidget {
  const _AvisoLinha({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = onTap == null ? AppColors.cinza600 : AppColors.petroleo700;
    final linha = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsBold.bellSimple, size: 15, color: cor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.label(size: 13.5, color: cor).copyWith(
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: cor.withValues(alpha: .35),
              decorationThickness: 1.5,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return linha;
    return Semantics(
      button: true,
      child: Pressable(onTap: onTap, scale: .96, child: linha),
    );
  }
}

/// O balão que ensina o primeiro toque, com a setinha apontando o pino.
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

/// Tudo o que filtra o mapa numa folha: tipo de ajuda, causas e distância.
/// Aplicado ao fechar, para a lista não piscar a cada toque.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet();

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final _types = {...store.filterTypes};
  late final _causes = {...store.filterCauses};
  late double _km = store.radiusKm;

  static const _steps = [5.0, 10.0, 20.0, 50.0];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Filtros', style: AppType.title().copyWith(fontSize: 22)),
        const SizedBox(height: 18),
        Text('Como você quer ajudar', style: AppType.label(size: 14, color: AppColors.cinza700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in HelpType.values)
              ChoiceChipPill(
                label: t.label,
                icon: t.icon,
                color: t.color,
                selected: _types.contains(t),
                onTap: () => setState(() => _types.contains(t) ? _types.remove(t) : _types.add(t)),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Causas', style: AppType.label(size: 14, color: AppColors.cinza700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in causes)
              ChoiceChipPill(
                label: c,
                selected: _causes.contains(c),
                onTap: () => setState(() => _causes.contains(c) ? _causes.remove(c) : _causes.add(c)),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Até que distância', style: AppType.label(size: 14, color: AppColors.cinza700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in _steps)
              ChoiceChipPill(label: '${k.round()} km', selected: _km == k, onTap: () => setState(() => _km = k)),
          ],
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: 'Aplicar',
          icon: null,
          onPressed: () {
            store.filterTypes
              ..clear()
              ..addAll(_types);
            store.filterCauses
              ..clear()
              ..addAll(_causes);
            store.radiusKm = _km;
            Navigator.pop(context);
          },
        ),
        if (_types.isNotEmpty || _causes.isNotEmpty)
          GhostButton(
            label: 'Limpar filtros',
            onPressed: () => setState(() {
              _types.clear();
              _causes.clear();
            }),
          ),
      ],
    );
  }
}

/// Pílula branca que segura os controles do mapa (zoom, centralizar).
class _MapControl extends StatelessWidget {
  const _MapControl({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 20, color: AppColors.petroleo600)),
      ),
    );
  }
}
