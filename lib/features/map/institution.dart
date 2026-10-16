import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/assets.dart';
import '../onboarding/onboarding_state.dart';

enum PlaceKind {
  school(Ic.school),
  church(Ic.church),
  care(Ic.heartMedicine);

  const PlaceKind(this.icon);

  final String icon;
}

/// Fictional institution for the prototype (the briefing asks for fake data).
class Institution {
  const Institution({
    required this.name,
    required this.point,
    required this.kind,
    required this.types,
    required this.causes,
    required this.need,
    this.tag = '',
    this.progress = 0,
  });

  final String name;
  final LatLng point;
  final PlaceKind kind;
  final Set<HelpType> types;
  final Set<String> causes;

  /// Current goal, in the "quantity + deadline + reason" formula.
  final String need;

  /// Short label for the chip under the pin ("40 cobertores").
  final String tag;

  /// Share of the current goal already reached, 0–1.
  final double progress;

  /// Type that colors the pin: the one the current need asks for.
  HelpType get primaryType => types.first;

  double kmFrom(LatLng p) => const Distance().as(LengthUnit.Meter, p, point) / 1000;
}

class _Seed {
  const _Seed(this.name, this.east, this.north, this.kind, this.types, this.causes, this.need, this.tag, this.progress);

  final String name;

  /// Offset from the center, in km.
  final double east;
  final double north;
  final PlaceKind kind;
  final Set<HelpType> types;
  final Set<String> causes;
  final String need;
  final String tag;
  final double progress;
}

const _seeds = [
  _Seed(
    'Casa Exemplo',
    -1.1,
    .9,
    PlaceKind.church,
    {HelpType.itens, HelpType.pix},
    {'Roupas e agasalhos', 'Pessoas em situação de rua'},
    '40 cobertores até 30/06. Motivo: a frente fria aumentou o número de acolhidos.',
    '40 cobertores',
    .55,
  ),
  _Seed(
    'Instituição Santo Dumont',
    2.2,
    2.6,
    PlaceKind.care,
    {HelpType.pix},
    {'Crianças', 'Saúde'},
    'R\$ 3.000 até sexta para remédios de uso contínuo.',
    'R\$ 3 mil',
    .72,
  ),
  _Seed(
    'Instituição Liberal',
    .5,
    -1.5,
    PlaceKind.school,
    {HelpType.itens, HelpType.voluntariado},
    {'Educação', 'Material escolar'},
    '25 kits escolares até 10/02 para a volta às aulas.',
    '25 kits',
    .4,
  ),
  _Seed(
    'Projeto Semear',
    -2.4,
    -.6,
    PlaceKind.school,
    {HelpType.voluntariado},
    {'Crianças', 'Educação'},
    'Voluntários no sábado, das 9h às 12h, para reforço escolar.',
    'Voluntários',
    .3,
  ),
  _Seed(
    'Cozinha Comunitária Jardim',
    1.4,
    -.2,
    PlaceKind.care,
    {HelpType.itens},
    {'Alimentos'},
    '30 kg de arroz até sexta. Motivo: aumentou o número de famílias atendidas.',
    '30 kg de arroz',
    .64,
  ),
  _Seed(
    'Lar Aurora',
    -.6,
    2.2,
    PlaceKind.care,
    {HelpType.pix, HelpType.voluntariado},
    {'Idosos', 'Saúde'},
    'R\$ 1.200 até o dia 20 para fraldas geriátricas.',
    'R\$ 1.200',
    .48,
  ),
  _Seed(
    'Escola Viva',
    3.1,
    .4,
    PlaceKind.school,
    {HelpType.itens},
    {'Material escolar', 'Crianças'},
    '60 cadernos até o fim do mês.',
    '60 cadernos',
    .25,
  ),
  _Seed(
    'Abrigo Recanto',
    -3.2,
    1.8,
    PlaceKind.church,
    {HelpType.itens, HelpType.voluntariado},
    {'Pessoas em situação de rua', 'Higiene e limpeza'},
    '80 kits de higiene até domingo.',
    '80 kits',
    .58,
  ),
  _Seed(
    'Associação Vila Nova',
    .9,
    3.4,
    PlaceKind.church,
    {HelpType.pix},
    {'Alimentos', 'Idosos'},
    'R\$ 2.500 até o dia 15 para cestas básicas.',
    'R\$ 2.500',
    .81,
  ),
  _Seed(
    'Grupo Patas do Bairro',
    -1.8,
    -2.4,
    PlaceKind.care,
    {HelpType.itens, HelpType.pix},
    {'Animais'},
    '50 kg de ração até quarta. Motivo: 12 resgates neste mês.',
    '50 kg de ração',
    .36,
  ),
  _Seed(
    'Centro Comunitário Boa Vista',
    2.6,
    -2.2,
    PlaceKind.school,
    {HelpType.voluntariado},
    {'Educação', 'Crianças'},
    'Voluntários para oficina de leitura, terças às 14h.',
    'Voluntários',
    .5,
  ),
  _Seed(
    'Paróquia São Lucas',
    -.2,
    -3.1,
    PlaceKind.church,
    {HelpType.itens},
    {'Alimentos', 'Roupas e agasalhos'},
    '100 peças de agasalho até 30/06.',
    '100 agasalhos',
    .67,
  ),
];

/// Builds the sample institutions around [center], so the demo works
/// wherever the phone is.
List<Institution> sampleInstitutions(LatLng center) {
  final kmPerLat = 110.574;
  final kmPerLng = 111.320 * math.cos(center.latitude * math.pi / 180);
  return [
    for (final s in _seeds)
      Institution(
        name: s.name,
        point: LatLng(center.latitude + s.north / kmPerLat, center.longitude + s.east / kmPerLng),
        kind: s.kind,
        types: s.types,
        causes: s.causes,
        need: s.need,
        tag: s.tag,
        progress: s.progress,
      ),
  ];
}

String formatKm(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
