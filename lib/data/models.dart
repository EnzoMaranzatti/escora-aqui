import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import '../core/assets.dart';
import '../core/format.dart';
import '../features/onboarding/onboarding_state.dart';

export '../features/onboarding/onboarding_state.dart' show HelpType, causes, onboarding;

enum PlaceKind {
  school(Ic.school),
  church(Ic.church),
  care(Ic.heartMedicine);

  const PlaceKind(this.icon);

  final String icon;

  static PlaceKind fromType(String type) => switch (type) {
    'Igreja' => church,
    'Escola' => school,
    _ => care,
  };
}

const placeTypes = ['Igreja', 'Escola', 'ONG', 'Associação', 'Coletivo', 'Outro'];

const itemUnits = ['unidades', 'kg', 'litros', 'pacotes', 'kits'];

enum GoalStatus { open, done, expired, closed }

/// A volunteer action with day and time (meta de voluntariado).
class VolunteerAction {
  VolunteerAction({required this.name, required this.task, required this.day, required this.start, required this.end});

  String name;
  String task;
  DateTime day;

  /// Minutes since midnight.
  int start;
  int end;

  String get when => '${Fmt.weekdayDay(day)}, das ${Fmt.hour(start)} às ${Fmt.hour(end)}';
  String get hours => 'das ${Fmt.hour(start)} às ${Fmt.hour(end)}';

  DateTime get endsAt => DateTime(day.year, day.month, day.day).add(Duration(minutes: end));
}

class Goal {
  Goal({
    required this.id,
    required this.type,
    required this.deadline,
    required this.reason,
    required this.target,
    this.current = 0,
    this.item = '',
    this.unit = 'unidades',
    this.cause,
    this.action,
    this.status = GoalStatus.open,
    this.doneAt,
    this.helpers = 0,
    this.enrolled = 0,
    this.published = true,
  });

  final String id;
  final HelpType type;
  DateTime deadline;
  String reason;

  /// Money (Pix), quantity (itens) or slots (voluntariado).
  double target;

  /// Confirmed by the institution only.
  double current;
  String item;
  String unit;
  String? cause;
  VolunteerAction? action;
  GoalStatus status;
  DateTime? doneAt;

  /// People whose donation was confirmed.
  int helpers;

  /// Volunteers enrolled (taken slots).
  int enrolled;

  /// False while the point is still under review ("Salvar meta").
  bool published;

  /// The institution already saw the "Meta concluída" notice.
  bool seenDone = false;

  /// Value before the first confirmed donation can still change.
  bool get valueLocked => current > 0;

  /// Copies what came from the database into this same object, so screens
  /// that hold it show the new numbers.
  void updateFrom(Goal o) {
    deadline = o.deadline;
    reason = o.reason;
    target = o.target;
    current = o.current;
    item = o.item;
    unit = o.unit;
    cause = o.cause;
    action = o.action;
    status = o.status;
    doneAt = o.doneAt;
    helpers = o.helpers;
    enrolled = o.enrolled;
    published = o.published;
    seenDone = o.seenDone;
  }

  int get slotsLeft => (target - enrolled).round().clamp(0, 9999);

  String amount(double v) => switch (type) {
    HelpType.pix => Fmt.money(v, cents: false),
    HelpType.itens => _items(v),
    HelpType.voluntariado => v.round() == 1 ? '1 voluntário' : '${v.round()} voluntários',
  };

  String _items(double v) {
    final n = Fmt.count(v);
    return unit == 'unidades' ? '$n $item' : '$n $unit de $item';
  }

  /// "{quantidade}" — "40 cobertores", "R$ 3.000".
  String get quantity => amount(target);

  /// "{quantidade} até {prazo}"
  String get headline => '$quantity até ${Fmt.day(deadline)}';

  String _short(double v) => type == HelpType.pix ? Fmt.money(v, cents: false) : Fmt.count(v);

  /// "{atual} de {meta}"
  String get progressLabel => '${_short(current)} de ${_short(target)}';

  /// "Faltam {restante}"
  String get remaining => amount((target - current).clamp(0, target));

  double get progress => target <= 0 ? 0 : (current / target).clamp(0, 1);

  /// Short label under the map pin.
  String get tag => switch (type) {
    HelpType.pix => Fmt.money(target, cents: false),
    HelpType.itens => _items(target).length > 18 ? '${Fmt.count(target)} $unit' : _items(target),
    HelpType.voluntariado => 'Voluntários',
  };
}

