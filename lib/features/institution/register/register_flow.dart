import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/icons.dart';

import '../../../core/format.dart';
import '../../../core/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../data/br_api.dart';
import '../../../data/store.dart';
import '../../map/escora_map.dart';
import '../../shared/help_ui.dart';
import '../institution_shell.dart';

/// Opens the signup where the person stopped (data is saved at each step).
void openRegister(BuildContext context) {
  final d = store.startDraft();
  context.push(switch (d.step) {
    1 => const _StepPerson(),
    2 => const _StepInstitution(),
    3 => const _StepPlace(),
    4 => const _StepHelp(),
    5 => const _StepReview(),
    _ => const _Intro(),
  });
}

/// "Corrigir cadastro": the data already sent, on the review step.
/// With [step] 2, the institution step opens on top of it.
void openRegisterAt(BuildContext context, Place p, {int? step}) {
  store.reopenDraft(p);
  context.push(const _StepReview());
  if (step == 2) context.push(const _StepInstitution(fromReview: true));
}

PointDraft get _d => store.draft!;

/// Moves on, or returns to the review when editing a block from it.
void _next(BuildContext context, int step, Widget page, bool fromReview) {
  if (fromReview) {
    Navigator.pop(context);
    return;
  }
  _d.step = math.max(_d.step, step);
  context.push(page);
}

