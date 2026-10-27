import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, RealtimeChannel, StorageException, Supabase;

import 'models.dart';
import 'remote.dart' as remote;

export 'models.dart';

enum AppMode { donor, institution, team }

/// Signup draft for the institution's point. Kept on the device while the
/// person goes through the 5 steps; it reaches the database on "Enviar".
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

/// App-wide state. Screens read the lists here and call the actions below.
/// The data comes from Supabase (lib/data/remote.dart): each action updates
/// the screen right away, saves in the background and then reloads, so the
/// app ends up exactly like the database. If the database refuses (no slots
/// left, goal closed…), [errors] carries the message and the reload undoes it.
class AppStore extends ChangeNotifier {
  // ── Account ───────────────────────────────────────────────
  String name = 'você';
  String fullName = '';
  String email = '';
  String userPhone = '';
  DateTime? birthDate;

  /// Profile photo: a Storage link, or the local file just picked.
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

  /// Validation team member (profiles.is_team, set only in the database).
  bool isTeam = false;
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

  // ── Sync ──────────────────────────────────────────────────
  /// Messages for the person when the database refuses an action
  /// (main.dart shows them as a toast).
  final errors = StreamController<String>.broadcast();

  /// True until the first load finishes.
  bool loading = true;

  bool _ready = false;
  Future<void>? _loading;
  bool _again = false;
  RealtimeChannel? _channel;

  String nextId(String _) => remote.newId();

  /// Loads everything the first time a shell opens.
  Future<void> init() {
    if (_ready) return _loading ?? Future.value();
    _ready = true;
    center = onboarding.position ?? center;
    filterCauses.addAll(onboarding.selectedCauses);
    return refresh();
  }

  /// Reads everything again from the database. Calls that arrive during a
  /// load wait for it and run once more at the end.
  Future<void> refresh() {
    if (_loading != null) {
      _again = true;
      return _loading!;
    }
    return _loading = _load().whenComplete(() {
      _loading = null;
      if (_again) {
        _again = false;
        refresh();
      }
    });
  }