class Review {
  const Review(this.name, this.date, this.stars, this.comment);

  final String name;
  final DateTime date;
  final int stars;
  final String comment;
}

enum PlaceStatus { draft, review, awaitingIndication, adjust, refused, active, paused, removed }

class Place {
  Place({
    required this.id,
    required this.name,
    required this.point,
    required this.kind,
    required this.typeLabel,
    required this.neighborhood,
    required this.street,
    required this.number,
    this.complement = '',
    this.cep = '',
    this.city = 'São José do Rio Preto',
    required this.hours,
    required this.receiveDays,
    required this.about,
    this.distributes,
    required this.causes,
    this.verifiedAt,
    this.cnpj,
    this.legalName = '',
    this.cnpjStatus = 'ativa',
    this.cnpjUnchecked = false,
    this.indicatedBy,
    required this.accepts,
    this.pixKeyType,
    this.pixKey,
    this.payee,
    List<Goal>? goals,
    List<Review>? reviews,
    this.status = PlaceStatus.active,
    this.pixPaused = false,
    DateTime? lastReviewed,
    this.responsible = '',
    this.phone = '',
    this.photo,
    this.statusReason,
    this.statusMessage,
  }) : goals = goals ?? [],
       reviews = reviews ?? [],
       lastReviewed = lastReviewed ?? DateTime.now();

  final String id;
  String name;
  LatLng point;
  PlaceKind kind;
  String typeLabel;
  String neighborhood;
  String street;
  String number;
  String complement;
  String cep;
  String city;
  String hours;

  /// Weekdays (1 = segunda … 7 = domingo) when donations are received.
  Set<int> receiveDays;
  String about;
  String? distributes;
  Set<String> causes;
  DateTime? verifiedAt;
  String? cnpj;
  String legalName;
  String cnpjStatus;

  /// BrasilAPI was offline at signup: nobody has looked the CNPJ up yet.
  bool cnpjUnchecked;

  /// Verified institution that vouches for a point without CNPJ.
  String? indicatedBy;
  Set<HelpType> accepts;
  String? pixKeyType;
  String? pixKey;

  /// Name shown by the bank ("razão social" or the responsible person).
  String? payee;
  final List<Goal> goals;
  final List<Review> reviews;
  PlaceStatus status;
  bool pixPaused;
  DateTime lastReviewed;
  String responsible;
  String phone;

  /// photo_path: a Storage link, a bundled stock photo of the test points
  /// (CC0, StockSnap, `assets/images/places/`) or, before the upload
  /// finishes, the local file picked at signup.
  String? photo;

  ImageProvider? get image => photoImage(photo);

  /// Reason and message from the team (ajuste, recusa, pausa).
  String? statusReason;
  String? statusMessage;

  String get address {
    final c = complement.trim().isEmpty ? '' : ', $complement';
    return '$street, $number$c · $neighborhood';
  }

  List<Goal> get openGoals {
    final list = goals.where((g) => g.status == GoalStatus.open && g.published).toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return list;
  }

  /// Finished goals stay visible for 7 days, without the help button.
  List<Goal> get recentClosed {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    return goals
        .where((g) => (g.status == GoalStatus.done || g.status == GoalStatus.expired) && g.published)
        .where((g) => (g.doneAt ?? g.deadline).isAfter(limit))
        .toList();
  }

  Goal? get nextGoal => openGoals.firstOrNull;

  /// Help type that colors the pin.
  HelpType get primaryType => nextGoal?.type ?? accepts.first;

  Set<HelpType> get activeTypes => {for (final g in openGoals) g.type};

  double get rating => reviews.isEmpty ? 0 : reviews.map((r) => r.stars).reduce((a, b) => a + b) / reviews.length;

  bool get onMap => status == PlaceStatus.active;

