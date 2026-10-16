import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import 'models.dart';
import 'seed.dart';

export 'models.dart';

enum AppMode { donor, institution, team }

/// Signup draft for the institution's point. Saved at every step, so the
/// person continues where they stopped.
class PointDraft {
  int step = 0;
  String responsible = '';
  String phone = '';
  bool phoneVerified = false;
  bool? hasCnpj;
  String cnpj = '';
  String legalName = '';
  String cnpjStatus = '';
  bool cnpjConfirmed = false;

  /// True when the public lookup was offline and the team checks later.
  bool cnpjUnchecked = false;
  String? indicatedBy;
  String name = '';
  String type = '';
  String about = '';
  String cep = '';
  String street = '';
  String number = '';
  String complement = '';
  String neighborhood = '';
  String city = '';
  LatLng? point;
  String hours = '';
  String? photo;
  final accepts = <HelpType>{};
  String pixKeyType = 'CNPJ';
  String pixKey = '';
  String payee = '';
  bool declared = false;
}

/// App-wide state for the prototype (no backend yet). Donor, institution
/// and team modes read the same data, so the demo closes the loop: a donor
/// registers a Pix, the institution confirms it, the team approves points.
class AppStore extends ChangeNotifier {
  // ── Account ───────────────────────────────────────────────
  String name = 'você';
  String fullName = '';
  String email = '';
  String userPhone = '';
  DateTime? birthDate;

  /// Local path of the profile photo picked from the gallery.
  String? avatar;

  void updateProfile({
    required String fullName,
    required String email,
    required String phone,
    required DateTime? birthDate,
    required String? avatar,
  }) {
    this.fullName = fullName;
    name = fullName.split(' ').first;
    onboarding.name = name;
    this.email = email;
    userPhone = phone;
    this.birthDate = birthDate;
    this.avatar = avatar;
    notifyListeners();
  }

  /// Demo accounts belong to the team ("vocês dois na demonstração").
  bool isTeam = true;
  AppMode mode = AppMode.donor;

  // ── Data ──────────────────────────────────────────────────
  LatLng center = const LatLng(-20.8113, -49.3758);
  final places = <Place>[];
  final donations = <Donation>[];
  final notices = <Notice>[];
  final reports = <Report>[];
  final queue = <Submission>[];
  final followed = <String>{};
  final monthly = <MonthlyGift>[];

  // ── Donor preferences ─────────────────────────────────────
  final filterTypes = <HelpType>{};
  final filterCauses = <String>{};
  double radiusKm = 5;
  LatLng? mapCenter;
  double? mapZoom;
  bool notifyGoals = true;
  bool notifyConfirm = true;
  bool notifyVolunteer = true;

  // ── Institution ───────────────────────────────────────────
  String? myPointId;
  PointDraft? draft;

  /// "Aprovado" shows once, the first time the mode opens after approval.
  bool approvalSeen = false;

  bool _ready = false;
  int _id = 0;
  final _timers = <Timer>[];

  /// When true, seeded institutions confirm a Pix some seconds after it is
  /// registered, so the demo shows the whole cycle.
  static const simulateReplies = true;

  String nextId(String p) => '$p${++_id}';

  void init({LatLng? at, bool returning = false}) {
    if (_ready) return;
    _ready = true;
    center = at ?? onboarding.position ?? center;
    places.addAll(seedPlaces(center));
    queue.addAll(seedQueue(center));
    reports.addAll(seedReports());
    filterCauses.addAll(onboarding.selectedCauses);
    if (returning) _seedHistory();
  }

