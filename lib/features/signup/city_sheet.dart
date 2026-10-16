import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/pills.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/svg_icon.dart';
import 'places_service.dart';

sealed class CitySheetResult {
  const CitySheetResult();
}

class PickedCity extends CitySheetResult {
  const PickedCity(this.city, this.uf, this.point);

  final String city;
  final String uf;
  final LatLng point;
}

class UseMyLocation extends CitySheetResult {
  const UseMyLocation();
}

/// Screen 9: floating sheet with state + city selectors.
/// The main button reads "Usar minha localização" until a city is picked,
/// then turns into "Confirmar cidade".
Future<CitySheetResult?> showCitySheet(BuildContext context, {bool permissionDenied = false}) {
  return showModalBottomSheet<CitySheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.cinza900.withValues(alpha: .25),
    sheetAnimationStyle: const AnimationStyle(duration: AppMotion.slow, curve: AppMotion.smooth),
    builder: (_) => _CitySheet(permissionDenied: permissionDenied),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.permissionDenied});

  final bool permissionDenied;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  BrState? _state;
  String? _city;
  bool _busy = false;
  String? _error;

  Future<void> _pickState() async {
    final states = await PlacesService.states();
    if (!mounted) return;
    final picked = await _pickFrom(context, 'Estado', [for (final s in states) s.name]);
    if (picked == null) return;
    setState(() {
      _state = states.firstWhere((s) => s.name == picked);
      _city = null;
      _error = null;
    });
  }

  Future<void> _pickCity() async {
    if (_state == null) return _pickState();
    final cities = await PlacesService.cities(_state!.uf);
    if (!mounted) return;
    final picked = await _pickFrom(context, 'Cidade', cities);
    if (picked == null) return;
    setState(() {
      _city = picked;
      _error = null;
    });
  }

  Future<void> _confirm() async {
    if (_city == null) {
      Navigator.pop(context, const UseMyLocation());
      return;
    }
    setState(() => _busy = true);
    final point = await PlacesService.locate(_city!, _state!.uf);
    if (!mounted) return;
    if (point == null) {
      setState(() {
        _busy = false;
        _error = 'Não encontramos "$_city" no mapa. Confira o nome da cidade.';
      });
      return;
    }
    Navigator.pop(context, PickedCity(_city!, _state!.uf, point));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(5, 0, 5, 12 + bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.sheetBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 107,
              height: 4,
              decoration: BoxDecoration(color: AppColors.sheetBorder, borderRadius: BorderRadius.circular(24)),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: BackPill(style: PillStyle.solid, onTap: () => Navigator.pop(context)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.permissionDenied ? 'Tudo bem, escolha sua cidade.' : 'Onde você está?',
              textAlign: TextAlign.center,
              style: AppType.title(),
            ),
            const SizedBox(height: 5),
            Text(
              widget.permissionDenied
                  ? 'Você pode liberar a localização depois, nas configurações do celular.'
                  : 'Usamos sua localização só para mostrar os pontos mais perto. Você pode trocar a cidade quando quiser.',
              textAlign: TextAlign.center,
              style: AppType.body(),
            ),
            const SizedBox(height: 32),
            _SelectField(hint: 'Selecione um estado', value: _state?.name, onTap: _pickState),
            const SizedBox(height: 13),
            AnimatedOpacity(
              opacity: _state == null ? .5 : 1,
              duration: AppMotion.medium,
              child: _SelectField(hint: 'Selecione sua cidade', value: _city, onTap: _pickCity),
            ),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.smooth,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: AppType.body(color: AppColors.erroTexto, size: 13)),
                    ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: _city == null ? 'Usar minha localização' : 'Confirmar cidade',
              icon: _city == null ? Ic.pinWhite : Ic.arrowRight,
              loading: _busy,
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({required this.hint, required this.value, required this.onTap});

  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.smooth,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? AppColors.petroleo50 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: filled ? AppColors.petroleo300 : AppColors.cinza100),
        ),
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                child: Text(
                  value ?? hint,
                  key: ValueKey(value),
                  style: filled ? AppType.label(color: AppColors.petroleo800, size: 14) : AppType.body(size: 14),
                ),
              ),
            ),
            const SizedBox(width: 8, height: 24),
            const SvgIcon(Ic.chevronUpDown, width: 5, height: 8.43),
          ],
        ),
      ),
    );
  }
}

/// Searchable list in a tall sheet.
Future<String?> _pickFrom(BuildContext context, String title, List<String> options) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: const AnimationStyle(duration: AppMotion.slow, curve: AppMotion.smooth),
    builder: (context) => _SearchList(title: title, options: options),
  );
}

class _SearchList extends StatefulWidget {
  const _SearchList({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  State<_SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<_SearchList> {
  String _q = '';

  static String _fold(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final lower = s.toLowerCase();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final q = _fold(_q);
    final items = q.isEmpty ? widget.options : widget.options.where((o) => _fold(o).contains(q)).toList();
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 40, bottom: media.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(color: AppColors.sheetBorder, borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: AppType.body(color: AppColors.cinza900),
                decoration: InputDecoration(
                  hintText: widget.title == 'Cidade' ? 'Digite o nome da cidade' : 'Buscar estado',
                  hintStyle: AppType.body(color: AppColors.cinza500),
                  filled: true,
                  fillColor: AppColors.cinza50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não encontramos "$_q". Confira o nome da cidade.',
                        style: AppType.body(),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 16 + media.padding.bottom),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.cinza100, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) => ListTile(
                        title: Text(items[i], style: AppType.body(color: AppColors.cinza900)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () => Navigator.pop(context, items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