  /// Copies what came from the database into this same object (see
  /// [Goal.updateFrom]). Goals keep their identity by id.
  void updateFrom(Place o) {
    name = o.name;
    point = o.point;
    kind = o.kind;
    typeLabel = o.typeLabel;
    neighborhood = o.neighborhood;
    street = o.street;
    number = o.number;
    complement = o.complement;
    cep = o.cep;
    city = o.city;
    hours = o.hours;
    receiveDays = o.receiveDays;
    about = o.about;
    distributes = o.distributes;
    causes = o.causes;
    verifiedAt = o.verifiedAt;
    cnpj = o.cnpj;
    legalName = o.legalName;
    cnpjStatus = o.cnpjStatus;
    cnpjUnchecked = o.cnpjUnchecked;
    indicatedBy = o.indicatedBy;
    accepts = o.accepts;
    pixKeyType = o.pixKeyType;
    pixKey = o.pixKey;
    payee = o.payee;
    status = o.status;
    pixPaused = o.pixPaused;
    lastReviewed = o.lastReviewed;
    responsible = o.responsible;
    phone = o.phone;
    photo = o.photo;
    statusReason = o.statusReason;
    statusMessage = o.statusMessage;
    final old = {for (final g in goals) g.id: g};
    goals
      ..clear()
      ..addAll([for (final g in o.goals) (old[g.id]?..updateFrom(g)) ?? g]);
    reviews
      ..clear()
      ..addAll(o.reviews);
  }

  double kmFrom(LatLng p) => const Distance().as(LengthUnit.Meter, p, point) / 1000;

  int get daysSinceReview => DateTime.now().difference(lastReviewed).inDays;

  /// Guesses the receiving days from free text ("segunda a sábado…").
  static Set<int> daysFromText(String text) {
    final t = Fmt.fold(text);
    if (t.contains('todos os dias') || t.contains('segunda a domingo')) return {1, 2, 3, 4, 5, 6, 7};
    if (t.contains('segunda a sabado')) return {1, 2, 3, 4, 5, 6};
    final days = <int>{};
    if (t.contains('segunda a sexta')) days.addAll([1, 2, 3, 4, 5]);
    const names = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
    for (final (i, n) in names.indexed) {
      if (t.contains(n)) days.add(i + 1);
    }
    return days.isEmpty ? {1, 2, 3, 4, 5} : days;
  }
}

enum DonationStatus { waiting, confirmed, notFound, enrolled, itemsAgreed, cancelled, absent }

/// Contato de quem doou, do jeito que a instituição vê (fase 11). Vem da
/// função `place_donor_contact`, que só responde para o dono do ponto que
/// recebeu a doação.
class DonorContact {
  const DonorContact({
    required this.name,
    required this.firstName,
    this.phone,
    this.email,
    this.city,
    this.uf,
    this.since,
  });

  final String name;
  final String firstName;
  final String? phone;
  final String? email;
  final String? city;
  final String? uf;
  final DateTime? since;

  String? get place => city == null ? null : (uf == null ? city : '$city, $uf');

  /// Só os dígitos, com o 55 na frente, do jeito que o WhatsApp pede.
  String? get whatsapp {
    final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length < 10) return null;
    return d.startsWith('55') ? d : '55$d';
  }
}

class Donation {
  Donation({
    required this.id,
    required this.placeId,
    required this.goalId,
    required this.type,
    required this.amount,
    required this.date,
    required this.donor,
    this.donorId,
    this.mine = false,
    this.when,
    this.receipt = false,
    this.receiptPath,
    this.status = DonationStatus.waiting,
    this.confirmedAt,
    this.rated = false,
  });

  final String id;
  final String placeId;
  final String goalId;
  final HelpType type;

  /// Money (Pix) or quantity (itens); 1 for voluntariado.
  final double amount;
  final DateTime date;

  /// Donor's first name.
  final String donor;

  /// Conta de quem doou. Nula se a pessoa apagou a conta.
  final String? donorId;
  final bool mine;

  /// Delivery date (itens) or the action day (voluntariado).
  final DateTime? when;
  final bool receipt;

  /// Where the receipt is in the private Storage bucket (`donor/id.jpg`).
  final String? receiptPath;
  DonationStatus status;
  DateTime? confirmedAt;
  bool rated;

  bool get pending =>
      status == DonationStatus.waiting || status == DonationStatus.itemsAgreed || status == DonationStatus.enrolled;

  // ── Prazo de confirmação ────────────────────────────────────────────
  //
  // Quem doa por Pix manda o dinheiro direto para a conta da instituição e
  // some: o app não tem como saber que chegou, só a instituição tem. Sem um
  // prazo combinado, "aguardando confirmação" não quer dizer nada — pode ser
  // hoje à tarde ou nunca, e é essa dúvida que faz a pessoa achar que caiu
  // num golpe. Com prazo, os dois lados sabem quando a espera deixou de ser
  // normal: o doador ganha um caminho, e a instituição, uma cobrança.

