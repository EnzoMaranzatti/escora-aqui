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

class Donation {
  Donation({
    required this.id,
    required this.placeId,
    required this.goalId,
    required this.type,
    required this.amount,
    required this.date,
    required this.donor,
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
}

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

const adjustReasons = [
  'A foto não mostra o local',
  'O endereço não confere com o CNPJ',
  'O CNPJ não está ativo',
  'A chave Pix não está no nome da instituição',
  'A descrição não explica o que o ponto faz',
  'Outro motivo',
];