// ── Abertura ────────────────────────────────────────────────
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    const needs = [
      (PhosphorIconsRegular.identificationCard, 'CNPJ da instituição, ou a indicação de uma instituição já verificada'),
      (PhosphorIconsRegular.mapPin, 'Endereço do local'),
      (PhosphorIconsRegular.camera, 'Uma foto da fachada ou do espaço'),
      (PhosphorIconsRegular.phone, 'Um telefone para contato'),
    ];
    return FlowScaffold(
      header: const IconBadge(PhosphorIconsFill.storefront, size: 64),
      title: 'Cadastre seu ponto de apoio',
      subtitle:
          'Depois da análise da nossa equipe, seu ponto aparece no mapa para quem quer ajudar perto de vocês. Leva cerca de 5 minutos.',
      primary: 'Começar cadastro',
      onPrimary: () => _next(context, 1, const _StepPerson(), false),
      secondary: 'Agora não',
      onSecondary: () => Navigator.pop(context),
      children: [
        Text(
          'Você vai precisar de',
          style: AppType.label(color: AppColors.cinza900, size: 16).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, (icon, text)) in needs.indexed) ...[
                if (i > 0) const Hairline(indent: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(icon, size: 21, color: AppColors.petroleo600),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(text, style: AppType.body(size: 15, color: AppColors.cinza800)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Passo 1 — Responsável ───────────────────────────────────
class _StepPerson extends StatefulWidget {
  const _StepPerson({this.fromReview = false});

  final bool fromReview;

  @override
  State<_StepPerson> createState() => _StepPersonState();
}

/// No SMS code (paid service): the phone is a contact for the team, which
/// checks it while reviewing the signup (product decision).
class _StepPersonState extends State<_StepPerson> {
  late String _name = _d.responsible;
  late String _phone = _d.phone;
  bool _phoneTried = false;

  bool get _phoneOk {
    final n = Fmt.digits(_phone).length;
    return n == 10 || n == 11;
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    setState(() => _phoneTried = true);
    if (!_phoneOk || _name.trim().isEmpty) return;
    _d
      ..responsible = _name.trim()
      ..phone = _phone;
    _next(context, 2, const _StepInstitution(), widget.fromReview);
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      step: 1,
      title: 'Quem é o responsável pelo ponto?',
      subtitle: 'Usamos esse contato só para falar sobre o cadastro. Ele não aparece no app.',
      primary: 'Continuar',
      primaryIcon: 'assets/icons/arrow_right.svg',
      onPrimary: _name.trim().isEmpty ? null : _continue,
      children: [
        AppTextField(
          label: 'Nome completo',
          hint: '',
          initialValue: _name,
          capitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          onChanged: (v) => setState(() {
            _name = v;
            _d.responsible = v;
          }),
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'Telefone',
          hint: '(17) 99999-9999',
          initialValue: _phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [MaskFormatter.phone()],
          error: _phoneTried && !_phoneOk ? 'Confira o telefone: são DDD e mais 8 ou 9 números.' : null,
          onChanged: (v) => setState(() => _phone = v),
          onSubmitted: (_) => _continue(),
        ),
      ],
    );
  }
}

// ── Passo 2 — Instituição ───────────────────────────────────
class _StepInstitution extends StatefulWidget {
  const _StepInstitution({this.fromReview = false});

  final bool fromReview;

  @override
  State<_StepInstitution> createState() => _StepInstitutionState();
}

class _StepInstitutionState extends State<_StepInstitution> {
  late final _cnpj = TextEditingController(text: _d.cnpj);
  bool _checking = false;
  CnpjResult? _result = _d.cnpjConfirmed ? CnpjFound(_d.legalName, _d.cnpjStatus) : null;
  bool _cnpjTried = false;
  String _search = '';

  @override
  void dispose() {
    _cnpj.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final digits = Fmt.digits(_cnpj.text);
    if (digits.length != 14) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _result = null;
    });
    final r = await BrApi.cnpj(digits);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = r;
      _d.cnpjConfirmed = false;
      _d.cnpjUnchecked = r is CnpjOffline;
    });
  }

  String? get _cnpjError {
    final digits = Fmt.digits(_cnpj.text);
    if (_cnpjTried && digits.length != 14) return 'Confira o CNPJ: são 14 números.';
    final r = _result;
    if (r is CnpjNotFound) return 'Não encontramos esse CNPJ na base pública. Confira os números.';
    if (r is CnpjFound && !r.active) {
      return 'Esse CNPJ aparece como ${r.status} na base pública. Para aparecer no mapa, o CNPJ precisa estar ativo.';
    }
    return null;
  }

  bool get _idOk => switch (_d.hasCnpj) {
    true => _d.cnpjConfirmed || _d.cnpjUnchecked,
    false => _d.indicatedBy != null,
    null => false,
  };

  bool get _valid => _idOk && _d.name.trim().isNotEmpty && _d.type.isNotEmpty && _d.about.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final verified = store.verifiedPlaces.where((p) => p.cnpj != null).toList();
    final q = Fmt.fold(_search.trim());
    final matches = q.isEmpty ? <Place>[] : verified.where((p) => Fmt.fold(p.name).contains(q)).take(4).toList();
    return FlowScaffold(
      step: 2,
      title: 'Sobre a instituição',
      primary: 'Continuar',
      onPrimary: _valid
          ? () {
              _d.cnpj = _cnpj.text;
              _next(context, 3, const _StepPlace(), widget.fromReview);
            }
          : () => setState(() => _cnpjTried = _d.hasCnpj == true),
      children: [
        Text('A instituição tem CNPJ?', style: AppType.label(size: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OptionTile(
                title: 'Sim',
                selected: _d.hasCnpj == true,
                onTap: () => setState(() => _d.hasCnpj = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OptionTile(
                title: 'Não',
                selected: _d.hasCnpj == false,
                onTap: () => setState(() => _d.hasCnpj = false),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.slow,
          curve: AppMotion.smooth,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_d.hasCnpj == true) ...[
                const SizedBox(height: 20),
                AppTextField(
                  label: 'CNPJ',
                  hint: '00.000.000/0000-00',
                  controller: _cnpj,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MaskFormatter.cnpj()],
                  error: _checking ? null : _cnpjError,
                  help: _checking ? 'Consultando o CNPJ…' : null,
                  onChanged: (v) {
                    setState(() {
                      _result = null;
                      _d.cnpjConfirmed = false;
                      _d.cnpjUnchecked = false;
                    });
                    if (Fmt.digits(v).length == 14) _lookup();
                  },
                  onFocusLost: () => setState(() => _cnpjTried = Fmt.digits(_cnpj.text).isNotEmpty),
                  suffix: _checking
                      ? const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.petroleo600),
                          ),
                        )
                      : null,
                ),
                if (r is CnpjFound && r.active) ...[
                  const SizedBox(height: 12),
                  _CnpjCard(
                    result: r,
                    confirmed: _d.cnpjConfirmed,
                    onYes: () => setState(() {
                      _d
                        ..cnpjConfirmed = true
                        ..legalName = r.legalName
                        ..cnpjStatus = r.status;
                      if (_d.payee.isEmpty) _d.payee = r.legalName;
                    }),
                    onNo: () => setState(() {
                      _cnpj.clear();
                      _result = null;
                    }),
                  ),
                ],
                if (r is CnpjOffline) ...[
                  const SizedBox(height: 12),
                  const NoticeBanner(
                    tone: Tone.neutral,
                    icon: PhosphorIconsRegular.wifiSlash,
                    text: 'Não conseguimos consultar o CNPJ agora. Você pode continuar, e nossa equipe confere depois.',
                  ),
                ],
              ],
              if (_d.hasCnpj == false) ...[
                const SizedBox(height: 20),
                if (_d.indicatedBy != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qual instituição verificada indica vocês?', style: AppType.label(size: 14)),
                      const SizedBox(height: 6),
                      OptionTile(
                        title: _d.indicatedBy!,
                        icon: PhosphorIconsFill.sealCheck,
                        selected: true,
                        onTap: () => setState(() => _d.indicatedBy = null),
                      ),
                    ],
                  )
                else ...[
                  AppTextField(
                    label: 'Qual instituição verificada indica vocês?',
                    hint: 'Buscar instituição',
                    help:
                        'Pastorais, coletivos e grupos de bairro podem entrar por indicação. A instituição indicada recebe um pedido e precisa aceitar.',
                    onChanged: (v) => setState(() => _search = v),
                    suffix: const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: AppColors.cinza600),
                    ),
                  ),
                  for (final p in matches) ...[
                    const SizedBox(height: 8),
                    Pressable(
                      onTap: () => setState(() => _d.indicatedBy = p.name),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cinza200),
                        ),
                        child: Row(
                          children: [
                            const Icon(PhosphorIconsFill.sealCheck, size: 18, color: AppColors.petroleo600),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p.name, style: AppType.label(size: 15))),
                            Text(p.neighborhood, style: AppType.body(size: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'Como o ponto aparece no mapa',
          hint: 'Ex.: Cozinha Comunitária Vila Nova',
          initialValue: _d.name,
          capitalization: TextCapitalization.words,
          onChanged: (v) => setState(() => _d.name = v),
        ),
        const SizedBox(height: 18),
        Text('Tipo', style: AppType.label(size: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in placeTypes)
              ChoiceChipPill(label: t, selected: _d.type == t, onTap: () => setState(() => _d.type = t)),
          ],
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: 'O que vocês fazem',
          hint: 'Conte em poucas palavras quem vocês atendem e como',
          help: 'Até 280 caracteres. Aparece no perfil do ponto.',
          initialValue: _d.about,
          maxLines: 4,
          minLines: 3,
          maxLength: 280,
          capitalization: TextCapitalization.sentences,
          onChanged: (v) => setState(() => _d.about = v),
        ),
      ],
    );
  }
}