  /// Até quando a instituição deveria ter conferido.
  DateTime get deadline => date.add(confirmWindow);

  /// Dias corridos de espera.
  int get waitingDays => DateTime.now().difference(date).inDays;

  /// Dias que ainda faltam (0 = vence hoje). Negativo depois do prazo.
  int get daysLeft => deadline.difference(DateTime.now()).inDays;

  /// Parada esperando alguém da instituição olhar. `itemsAgreed` e
  /// `enrolled` já são resposta: lá alguém viu e combinou.
  bool get awaiting => status == DonationStatus.waiting;

  /// Passou do prazo sem ninguém olhar.
  bool get overdue => awaiting && DateTime.now().isAfter(deadline);

  /// Quanto da espera já correu, de 0 a 1. É o que a barra do prazo desenha.
  double get waitProgress {
    final total = confirmWindow.inMinutes;
    final feito = DateTime.now().difference(date).inMinutes;
    return (feito / total).clamp(0.0, 1.0);
  }
}

/// O prazo que a instituição tem para conferir uma doação registrada.
///
/// Três dias é o que a própria tela de doação já prometia ("costuma levar
/// até 3 dias"); aqui a promessa vira regra, com consequência dos dois lados.
const confirmWindow = Duration(days: 3);

/// A donor's promise to send a Pix to one point every month. The app
/// doesn't move money: on [day] it reminds the donor, who pays in the bank
/// app with the amount ready, and each month becomes a normal Pix donation.
class MonthlyGift {
  MonthlyGift({
    required this.id,
    required this.placeId,
    required this.amount,
    required this.day,
    required this.donor,
    this.mine = false,
    DateTime? since,
  }) : since = since ?? DateTime.now();

  final String id;
  final String placeId;
  double amount;

  /// Day of the month, 1 to 28 (every month has it).
  int day;
  final String donor;
  final bool mine;
  final DateTime since;
  bool paused = false;

  /// First day of each month already paid.
  final paidMonths = <DateTime>{};

  static DateTime _month(DateTime d) => DateTime(d.year, d.month);

  bool get paidThisMonth => paidMonths.contains(_month(DateTime.now()));

  /// Next reminder: this month's day if it's still ahead and unpaid,
  /// otherwise the day in the next month.
  DateTime get nextDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final here = DateTime(now.year, now.month, day);
    if (!paidThisMonth && !here.isBefore(today)) return here;
    return DateTime(now.year, now.month + 1, day);
  }

  void markPaid() => paidMonths.add(_month(DateTime.now()));
}

enum NoticeKind {
  newGoal,
  confirmed,
  notFound,
  volunteerReminder,
  goalDone,
  monthlyReminder,
  // Institution side.
  approved,
  adjust,
  refused,
  paused,
  reactivated,
  newDonation,
}

class Notice {
  Notice({
    required this.id,
    required this.kind,
    required this.title,
    required this.text,
    required this.date,
    this.placeId,
    this.read = false,
  });

  final String id;
  final NoticeKind kind;
  final String title;
  final String text;
  final DateTime date;
  final String? placeId;
  bool read;

  bool get forInstitution => kind.index >= NoticeKind.approved.index;
}

/// A photo saved as a Storage link, a bundled asset or a local file.
ImageProvider? photoImage(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return NetworkImage(path);
  if (path.startsWith('assets/')) return AssetImage(path);
  return FileImage(File(path));
}

const reportReasons = [
  'As informações estão erradas',
  'O ponto não funciona mais',
  'Suspeito de golpe',
  'Outro motivo',
];

class Report {
  Report({required this.placeId, required this.reason, required this.text, required this.date});

  final String placeId;
  final String reason;
  final String text;
  final DateTime date;
}

enum SubmissionKind { novo, correcao, mudanca }

/// One entry in the team's review queue.
class Submission {
  Submission({
    required this.id,
    required this.place,
    required this.kind,
    required this.sentAt,
    this.changes = const {},
  });

  final String id;
  final Place place;
  final SubmissionKind kind;
  final DateTime sentAt;

  /// For "Mudanças de dados": label → new value.
  final Map<String, String> changes;