  Future<void> _load() async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      final s = await remote.loadAll(center: center, isTeam: isTeam);
      _apply(s);
    } catch (e) {
      debugPrint('store: load failed: $e');
      if (loading) errors.add('Não deu para carregar os pontos. Confira a internet.');
    }
    loading = false;
    _channel ??= remote.listen(isTeam: isTeam, onChange: refresh);
    notifyListeners();
  }

  void _apply(remote.Snapshot s) {
    // Same objects for the same ids, so open screens show the new data.
    final old = {for (final p in places) p.id: p};
    places
      ..clear()
      ..addAll([for (final p in s.places) (old[p.id]?..updateFrom(p)) ?? p]);
    myPointId = s.myPointId;
    donations
      ..clear()
      ..addAll(s.donations);
    monthly
      ..clear()
      ..addAll(s.monthly);
    followed
      ..clear()
      ..addAll(s.followed);
    notices
      ..clear()
      ..addAll(s.notices);
    final byId = {for (final p in places) p.id: p};
    queue
      ..clear()
      ..addAll([
        for (final q in s.queue)
          Submission(id: q.id, place: byId[q.place.id]!, kind: q.kind, sentAt: q.sentAt, changes: q.changes),
      ]);
    reports
      ..clear()
      ..addAll(s.reports);
  }

  /// Logout: forgets everything that belonged to the person.
  Future<void> reset() async {
    if (_channel != null) await remote.stopListening(_channel!);
    _channel = null;
    _ready = false;
    loading = true;
    for (final l in <List<Object>>[places, donations, notices, reports, queue, monthly]) {
      l.clear();
    }
    followed.clear();
    filterTypes.clear();
    filterCauses.clear();
    myPointId = null;
    draft = null;
    mode = AppMode.donor;
    isTeam = false;
    approvalSeen = false;
    mapCenter = null;
    radiusKm = 5;
    notifyListeners();
  }

  /// Saves in the background, then reloads (also after an error, to undo
  /// what the screen showed ahead of time).
  void _save(Future<void> Function() call) {
    notifyListeners();
    call().then(
      (_) => refresh(),
      onError: (Object e) {
        debugPrint('store: save failed: $e');
        errors.add(_message(e));
        refresh();
      },
    );
  }

  /// Messages written in the SQL functions (RAISE EXCEPTION) are already
  /// for the person; anything else becomes a generic message.
  static String _message(Object e) {
    if (e is PostgrestException && e.code == 'P0001') return e.message;
    if (e is StorageException) return 'Não deu para enviar a foto. Tente de novo.';
    return 'Não deu para salvar agora. Confira a internet e tente de novo.';
  }

  void touch() => notifyListeners();

  // ── Lookups ───────────────────────────────────────────────
  Place place(String id) => places.firstWhere((p) => p.id == id);

  Place? placeOrNull(String id) => places.where((p) => p.id == id).firstOrNull;

  Goal? goal(Place p, String id) => p.goals.where((g) => g.id == id).firstOrNull;

  Place? get myPoint => myPointId == null ? null : placeOrNull(myPointId!);

  List<Place> get verifiedPlaces => places.where((p) => p.verifiedAt != null && p.onMap).toList();

  /// Only donations whose point is loaded (a paused point leaves the map).
  List<Donation> get myDonations =>
      donations.where((d) => d.mine && placeOrNull(d.placeId) != null).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

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
    _save(() => remote.follow(placeId));
  }

  void unfollow(String placeId) {
    followed.remove(placeId);
    _save(() => remote.unfollow(placeId));
  }

  /// [receiptFile]: the receipt photo picked on the device, if any.
  Donation registerPix(Place p, Goal g, double amount, {String? receiptFile}) {
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: g.id,
      type: HelpType.pix,
      amount: amount,
      date: DateTime.now(),
      donor: name,
      mine: true,
      receipt: receiptFile != null,
    );
    donations.add(d);
    _save(() => remote.insertDonation(d, receiptFile: receiptFile));
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
    _save(() => remote.insertDonation(d));
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
    _save(() => remote.insertDonation(d));
    return d;
  }

  void cancelEnrollment(Donation d) {
    final g = goal(place(d.placeId), d.goalId);
    if (g != null && g.enrolled > 0) g.enrolled--;
    d.status = DonationStatus.cancelled;
    _save(() => remote.cancelEnrollment(d.id));
  }

  void rate(Donation d, int stars, String comment) {
    place(d.placeId).reviews.insert(0, Review(name, DateTime.now(), stars, comment.trim()));
    d.rated = true;
    _save(() => remote.rate(d, stars, comment.trim()));
  }

  void report(String placeId, String reason, String text) {
    _save(() => remote.report(placeId, reason, text.trim()));
  }

  void markRead(Notice n) {
    n.read = true;
    _save(() => remote.markRead(n.id));
  }

  void markAllRead() {
    for (final n in notices) {
      n.read = true;
    }
    _save(remote.markAllRead);
  }

  // ── Donor: monthly Pix ────────────────────────────────────
  MonthlyGift? monthlyFor(String placeId) => monthly.where((m) => m.mine && m.placeId == placeId).firstOrNull;

  List<MonthlyGift> get myMonthly => monthly.where((m) => m.mine && placeOrNull(m.placeId) != null).toList();

  /// Active monthly donors of a point (institution side).
  List<MonthlyGift> monthlyDonors(String placeId) => monthly.where((m) => m.placeId == placeId && !m.paused).toList();

  MonthlyGift startMonthly(Place p, double amount, int day) {
    final m = MonthlyGift(id: nextId('m'), placeId: p.id, amount: amount, day: day, donor: name, mine: true);
    monthly.add(m);
    _save(() => remote.insertMonthly(m));
    return m;
  }

  void updateMonthly(MonthlyGift m, {required double amount, required int day}) {
    m
      ..amount = amount
      ..day = day;
    _save(() => remote.updateMonthly(m));
  }

  void toggleMonthly(MonthlyGift m) {
    m.paused = !m.paused;
    _save(() => remote.updateMonthly(m));
  }

  void cancelMonthly(MonthlyGift m) {
    monthly.remove(m);
    _save(() => remote.deleteMonthly(m.id));
  }

  /// This month's payment, registered as a regular Pix donation. It counts
  /// towards the point's open Pix goal when there is one.
  Donation payMonthly(MonthlyGift m, {String? receiptFile}) {
    final p = place(m.placeId);
    final g = p.openGoals.where((g) => g.type == HelpType.pix).firstOrNull;
    m.markPaid();
    final d = Donation(
      id: nextId('d'),
      placeId: p.id,
      goalId: g?.id ?? '',
      type: HelpType.pix,
      amount: m.amount,
      date: DateTime.now(),
      donor: name,
      mine: true,
      receipt: receiptFile != null,
    );
    donations.add(d);
    _save(() => remote.insertDonation(d, monthlyGiftId: m.id, receiptFile: receiptFile));
    return d;
  }

  // ── Institution: donations ────────────────────────────────
  void confirm(Donation d) {
    _confirmHere(d);
    _save(() => remote.confirmDonation(d.id));
  }

  /// What the database does on confirm (fase 5), shown ahead of time.
  void _confirmHere(Donation d) {
    d.status = DonationStatus.confirmed;
    d.confirmedAt = DateTime.now();
    final g = goal(place(d.placeId), d.goalId);
    if (g == null) return;
    g.current += d.amount;
    g.helpers++;
    if (g.current >= g.target && g.status == GoalStatus.open) {
      g.status = GoalStatus.done;
      g.doneAt = DateTime.now();
    }
  }

  void markNotFound(Donation d) {
    d.status = DonationStatus.notFound;
    _save(() => remote.markNotFound(d.id));
  }

  /// "Salvar presença": participants count for the goal and can rate.
  void savePresence(Goal g, Map<String, bool> attended) {
    for (final e in attended.entries) {
      final d = donations.firstWhere((x) => x.id == e.key);
      e.value ? _confirmHere(d) : d.status = DonationStatus.absent;
    }
    _save(() async {
      for (final e in attended.entries) {
        await (e.value ? remote.confirmDonation(e.key) : remote.markAbsent(e.key));
      }
    });
  }

  void cancelAction(Goal g) {
    g.status = GoalStatus.closed;
    g.doneAt = DateTime.now();
    for (final d in donations.where((d) => d.goalId == g.id && d.status == DonationStatus.enrolled)) {
      d.status = DonationStatus.cancelled;
    }
    _save(() => remote.cancelAction(g.id));
  }

  // ── Institution: goals ────────────────────────────────────
  void addGoal(Place p, Goal g) {
    p.goals.add(g);
    _save(() => remote.insertGoal(p.id, g));
  }

  void closeGoal(Goal g) {
    g.status = GoalStatus.closed;
    g.doneAt = DateTime.now();
    _save(() => remote.closeGoal(g.id));
  }

  void extendGoal(Goal g, DateTime deadline) {
    g.deadline = deadline;
    g.status = GoalStatus.open;
    g.doneAt = null;
    _save(() => remote.extendGoal(g.id, deadline));
  }

  /// The institution saw the "Meta concluída" card.
  void markGoalSeen(Goal g) {
    g.seenDone = true;
    _save(() => remote.markGoalSeen(g.id));
  }

  // ── Institution: signup and edits ─────────────────────────
  PointDraft startDraft() => draft ??= (PointDraft()..responsible = fullName.isEmpty ? '' : fullName);

  Place submitDraft() {
    final d = draft!;
    final existing = myPoint;
    // A point sent back for adjustment is fixed in place; after a refusal
    // or removal the person starts a new one.
    final fixing =
        existing != null && (existing.status == PlaceStatus.adjust || existing.status == PlaceStatus.draft);
    final p = Place(
      id: fixing ? existing.id : nextId('p'),
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
      causes: fixing ? existing.causes : {...onboarding.selectedCauses.take(2)},
      cnpj: d.hasCnpj == true ? d.cnpj : null,
      legalName: d.legalName,
      cnpjStatus: d.cnpjStatus.isEmpty ? 'ativa' : d.cnpjStatus,
      indicatedBy: d.hasCnpj == false ? d.indicatedBy : null,
      accepts: {...d.accepts},
      pixKeyType: d.accepts.contains(HelpType.pix) ? d.pixKeyType : null,
      pixKey: d.accepts.contains(HelpType.pix) ? d.pixKey.trim() : null,
      payee: d.accepts.contains(HelpType.pix) ? d.payee.trim() : null,
      // Points without CNPJ also go straight to the team, which checks
      // the indication (product decision).
      status: PlaceStatus.review,
      responsible: d.responsible.trim(),
      phone: d.phone,
      photo: d.photo,
    );
    if (fixing) {
      p.goals.addAll(existing.goals);
      places.remove(existing);
    }
    places.add(p);
    myPointId = p.id;
    approvalSeen = false;
    draft = null;
    final indicatedById = d.hasCnpj == false
        ? verifiedPlaces.where((x) => x.name == d.indicatedBy).firstOrNull?.id
        : null;
    _save(
      () => remote.savePlace(p, isNew: !fixing, indicatedById: indicatedById, cnpjUnchecked: d.cnpjUnchecked),
    );
    return p;
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
    _save(() => remote.renewReview(p.id));
  }

  /// Name, "sobre", what it distributes and hours: saved right away.
  void savePlaceInfo(Place p) => _save(() => remote.editPlace(p));

  /// Address, photo or responsible: the point stays as it is until approved.
  void requestChange(Place p, Map<String, String> changes) {
    _save(() => remote.requestChange(p, changes));
  }

  void changePixKey(Place p, String type, String key, String payee) {
    p.pixPaused = true;
    _save(() => remote.changePixKey(p.id, type, key, payee));
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
    queue.remove(s);
    if (s.kind != SubmissionKind.mudanca) {
      s.place
        ..status = PlaceStatus.active
        ..verifiedAt ??= DateTime.now();
    }
    _save(() => remote.approve(s.id));
  }

  void askAdjust(Submission s, List<String> reasons, String message) {
    queue.remove(s);
    final text = reasons.map((r) => r[0].toLowerCase() + r.substring(1)).join('; ');
    if (s.kind != SubmissionKind.mudanca) s.place.status = PlaceStatus.adjust;
    _save(() => remote.askAdjust(s.id, text, message.trim()));
  }

  void refuse(Submission s, String reason) {
    queue.remove(s);
    if (s.kind != SubmissionKind.mudanca) s.place.status = PlaceStatus.refused;
    _save(() => remote.refuse(s.id, reason.trim()));
  }

  void keepOnMap(String placeId) {
    reports.removeWhere((r) => r.placeId == placeId);
    _save(() => remote.keepOnMap(placeId));
  }

  void pause(String placeId, String reason) {
    place(placeId).status = PlaceStatus.paused;
    reports.removeWhere((r) => r.placeId == placeId);
    _save(() => remote.pausePlace(placeId, reason.trim()));
  }

  void remove(String placeId, String reason) {
    place(placeId).status = PlaceStatus.removed;
    reports.removeWhere((r) => r.placeId == placeId);
    _save(() => remote.removePlace(placeId, reason.trim()));
  }

  void reactivate(String placeId) {
    place(placeId).status = PlaceStatus.active;
    _save(() => remote.reactivatePlace(placeId));
  }
}

final store = AppStore();