  /// History for someone who logs back in (a new account starts empty).
  void _seedHistory() {
    DateTime ago(int d) => DateTime.now().subtract(Duration(days: d));
    donations.addAll([
      Donation(
        id: nextId('d'),
        placeId: 'lar-aurora',
        goalId: 'g8',
        type: HelpType.pix,
        amount: 50,
        date: ago(9),
        donor: name,
        mine: true,
        status: DonationStatus.confirmed,
        confirmedAt: ago(8),
      ),
      Donation(
        id: nextId('d'),
        placeId: 'casa-exemplo',
        goalId: 'g1',
        type: HelpType.itens,
        amount: 3,
        date: ago(5),
        donor: name,
        mine: true,
        when: ago(4),
        status: DonationStatus.confirmed,
        confirmedAt: ago(4),
        rated: true,
      ),
      Donation(
        id: nextId('d'),
        placeId: 'santo-dumont',
        goalId: 'g3',
        type: HelpType.pix,
        amount: 30,
        date: ago(3),
        donor: name,
        mine: true,
        status: DonationStatus.notFound,
      ),
    ]);
    notices.addAll([
      Notice(
        id: nextId('n'),
        kind: NoticeKind.notFound,
        title: 'A Instituição Santo Dumont não encontrou sua doação',
        text: 'Confira o comprovante em Minhas doações.',
        date: ago(2),
        placeId: 'santo-dumont',
      ),
      Notice(
        id: nextId('n'),
        kind: NoticeKind.goalDone,
        title: 'A meta de Associação Vila Nova foi concluída',
        text: 'R\$ 2.500 arrecadados. Obrigado por fazer parte.',
        date: ago(2),
        placeId: 'vila-nova',
      ),
      Notice(
        id: nextId('n'),
        kind: NoticeKind.confirmed,
        title: 'Sua doação foi confirmada',
        text: 'A Lar Aurora confirmou o recebimento de R\$ 50,00.',
        date: ago(8),
        placeId: 'lar-aurora',
        read: true,
      ),
    ]);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) => _timers.add(Timer(d, f));

  void touch() => notifyListeners();

  // ── Lookups ───────────────────────────────────────────────
  Place place(String id) => places.firstWhere((p) => p.id == id);

  Place? placeOrNull(String id) => places.where((p) => p.id == id).firstOrNull;

  Goal? goal(Place p, String id) => p.goals.where((g) => g.id == id).firstOrNull;

  Place? get myPoint => myPointId == null ? null : placeOrNull(myPointId!);

  List<Place> get verifiedPlaces => places.where((p) => p.verifiedAt != null && p.onMap).toList();

  List<Donation> get myDonations => donations.where((d) => d.mine).toList()..sort((a, b) => b.date.compareTo(a.date));

  int get unread => notices.where((n) => !n.read).length;

  List<Donation> incoming(Place p) =>
      donations.where((d) => d.placeId == p.id).toList()..sort((a, b) => b.date.compareTo(a.date));

  int pendingFor(Place p) =>
      incoming(p).where((d) => d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed).length;

  int get confirmedCount => myDonations.where((d) => d.status == DonationStatus.confirmed).length;

  int get helpedPlaces =>
      {for (final d in myDonations.where((d) => d.status == DonationStatus.confirmed)) d.placeId}.length;

  // ── Donor actions ─────────────────────────────────────────
  void setMode(AppMode m) {
    mode = m;
    notifyListeners();
  }

  void follow(String placeId) {
    followed.add(placeId);
    notifyListeners();
  }

  void unfollow(String placeId) {
    followed.remove(placeId);
    notifyListeners();
  }