  bool get urgent => _businessDaysSince(sentAt) > 3;

  static int _businessDaysSince(DateTime d) {
    var n = 0;
    var day = Fmt.dateOnly(d);
    final today = Fmt.dateOnly(DateTime.now());
    while (day.isBefore(today)) {
      day = day.add(const Duration(days: 1));
      if (day.weekday <= 5) n++;
    }
    return n;
  }
}

/// Levels of the rewards system (fase 9). The thresholds are the same ones in
/// `supabase/migrations/..._fase9_bonificacao.sql`: the database decides the
/// level, these numbers only draw the progress on screen.
enum PointsLevel {
  bronze('Bronze', 0, 0, 0),
  prata('Prata', 5, 100, 50),
  ouro('Ouro', 20, 500, 150),
  black('Doador Black', null, 10000, 500);

  const PointsLevel(this.label, this.donations, this.points, this.items);

  final String label;

  /// Donations of R$10+ that unlock it; null when this track doesn't reach it.
  final int? donations;
  final int points;
  final int items;

  PointsLevel? get next => index + 1 < values.length ? values[index + 1] : null;
}

/// Why points went in or out. The labels are placeholders until the points
/// screens get their copy.
enum PointsReason {
  doacaoDinheiro('Doação em dinheiro'),
  doacaoItem('Itens doados'),
  loginDiario('Login diário'),
  bonusMensalLogin('Mês completo'),
  sequenciaDoacao('Sequência de doação'),
  canje('Troca no catálogo');

  const PointsReason(this.label);

  final String label;
}

class PointsProfile {
  PointsProfile({
    required this.balance,
    required this.lifetime,
    required this.level,
    required this.qualifyingDonations,
    required this.itemsDonated,
    required this.loginStreakDays,
    required this.donationStreakMonths,
    this.loginLastDate,
    this.donationLastAt,
  });

  /// Points still to spend in the partners' catalog.
  int balance;

  /// Everything ever earned; never decays, and decides the level.
  final int lifetime;
  final PointsLevel level;
  final int qualifyingDonations;
  final int itemsDonated;
  final int loginStreakDays;
  final int donationStreakMonths;
  final DateTime? loginLastDate;
  final DateTime? donationLastAt;

  PointsLevel? get nextLevel => level.next;

  /// Os pontos de hoje já entraram? O banco guarda a data no fuso de São
  /// Paulo; o aparelho de quem usa o app está no mesmo fuso.
  bool get claimedToday {
    final d = loginLastDate;
    if (d == null) return false;
    final hoje = DateTime.now();
    return d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
  }

  /// Quanto vale abrir o app num dia: 2 de segunda a sexta, 4 no sábado e 6
  /// no domingo. É a mesma conta do `register_daily_login` (fase 9) — aqui
  /// só para a tela poder dizer o número antes de chamar o banco.
  static int dailyValue([DateTime? day]) => switch ((day ?? DateTime.now()).weekday) {
    DateTime.saturday => 4,
    DateTime.sunday => 6,
    _ => 2,
  };

  /// Os dias da semana atual (segunda a domingo) em que a pessoa já pontuou,
  /// deduzidos da sequência que o banco mantém: os últimos [loginStreakDays]
  /// dias terminam em [loginLastDate].
  Set<int> get weekdaysClaimed {
    final last = loginLastDate;
    if (last == null || loginStreakDays <= 0) return const {};
    final hoje = DateTime.now();
    final monday = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: hoje.weekday - 1));
    final lastDay = DateTime(last.year, last.month, last.day);
    return {
      for (var i = 0; i < loginStreakDays; i++)
        if (lastDay.subtract(Duration(days: i)).isAfter(monday.subtract(const Duration(hours: 1))))
          lastDay.subtract(Duration(days: i)).weekday,
    };
  }

  /// The three tracks to the next level, in the order of the level table.
  /// Null progress means the track doesn't reach the next level.
  List<({PointsTrack track, double progress, int missing})> get tracks {
    final next = level.next;
    return [
      (track: PointsTrack.donations, from: level.donations ?? 0, to: next?.donations, has: qualifyingDonations),
      (track: PointsTrack.points, from: level.points, to: next?.points, has: lifetime),
      (track: PointsTrack.items, from: level.items, to: next?.items, has: itemsDonated),
    ].map((t) {
      final to = t.to;
      if (to == null || to <= t.from) return (track: t.track, progress: 0.0, missing: 0);
      return (
        track: t.track,
        progress: ((t.has - t.from) / (to - t.from)).clamp(0.0, 1.0),
        missing: (to - t.has).clamp(0, to),
      );
    }).toList();
  }

  /// How far the next level is, along whichever of the three tracks is closest.
  double get levelProgress => level.next == null ? 1 : tracks.map((t) => t.progress).reduce((a, b) => a > b ? a : b);

  /// The track that gets to the next level first, and what's still missing on
  /// it. Null on the last level.
  ({PointsTrack track, int missing})? get nextStep {
    if (level.next == null) return null;
    final best = tracks.reduce((a, b) => a.progress >= b.progress ? a : b);
    return (track: best.track, missing: best.missing);
  }
}