class _CnpjCard extends StatelessWidget {
  const _CnpjCard({required this.result, required this.confirmed, required this.onYes, required this.onNo});

  final CnpjFound result;
  final bool confirmed;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.medium,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: confirmed ? AppColors.sucessoFundo : AppColors.petroleo50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: confirmed ? const Color(0xFFCFE5D4) : AppColors.petroleo100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                confirmed ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.buildings,
                size: 20,
                color: confirmed ? AppColors.sucessoBase : AppColors.petroleo600,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Encontramos: '),
                      TextSpan(
                        text: result.legalName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' · situação ${result.status}.${confirmed ? '' : ' É esta instituição?'}'),
                    ],
                  ),
                  style: AppType.body(size: 14.5, color: confirmed ? AppColors.sucessoTexto : AppColors.petroleo800),
                ),
              ),
            ],
          ),
          if (!confirmed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SoftButton(label: 'Sim, é esta', filled: true, expand: true, onTap: onYes),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton(label: 'Não é', expand: true, onTap: onNo),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Passo 3 — Local ─────────────────────────────────────────
class _StepPlace extends StatefulWidget {
  const _StepPlace({this.fromReview = false});

  final bool fromReview;

  @override
  State<_StepPlace> createState() => _StepPlaceState();
}

class _StepPlaceState extends State<_StepPlace> with TickerProviderStateMixin {
  late final _street = TextEditingController(text: _d.street);
  late final _neighborhood = TextEditingController(text: _d.neighborhood);
  final _map = MapController();
  late final _mover = MapMover(_map, this);
  bool _cepLoading = false;
  String? _cepError;
  String? _photoError;
  bool _tried = false;

  @override
  void dispose() {
    _street.dispose();
    _neighborhood.dispose();
    _mover.dispose();
    super.dispose();
  }

  Future<void> _lookupCep(String v) async {
    final digits = Fmt.digits(v);
    _d.cep = v;
    if (digits.length != 8) {
      setState(() => _cepError = null);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _cepLoading = true);
    final a = await BrApi.cep(digits);
    if (!mounted) return;
    setState(() {
      _cepLoading = false;
      _cepError = a == null ? 'Não encontramos esse CEP. Preencha o endereço manualmente.' : null;
    });
    if (a == null) return;
    _street.text = _d.street = a.street;
    _neighborhood.text = _d.neighborhood = a.neighborhood;
    _d.city = a.city;
    _locate();
  }

  Future<void> _locate() async {
    if (_d.street.trim().isEmpty) return;
    try {
      final r = await Geocoding().locationFromAddress(
        '${_d.street}, ${_d.number}, ${_d.neighborhood}, ${_d.city.isEmpty ? onboarding.city ?? '' : _d.city}, Brasil',
      );
      if (r.isEmpty || !mounted) return;
      final p = LatLng(r.first.latitude, r.first.longitude);
      _d.point = p;
      _mover.flyTo(p, 17);
    } catch (_) {}
  }

  Future<void> _photo() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400);
      if (f == null) return;
      final size = await File(f.path).length();
      setState(() {
        if (size > 10 * 1024 * 1024) {
          _photoError = 'A foto passou de 10 MB. Escolha outra ou reduza o tamanho.';
        } else {
          _photoError = null;
          _d.photo = f.path;
        }
      });
    } catch (_) {}
  }

  bool get _valid =>
      _d.street.trim().isNotEmpty &&
      _d.number.trim().isNotEmpty &&
      _d.neighborhood.trim().isNotEmpty &&
      _d.hours.trim().isNotEmpty;

  void _continue() {
    setState(() => _tried = true);
    if (_d.photo == null) {
      setState(() => _photoError = 'Envie uma foto do local. É parte da verificação.');
      return;
    }
    if (!_valid) return;
    _d.point ??= _map.camera.center;
    _next(context, 4, const _StepHelp(), widget.fromReview);
  }

  String? _required(String v) => _tried && v.trim().isEmpty ? 'Preencha este campo para continuar.' : null;

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      step: 3,
      title: 'Onde fica o ponto?',
      primary: 'Continuar',
      onPrimary: _continue,
      children: [
        AppTextField(
          label: 'CEP',
          hint: '00000-000',
          help: _cepLoading ? 'Buscando o endereço…' : 'Preenchemos o endereço a partir do CEP.',
          error: _cepError,
          initialValue: _d.cep,
          keyboardType: TextInputType.number,
          inputFormatters: [MaskFormatter.cep()],
          onChanged: _lookupCep,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Rua',
          hint: '',
          controller: _street,
          error: _required(_d.street),
          onChanged: (v) => setState(() => _d.street = v),
          onFocusLost: _locate,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Número',
                hint: '',
                initialValue: _d.number,
                keyboardType: TextInputType.number,
                error: _required(_d.number),
                onChanged: (v) => setState(() => _d.number = v),
                onFocusLost: _locate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Complemento (opcional)',
                hint: '',
                initialValue: _d.complement,
                onChanged: (v) => _d.complement = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Bairro',
          hint: '',
          controller: _neighborhood,
          error: _required(_d.neighborhood),
          onChanged: (v) => setState(() => _d.neighborhood = v),
        ),
        const SizedBox(height: 26),
        Text('Confira o pino', style: AppType.cardTitle(size: 18, color: AppColors.cinza900)),
        const SizedBox(height: 6),
        Text(
          'Arraste o pino até a entrada do local, para quem vai levar doações chegar no lugar certo.',
          style: AppType.body(size: 14.5),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                EscoraMap(
                  controller: _map,
                  initialCenter: _d.point ?? onboarding.position ?? store.center,
                  initialZoom: 16.5,
                  onMoved: (c, _) => _d.point = c,
                ),
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 34),
                      child: Icon(PhosphorIconsFill.mapPin, size: 40, color: AppColors.terracota600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        AppTextField(
          label: 'Quando vocês recebem doações?',
          hint: 'Ex.: segunda a sexta, das 8h às 17h',
          initialValue: _d.hours,
          error: _required(_d.hours),
          onChanged: (v) => setState(() => _d.hours = v),
        ),
        const SizedBox(height: 22),
        Text('Foto do local', style: AppType.label(size: 14)),
        const SizedBox(height: 6),
        if (_d.photo != null)
          Pressable(
            onTap: _photo,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.file(File(_d.photo!), height: 180, width: double.infinity, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsRegular.camera, size: 16),
                          const SizedBox(width: 6),
                          Text('Enviar foto', style: AppType.label(size: 13.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SoftButton(label: 'Enviar foto', icon: PhosphorIconsRegular.camera, expand: true, height: 50, onTap: _photo),
        const SizedBox(height: 6),
        Text(
          _photoError ?? 'Uma foto real e atual da fachada ou do espaço. Evite fotos com o rosto de crianças.',
          style: AppType.body(size: 13, color: _photoError != null ? AppColors.erroTexto : AppColors.cinza600),
        ),
      ],
    );
  }
}

// ── Passo 4 — Como receber ajuda ────────────────────────────
const pixKeyTypes = ['CNPJ', 'E-mail', 'Telefone', 'Chave aleatória'];

String? pixKeyError(String type, String key) {
  final k = key.trim();
  final ok = switch (type) {
    'CNPJ' => Fmt.digits(k).length == 14,
    'E-mail' => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(k),
    'Telefone' => [10, 11].contains(Fmt.digits(k).length),
    _ => RegExp(r'^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$').hasMatch(k),
  };
  if (ok) return null;
  final name = switch (type) {
    'CNPJ' => 'um CNPJ válido',
    'E-mail' => 'um e-mail válido',
    'Telefone' => 'um telefone válido',
    _ => 'uma chave aleatória válida',
  };
  return 'Confira a chave: ela não parece $name.';
}

List<TextInputFormatter> pixKeyFormatters(String type) => switch (type) {
  'CNPJ' => [MaskFormatter.cnpj()],
  'Telefone' => [MaskFormatter.phone()],
  _ => const [],
};

class _StepHelp extends StatefulWidget {
  const _StepHelp({this.fromReview = false});

  final bool fromReview;

  @override
  State<_StepHelp> createState() => _StepHelpState();
}

class _StepHelpState extends State<_StepHelp> {
  bool _tried = false;
  late final _key = TextEditingController(text: _d.pixKey);
  late final _payee = TextEditingController(text: _d.payee);

  @override
  void dispose() {
    _key.dispose();
    _payee.dispose();
    super.dispose();
  }

  bool get _pix => _d.accepts.contains(HelpType.pix);

  void _continue() {
    setState(() => _tried = true);
    if (_d.accepts.isEmpty) return;
    if (_pix && (pixKeyError(_d.pixKeyType, _d.pixKey) != null || _d.payee.trim().isEmpty)) return;
    _next(context, 5, const _StepReview(), widget.fromReview);
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      step: 4,
      title: 'Como vocês recebem ajuda?',
      primary: 'Continuar',
      onPrimary: _continue,
      children: [
        for (final t in HelpType.values) ...[
          OptionTile(
            title: t.label,
            subtitle: t.description,
            icon: t.icon,
            iconColor: t.color,
            multi: true,
            selected: _d.accepts.contains(t),
            onTap: () => setState(() => _d.accepts.contains(t) ? _d.accepts.remove(t) : _d.accepts.add(t)),
          ),
          const SizedBox(height: 10),
        ],
        if (_tried && _d.accepts.isEmpty)
          Text(
            'Escolha pelo menos uma forma de receber ajuda.',
            style: AppType.body(size: 13, color: AppColors.erroTexto),
          ),
        AnimatedSize(
          duration: AppMotion.slow,
          curve: AppMotion.smooth,
          alignment: Alignment.topCenter,
          child: !_pix
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    Text('Tipo de chave Pix', style: AppType.label(size: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in pixKeyTypes)
                          ChoiceChipPill(
                            label: t,
                            selected: _d.pixKeyType == t,
                            onTap: () => setState(() {
                              _d.pixKeyType = t;
                              _key.clear();
                              _d.pixKey = '';
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      key: ValueKey(_d.pixKeyType),
                      label: 'Chave Pix',
                      hint: '',
                      controller: _key,
                      keyboardType: switch (_d.pixKeyType) {
                        'CNPJ' || 'Telefone' => TextInputType.number,
                        'E-mail' => TextInputType.emailAddress,
                        _ => TextInputType.text,
                      },
                      inputFormatters: pixKeyFormatters(_d.pixKeyType),
                      error: _tried ? pixKeyError(_d.pixKeyType, _d.pixKey) : null,
                      onChanged: (v) => setState(() => _d.pixKey = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nome que aparece no banco ao fazer o Pix',
                      hint: '',
                      controller: _payee,
                      help:
                          'O doador vai conferir esse nome antes de pagar. Ele precisa ser o da instituição (ou do responsável, se não houver CNPJ).',
                      error: _tried && _d.payee.trim().isEmpty ? 'Preencha este campo para continuar.' : null,
                      capitalization: TextCapitalization.words,
                      onChanged: (v) => setState(() => _d.payee = v),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Passo 5 — Revisão ───────────────────────────────────────
class _StepReview extends StatefulWidget {
  const _StepReview();

  @override
  State<_StepReview> createState() => _StepReviewState();
}

class _StepReviewState extends State<_StepReview> {
  bool _sending = false;

  Future<void> _edit(Widget page) async {
    await context.push(page);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    store.submitDraft();
    store.setMode(AppMode.institution);
    HapticFeedback.mediumImpact();
    context.replaceAll(const InstitutionShell());
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return FlowScaffold(
      step: 5,
      title: 'Confira antes de enviar',
      background: AppColors.cinza50,
      primary: 'Enviar para análise',
      primaryIcon: null,
      loading: _sending,
      note: _sending ? Text('Enviando seu cadastro…', style: AppType.body(size: 14)) : null,
      onPrimary: d.declared ? _send : null,
      children: [
        _Block(
          title: 'Responsável',
          lines: [d.responsible, d.phone],
          onEdit: () => _edit(const _StepPerson(fromReview: true)),
        ),
        _Block(
          title: 'Instituição',
          lines: [
            d.name,
            d.type,
            if (d.hasCnpj == true) 'CNPJ ${d.cnpj}${d.legalName.isEmpty ? '' : ' · ${d.legalName}'}',
            if (d.hasCnpj == false && d.indicatedBy != null) 'Indicada por ${d.indicatedBy}',
            d.about,
          ],
          onEdit: () => _edit(const _StepInstitution(fromReview: true)),
        ),
        _Block(
          title: 'Local',
          lines: [
            '${d.street}, ${d.number}${d.complement.isEmpty ? '' : ', ${d.complement}'} · ${d.neighborhood}',
            d.hours,
          ],
          photo: d.photo,
          onEdit: () => _edit(const _StepPlace(fromReview: true)),
        ),
        _Block(
          title: 'Como receber ajuda',
          lines: [
            [for (final t in HelpType.values.where(d.accepts.contains)) t.label].join(' · '),
            if (d.accepts.contains(HelpType.pix)) 'Chave Pix (${d.pixKeyType}): ${d.pixKey}',
            if (d.accepts.contains(HelpType.pix)) 'Favorecido: ${d.payee}',
          ],
          onEdit: () => _edit(const _StepHelp(fromReview: true)),
        ),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => setState(() => d.declared = !d.declared),
          scale: .99,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: d.declared ? AppColors.petroleo600 : AppColors.cinza200,
                width: d.declared ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckMark(selected: d.declared, square: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Declaro que as informações são verdadeiras e que represento esta instituição.',
                    style: AppType.body(size: 15, color: AppColors.cinza800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.lines, required this.onEdit, this.photo});

  final String title;
  final List<String> lines;
  final VoidCallback onEdit;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: AppType.cardTitle(size: 17, color: AppColors.cinza900)),
                ),
                LinkText('Editar', onTap: onEdit),
              ],
            ),
            const SizedBox(height: 6),
            for (final l in lines.where((l) => l.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(l, style: AppType.body(size: 14.5, color: AppColors.cinza700)),
              ),
            if (photo != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(photo!), height: 96, width: 140, fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