  Donation registerPix(Place p, Goal g, double amount, {required bool receipt}) {
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: g.id,
      type: HelpType.pix,
      amount: amount,
      date: DateTime.now(),
      donor: name,
      mine: true,
      receipt: receipt,
    );
    donations.add(d);
    notifyListeners();
    if (simulateReplies && p.id != myPointId) {
      _later(const Duration(seconds: 25), () {
        if (d.status == DonationStatus.waiting) confirm(d);
      });
    }
    return d;
  }

  Donation registerItems(Place p, Goal g, double qty, DateTime when) {
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: g.id,
      type: HelpType.itens,
      amount: qty,
      date: DateTime.now(),
      donor: name,
      mine: true,
      when: when,
      status: DonationStatus.itemsAgreed,
    );
    donations.add(d);
    notifyListeners();
    return d;
  }

  Donation enroll(Place p, Goal g) {
    g.enrolled++;
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: g.id,
      type: HelpType.voluntariado,
      amount: 1,
      date: DateTime.now(),
      donor: name,
      mine: true,
      when: g.action!.day,
      status: DonationStatus.enrolled,
    );
    donations.add(d);
    final tomorrow = Fmt.dateOnly(DateTime.now()).add(const Duration(days: 1));
    if (notifyVolunteer && Fmt.dateOnly(g.action!.day) == tomorrow) {
      _notice(
        NoticeKind.volunteerReminder,
        'Amanhã: ${g.action!.name}',
        'Das ${Fmt.hour(g.action!.start)} às ${Fmt.hour(g.action!.end)}, em ${p.address}.',
        placeId: p.id,
      );
    }
    notifyListeners();
    return d;
  }

  void cancelEnrollment(Donation d) {
    final p = place(d.placeId);
    final g = goal(p, d.goalId);
    if (g != null && g.enrolled > 0) g.enrolled--;
    d.status = DonationStatus.cancelled;
    notifyListeners();
  }

  void rate(Donation d, int stars, String comment) {
    place(d.placeId).reviews.insert(0, Review(name, DateTime.now(), stars, comment.trim()));
    d.rated = true;
    notifyListeners();
  }

  void report(String placeId, String reason, String text) {
    reports.add(Report(placeId: placeId, reason: reason, text: text.trim(), date: DateTime.now()));
    notifyListeners();
  }

  void markRead(Notice n) {
    n.read = true;
    notifyListeners();
  }

  void markAllRead() {
    for (final n in notices) {
      n.read = true;
    }
    notifyListeners();
  }

  void _notice(NoticeKind kind, String title, String text, {String? placeId}) {
    notices.insert(
      0,
      Notice(id: nextId('n'), kind: kind, title: title, text: text, date: DateTime.now(), placeId: placeId),
    );
  }

  String _what(Donation d, Goal? g) => switch (d.type) {
    HelpType.pix => Fmt.money(d.amount),
    _ => g?.amount(d.amount) ?? Fmt.count(d.amount),
  };

  // ── Donor: monthly Pix ────────────────────────────────────
  MonthlyGift? monthlyFor(String placeId) => monthly.where((m) => m.mine && m.placeId == placeId).firstOrNull;

  List<MonthlyGift> get myMonthly => monthly.where((m) => m.mine).toList();

  /// Active monthly donors of a point (institution side).
  List<MonthlyGift> monthlyDonors(String placeId) => monthly.where((m) => m.placeId == placeId && !m.paused).toList();

  MonthlyGift startMonthly(Place p, double amount, int day) {
    final m = MonthlyGift(id: nextId('m'), placeId: p.id, amount: amount, day: day, donor: name, mine: true);
    monthly.add(m);
    notifyListeners();
    // Demo: the first reminder arrives shortly instead of on the real day.
    if (simulateReplies) _later(const Duration(seconds: 20), () => _remindMonthly(m));
    return m;
  }

  void _remindMonthly(MonthlyGift m) {
    if (!monthly.contains(m) || m.paused || m.paidThisMonth) return;
    final p = place(m.placeId);
    _notice(
      NoticeKind.monthlyReminder,
      'Dia da sua doação mensal',
      '${Fmt.money(m.amount)} para ${p.name}. Toque para fazer o Pix com o valor pronto.',
      placeId: p.id,
    );
    notifyListeners();
  }

  void updateMonthly(MonthlyGift m, {required double amount, required int day}) {
    m
      ..amount = amount
      ..day = day;
    notifyListeners();
  }

  void toggleMonthly(MonthlyGift m) {
    m.paused = !m.paused;
    notifyListeners();
  }

  void cancelMonthly(MonthlyGift m) {
    monthly.remove(m);
    notifyListeners();
  }

  /// This month's payment, registered as a regular Pix donation. It counts
  /// towards the point's open Pix goal when there is one.
  Donation payMonthly(MonthlyGift m, {required bool receipt}) {
    final p = place(m.placeId);
    final g = p.openGoals.where((g) => g.type == HelpType.pix).firstOrNull;
    m.markPaid();
    if (g != null) return registerPix(p, g, m.amount, receipt: receipt);
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: '',
      type: HelpType.pix,
      amount: m.amount,
      date: DateTime.now(),
      donor: name,
      mine: true,
      receipt: receipt,
    );
    donations.add(d);
    notifyListeners();
    if (simulateReplies && p.id != myPointId) {
      _later(const Duration(seconds: 25), () {
        if (d.status == DonationStatus.waiting) confirm(d);
      });
    }
    return d;
  }

  // ── Institution: donations ────────────────────────────────
  void confirm(Donation d) {
    final p = place(d.placeId);
    final g = goal(p, d.goalId);
    d.status = DonationStatus.confirmed;
    d.confirmedAt = DateTime.now();
    if (g != null) {
      g.current += d.amount;
      g.helpers++;
      if (g.current >= g.target && g.status == GoalStatus.open) {
        g.status = GoalStatus.done;
        g.doneAt = DateTime.now();
        if (donations.any((x) => x.goalId == g.id && x.mine && x.status == DonationStatus.confirmed)) {
          _notice(
            NoticeKind.goalDone,
            'A meta de ${p.name} foi concluída',
            '${g.quantity} arrecadados. Obrigado por fazer parte.',
            placeId: p.id,
          );
        }
      }
    }
    if (d.mine && notifyConfirm) {
      _notice(
        NoticeKind.confirmed,
        'Sua doação foi confirmada',
        'A ${p.name} confirmou o recebimento de ${_what(d, g)}.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  void markNotFound(Donation d) {
    final p = place(d.placeId);
    d.status = DonationStatus.notFound;
    if (d.mine) {
      _notice(
        NoticeKind.notFound,
        'A ${p.name} não encontrou sua doação',
        'Confira o comprovante em Minhas doações.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  /// "Salvar presença": participants count for the goal and can rate.
  void savePresence(Goal g, Map<String, bool> attended) {
    for (final e in attended.entries) {
      final d = donations.firstWhere((x) => x.id == e.key);
      if (e.value) {
        confirm(d);
      } else {
        d.status = DonationStatus.absent;
      }
    }
    notifyListeners();
  }

  void cancelAction(Goal g) {
    g.status = GoalStatus.closed;
    g.doneAt = DateTime.now();
    for (final d in donations.where((d) => d.goalId == g.id && d.status == DonationStatus.enrolled)) {
      d.status = DonationStatus.cancelled;
    }
    notifyListeners();
  }

  // ── Institution: goals ────────────────────────────────────
  void addGoal(Place p, Goal g) {
    p.goals.add(g);
    if (g.published) _simulateDonor(p, g);
    notifyListeners();
  }

  void closeGoal(Goal g) {
    g.status = GoalStatus.closed;
    g.doneAt = DateTime.now();
    notifyListeners();
  }

  void extendGoal(Goal g, DateTime deadline) {
    g.deadline = deadline;
    g.status = GoalStatus.open;
    g.doneAt = null;
    notifyListeners();
  }

  /// Someone near the new point registers a donation a few seconds after a
  /// goal goes live, so the institution side of the demo has work to do.
  void _simulateDonor(Place p, Goal g) {
    if (!simulateReplies) return;
    _later(const Duration(seconds: 15), () {
      if (g.status != GoalStatus.open || !p.onMap) return;
      final d = switch (g.type) {
        HelpType.pix => Donation(
          id: nextId('d'),
          placeId: p.id,
          goalId: g.id,
          type: HelpType.pix,
          amount: 50,
          date: DateTime.now(),
          donor: 'Mariana',
          receipt: true,
        ),
        HelpType.itens => Donation(
          id: nextId('d'),
          placeId: p.id,
          goalId: g.id,
          type: HelpType.itens,
          amount: (g.target / 8).ceilToDouble(),
          date: DateTime.now(),
          donor: 'Carlos',
          when: DateTime.now().add(const Duration(days: 2)),
          status: DonationStatus.itemsAgreed,
        ),
        HelpType.voluntariado => Donation(
          id: nextId('d'),
          placeId: p.id,
          goalId: g.id,
          type: HelpType.voluntariado,
          amount: 1,
          date: DateTime.now(),
          donor: 'Ana',
          when: g.action?.day,
          status: DonationStatus.enrolled,
        ),
      };
      if (g.type == HelpType.voluntariado) g.enrolled++;
      donations.add(d);
      if (g.type != HelpType.voluntariado) {
        _notice(
          NoticeKind.newDonation,
          'Nova doação para confirmar',
          '${d.donor} registrou ${_what(d, g)}.',
          placeId: p.id,
        );
      }
      notifyListeners();
    });
  }

  // ── Institution: signup and edits ─────────────────────────
  PointDraft startDraft() => draft ??= (PointDraft()..responsible = fullName.isEmpty ? '' : fullName);

  Place submitDraft() {
    final d = draft!;
    final p = Place(
      id: nextId('p'),
      name: d.name.trim(),
      point: d.point ?? center,
      kind: PlaceKind.fromType(d.type),
      typeLabel: d.type,
      neighborhood: d.neighborhood.trim(),
      street: d.street.trim(),
      number: d.number.trim(),
      complement: d.complement.trim(),
      cep: d.cep,
      city: d.city.isEmpty ? (onboarding.city ?? 'São José do Rio Preto') : d.city,
      hours: d.hours.trim(),
      receiveDays: Place.daysFromText(d.hours),
      about: d.about.trim(),
      causes: {...onboarding.selectedCauses.take(2)},
      cnpj: d.hasCnpj == true ? d.cnpj : null,
      legalName: d.legalName,
      cnpjStatus: d.cnpjStatus.isEmpty ? 'ativa' : d.cnpjStatus,
      indicatedBy: d.hasCnpj == false ? d.indicatedBy : null,
      accepts: {...d.accepts},
      pixKeyType: d.accepts.contains(HelpType.pix) ? d.pixKeyType : null,
      pixKey: d.accepts.contains(HelpType.pix) ? d.pixKey.trim() : null,
      payee: d.accepts.contains(HelpType.pix) ? d.payee.trim() : null,
      status: d.hasCnpj == false ? PlaceStatus.awaitingIndication : PlaceStatus.review,
      responsible: d.responsible.trim(),
      phone: d.phone,
      photo: d.photo,
    );
    final existing = myPoint;
    if (existing != null) {
      places.remove(existing);
      queue.removeWhere((s) => s.place.id == existing.id);
    }
    places.add(p);
    myPointId = p.id;
    approvalSeen = false;
    draft = null;
    if (p.status == PlaceStatus.awaitingIndication) {
      // The indicating institution accepts after a while in the demo.
      _later(const Duration(seconds: 20), () {
        if (p.status != PlaceStatus.awaitingIndication) return;
        p.status = PlaceStatus.review;
        _enqueue(p, existing == null ? SubmissionKind.novo : SubmissionKind.correcao);
        notifyListeners();
      });
    } else {
      _enqueue(p, existing == null ? SubmissionKind.novo : SubmissionKind.correcao);
    }
    notifyListeners();
    return p;
  }

  void _enqueue(Place p, SubmissionKind kind, [Map<String, String> changes = const {}]) {
    queue.insert(0, Submission(id: nextId('s'), place: p, kind: kind, sentAt: DateTime.now(), changes: changes));
  }

  /// Reopens the signup with the data already sent ("Corrigir cadastro").
  void reopenDraft(Place p) {
    draft = PointDraft()
      ..step = 5
      ..responsible = p.responsible
      ..phone = p.phone
      ..phoneVerified = true
      ..hasCnpj = p.cnpj != null
      ..cnpj = p.cnpj ?? ''
      ..legalName = p.legalName
      ..cnpjStatus = p.cnpjStatus
      ..cnpjConfirmed = p.cnpj != null
      ..indicatedBy = p.indicatedBy
      ..name = p.name
      ..type = p.typeLabel
      ..about = p.about
      ..cep = p.cep
      ..street = p.street
      ..number = p.number
      ..complement = p.complement
      ..neighborhood = p.neighborhood
      ..city = p.city
      ..point = p.point
      ..hours = p.hours
      ..photo = p.photo
      ..pixKeyType = p.pixKeyType ?? 'CNPJ'
      ..pixKey = p.pixKey ?? ''
      ..payee = p.payee ?? '';
    draft!.accepts.addAll(p.accepts);
    notifyListeners();
  }

  void renewReview(Place p) {
    p.lastReviewed = DateTime.now();
    notifyListeners();
  }

  /// Address, photo or responsible: the point stays as it is until approved.
  void requestChange(Place p, Map<String, String> changes) {
    queue.removeWhere((s) => s.place.id == p.id && s.kind == SubmissionKind.mudanca);
    _enqueue(p, SubmissionKind.mudanca, changes);
    notifyListeners();
  }

  void changePixKey(Place p, String type, String key, String payee) {
    p.pixPaused = true;
    requestChange(p, {'Chave Pix': '$type: $key', 'Favorecido': payee});
  }

  // ── Team ──────────────────────────────────────────────────
  List<Submission> queueOf(SubmissionKind k) => queue.where((s) => s.kind == k).toList();

  Map<String, List<Report>> get openReports {
    final map = <String, List<Report>>{};
    for (final r in reports) {
      map.putIfAbsent(r.placeId, () => []).add(r);
    }
    return map;
  }

  void approve(Submission s) {
    final p = s.place;
    queue.remove(s);
    if (s.kind == SubmissionKind.mudanca) {
      _applyChanges(p, s.changes);
      p.pixPaused = false;
      p.lastReviewed = DateTime.now();
    } else {
      p.status = PlaceStatus.active;
      p.verifiedAt = DateTime.now();
      p.lastReviewed = DateTime.now();
      if (!places.contains(p)) places.add(p);
      for (final g in p.goals) {
        if (!g.published) {
          g.published = true;
          _simulateDonor(p, g);
        }
      }
    }
    if (p.id == myPointId && s.kind != SubmissionKind.mudanca && simulateReplies) {
      _later(const Duration(seconds: 30), () {
        if (monthly.any((m) => m.placeId == p.id)) return;
        monthly.add(MonthlyGift(id: nextId('m'), placeId: p.id, amount: 30, day: 10, donor: 'Marina S.'));
        _notice(
          NoticeKind.newDonation,
          'Nova doação mensal',
          'Marina S. vai doar ${Fmt.money(30)} todo mês para ${p.name}.',
          placeId: p.id,
        );
        notifyListeners();
      });
    }
    if (p.id == myPointId) {
      _notice(
        NoticeKind.approved,
        '${p.name} está no mapa',
        'Seu ponto foi verificado. Já dá para criar metas.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  void _applyChanges(Place p, Map<String, String> c) {
    final key = c['Chave Pix'];
    if (key != null) {
      final i = key.indexOf(': ');
      p.pixKeyType = key.substring(0, i);
      p.pixKey = key.substring(i + 2);
      p.payee = c['Favorecido'] ?? p.payee;
    }
    if (c['Responsável'] != null) p.responsible = c['Responsável']!;
    if (c['Endereço'] != null) {
      final parts = c['Endereço']!.split(' · ');
      p.street = parts.first.split(', ').first;
      p.number = parts.first.split(', ').skip(1).join(', ');
      if (parts.length > 1) p.neighborhood = parts[1];
    }
    if (c['Foto'] != null) p.photo = c['Foto'];
  }

  void askAdjust(Submission s, List<String> reasons, String message) {
    final p = s.place;
    queue.remove(s);
    p.status = PlaceStatus.adjust;
    p.statusReason = reasons.map((r) => r[0].toLowerCase() + r.substring(1)).join('; ');
    p.statusMessage = message.trim();
    if (p.id == myPointId) {
      _notice(
        NoticeKind.adjust,
        'Seu cadastro precisa de um ajuste',
        'Motivo: ${p.statusReason}. Toque para corrigir.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  void refuse(Submission s, String reason) {
    final p = s.place;
    queue.remove(s);
    p.status = PlaceStatus.refused;
    p.statusReason = reason.trim();
    if (p.id == myPointId) {
      _notice(NoticeKind.refused, 'Seu cadastro não foi aprovado', 'Motivo: ${p.statusReason}.', placeId: p.id);
    }
    notifyListeners();
  }

  void keepOnMap(String placeId) {
    reports.removeWhere((r) => r.placeId == placeId);
    notifyListeners();
  }

  void pause(String placeId, String reason) {
    final p = place(placeId);
    p.status = PlaceStatus.paused;
    p.statusReason = reason.trim();
    reports.removeWhere((r) => r.placeId == placeId);
    if (p.id == myPointId) {
      _notice(
        NoticeKind.paused,
        'Seu ponto foi pausado',
        'Recebemos uma denúncia e estamos analisando. Motivo: ${p.statusReason}.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  void remove(String placeId, String reason) {
    final p = place(placeId);
    p.status = PlaceStatus.removed;
    p.statusReason = reason.trim();
    for (final g in p.goals.where((g) => g.status == GoalStatus.open)) {
      g.status = GoalStatus.closed;
    }
    reports.removeWhere((r) => r.placeId == placeId);
    notifyListeners();
  }

  void reactivate(String placeId) {
    final p = place(placeId);
    p.status = PlaceStatus.active;
    p.statusReason = null;
    if (p.id == myPointId) {
      _notice(
        NoticeKind.reactivated,
        '${p.name} está de volta no mapa',
        'A análise terminou. Suas metas voltaram a aparecer.',
        placeId: p.id,
      );
    }
    notifyListeners();
  }

  // ── Dev shortcut: an approved point with work to do ───────
  void seedDemoInstitution() {
    init();
    final p = Place(
      id: 'meu-ponto',
      name: 'Cozinha Comunitária Vila Nova',
      point: LatLng(center.latitude - .006, center.longitude + .012),
      kind: PlaceKind.care,
      typeLabel: 'Associação',
      neighborhood: 'Vila Nova',
      street: 'Rua Bahia',
      number: '512',
      hours: 'segunda a sexta, das 8h às 17h',
      receiveDays: {1, 2, 3, 4, 5},
      about: 'Servimos almoço para 60 famílias do bairro, de segunda a sexta.',
      causes: {'Alimentos'},
      verifiedAt: DateTime.now().subtract(const Duration(days: 30)),
      cnpj: '22.333.444/0001-55',
      legalName: 'Associação Cozinha Comunitária Vila Nova',
      accepts: {HelpType.pix, HelpType.itens, HelpType.voluntariado},
      pixKeyType: 'CNPJ',
      pixKey: '22.333.444/0001-55',
      payee: 'Associação Cozinha Comunitária Vila Nova',
      responsible: fullName.isEmpty ? 'Enzo Silva' : fullName,
      phone: '(17) 99999-1234',
      lastReviewed: DateTime.now().subtract(const Duration(days: 40)),
      goals: [
        Goal(
          id: 'm1',
          type: HelpType.itens,
          target: 60,
          current: 34,
          item: 'feijão',
          unit: 'kg',
          deadline: DateTime.now().add(const Duration(days: 5)),
          reason: 'o número de famílias atendidas subiu de 45 para 60.',
          cause: 'Alimentos',
          helpers: 11,
        ),
        Goal(
          id: 'm2',
          type: HelpType.pix,
          target: 800,
          current: 350,
          deadline: DateTime.now().add(const Duration(days: 9)),
          reason: 'trocar o botijão e a mangueira do fogão industrial.',
          cause: 'Alimentos',
          helpers: 9,
        ),
        Goal(
          id: 'm3',
          type: HelpType.voluntariado,
          target: 6,
          enrolled: 2,
          deadline: DateTime.now().add(const Duration(days: 3)),
          reason: 'a entrega de cestas dobrou neste mês.',
          cause: 'Alimentos',
          action: VolunteerAction(
            name: 'Separar doações',
            task: 'Separar e organizar os alimentos que chegaram na semana.',
            day: DateTime.now().add(const Duration(days: 3)),
            start: 9 * 60,
            end: 12 * 60,
          ),
        ),
        Goal(
          id: 'm4',
          type: HelpType.itens,
          target: 40,
          current: 26,
          item: 'óleo',
          unit: 'litros',
          deadline: DateTime.now().subtract(const Duration(days: 1)),
          reason: 'o estoque de óleo acabou depois da festa junina.',
          cause: 'Alimentos',
          status: GoalStatus.expired,
          helpers: 8,
        ),
      ],
    );
    places.add(p);
    myPointId = p.id;
    approvalSeen = true;
    monthly.addAll([
      MonthlyGift(id: nextId('m'), placeId: p.id, amount: 30, day: 10, donor: 'Marina S.'),
      MonthlyGift(id: nextId('m'), placeId: p.id, amount: 50, day: 5, donor: 'Paulo R.'),
    ]);
    DateTime ago(int h) => DateTime.now().subtract(Duration(hours: h));
    donations.addAll([
      Donation(
        id: nextId('d'),
        placeId: p.id,
        goalId: 'm2',
        type: HelpType.pix,
        amount: 80,
        date: ago(80),
        donor: 'Beatriz',
        receipt: true,
      ),
      Donation(
        id: nextId('d'),
        placeId: p.id,
        goalId: 'm2',
        type: HelpType.pix,
        amount: 25,
        date: ago(5),
        donor: 'Rafael',
      ),
      Donation(
        id: nextId('d'),
        placeId: p.id,
        goalId: 'm1',
        type: HelpType.itens,
        amount: 5,
        date: ago(20),
        donor: 'Luíza',
        when: DateTime.now().add(const Duration(days: 1)),
        status: DonationStatus.itemsAgreed,
      ),
      Donation(
        id: nextId('d'),
        placeId: p.id,
        goalId: 'm2',
        type: HelpType.pix,
        amount: 100,
        date: ago(48),
        donor: 'João',
        status: DonationStatus.confirmed,
        confirmedAt: ago(40),
      ),
      for (final n in ['Ana', 'Carlos'])
        Donation(
          id: nextId('d'),
          placeId: p.id,
          goalId: 'm3',
          type: HelpType.voluntariado,
          amount: 1,
          date: ago(30),
          donor: n,
          when: p.goals[2].action!.day,
          status: DonationStatus.enrolled,
        ),
    ]);
  }
}

final store = AppStore();