/// The three ways to reach the next level; whichever arrives first counts.
enum PointsTrack { donations, points, items }

/// One line of the points statement (extrato).
class PointsEntry {
  const PointsEntry({
    required this.id,
    required this.amount,
    required this.reason,
    required this.note,
    required this.date,
  });

  final String id;

  /// Positive when earned, negative on a redemption.
  final int amount;
  final PointsReason reason;
  final String note;
  final DateTime date;
}

/// A company that gives coupons or tickets in exchange for exposure.
class Partner {
  const Partner({required this.id, required this.name, this.logo});

  final String id;
  final String name;
  final String? logo;

  ImageProvider? get image => photoImage(logo);
}

class CatalogItem {
  CatalogItem({
    required this.id,
    required this.partner,
    required this.title,
    required this.description,
    required this.cost,
    required this.minLevel,
    this.stock,
    this.active = true,
    this.photoPath,
  });

  final String id;
  final Partner partner;
  final String title;
  final String description;
  final int cost;
  final PointsLevel minLevel;

  /// null means no limit.
  int? stock;

  /// False when the item left the catalog; it still shows in past redemptions.
  final bool active;

  /// Foto do cupom dentro do app (assets/images/partners/...). Nula enquanto
  /// a migração das fotos não roda: aí o card cai no ícone.
  final String? photoPath;

  bool get soldOut => stock != null && stock! <= 0;
}

class Redemption {
  const Redemption({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.points,
    required this.code,
    required this.date,
  });

  final String id;
  final String title;
  final String partnerName;
  final int points;

  /// What the person shows at the partner ("ESC-A1B2C3").
  final String code;
  final DateTime date;
}

// ── Parceiro (fase 10) ───────────────────────────────────────

/// Um cupom do parceiro na tela "Meus cupons", com as contas já somadas
/// pelo banco (partner_catalog). Vem no lugar de [CatalogItem] porque o
/// parceiro precisa de duas coisas que o doador não vê: quantos cupons
/// saíram e quantos já foram usados no balcão.
class PartnerCoupon {
  const PartnerCoupon({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.minLevel,
    required this.redeemed,
    required this.used,
    this.stock,
    this.active = true,
    this.photoPath,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final PointsLevel minLevel;

  /// Quantos foram trocados por pontos, e quantos desses já tiveram baixa.
  final int redeemed;
  final int used;

  /// null = sem limite.
  final int? stock;
  final bool active;
  final String? photoPath;

  ImageProvider? get image => photoImage(photoPath);

  /// Trocados que ainda não apareceram no balcão.
  int get pending => redeemed - used;

  bool get soldOut => stock != null && stock! <= 0;
}

/// O que a tela de validação mostra depois de procurar um código.
class CouponLookup {
  const CouponLookup({
    required this.code,
    required this.title,
    required this.points,
    required this.date,
    required this.donorName,
    this.usedAt,
  });

  final String code;
  final String title;
  final int points;

  /// Quando a pessoa trocou os pontos por este cupom.
  final DateTime date;

  /// Primeiro nome de quem trocou: o suficiente para conferir no balcão.
  final String donorName;

  /// Quando o parceiro deu baixa. Nulo = o cupom ainda vale.
  final DateTime? usedAt;

  bool get used => usedAt != null;
}

const adjustReasons = [
  'A foto não mostra o local',
  'O endereço não confere com o CNPJ',
  'O CNPJ não está ativo',
  'A chave Pix não está no nome da instituição',
  'A descrição não explica o que o ponto faz',
  'Outro motivo',
];
