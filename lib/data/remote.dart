import 'dart:io';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

// Conversa com as tabelas do Supabase (fases 3 a 8). O store.dart chama
// estas funções; as telas continuam lendo só o store.
//
// Os nomes no banco são snake_case e os do Dart, camelCase:
// "awaiting_indication" ↔ PlaceStatus.awaitingIndication.

final _db = Supabase.instance.client;

String get _uid => _db.auth.currentUser!.id;

/// Id novo (UUID v4) criado no aparelho. Assim a doação ou a meta aparece na
/// tela na hora, com o mesmo id que vai ter no banco.
String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String _snake(String camel) => camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

T _enum<T extends Enum>(List<T> values, String snake) {
  final camel = snake.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());
  return values.byName(camel);
}

DateTime? _time(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

DateTime _date(Object? v) => DateTime.parse(v as String);

double _num(Object? v) => (v as num).toDouble();

Set<HelpType> _helpTypes(Object? v) => {for (final t in (v as List).cast<String>()) HelpType.values.byName(t)};

String _day(DateTime d) => d.toIso8601String().substring(0, 10);

// ── Leitura: tudo o que a pessoa enxerga ─────────────────────

/// Fotografia do banco para o store. Cada lista já vem convertida.
class Snapshot {
  Snapshot({
    required this.places,
    required this.myPointId,
    required this.donations,
    required this.monthly,
    required this.followed,
    required this.notices,
    required this.queue,
    required this.reports,
  });

  final List<Place> places;
  final String? myPointId;
  final List<Donation> donations;
  final List<MonthlyGift> monthly;
  final Set<String> followed;
  final List<Notice> notices;
  final List<Submission> queue;
  final List<Report> reports;
}

Future<Snapshot> loadAll({required LatLng center, required bool isTeam}) async {
  final uid = _uid;

  // Pontos: os ativos até 50 km, o da pessoa (em qualquer situação) e, para a
  // equipe, todos. Juntados por id, sem repetir.
  final rows = <String, Map<String, dynamic>>{};
  void add(List<dynamic> list) {
    for (final r in list.cast<Map<String, dynamic>>()) {
      rows[r['id'] as String] = r;
    }
  }

  add(await _db.rpc('places_near', params: {'lat': center.latitude, 'lng': center.longitude, 'km': 50}));
  final mine = await _db.from('places_geo').select().eq('owner_id', uid).order('created_at', ascending: false);
  add(mine);
  if (isTeam) add(await _db.from('places_geo').select());

  final myDonationRows = await _db.from('donations').select().eq('donor_id', uid);
  final myMonthlyRows = await _db.from('monthly_gifts').select().eq('donor_id', uid);
  final followRows = await _db.from('follows').select('place_id').eq('user_id', uid);
  final noticeRows = await _db
      .from('notices')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(100);
  final ratedRows = await _db.from('reviews').select('donation_id').eq('author_id', uid);

  // Pontos que a pessoa segue ou ajudou e que ficam além dos 50 km.
  final missing = {
    for (final r in [...myDonationRows, ...myMonthlyRows, ...followRows]) r['place_id'] as String,
  }.difference(rows.keys.toSet());
  if (missing.isNotEmpty) add(await _db.from('places_geo').select().inFilter('id', missing.toList()));

  final ids = rows.keys.toList();
  final goalRows = ids.isEmpty ? <Map<String, dynamic>>[] : await _db.from('goals').select().inFilter('place_id', ids);
  final reviewRows = ids.isEmpty
      ? <Map<String, dynamic>>[]
      : await _db.from('reviews').select().inFilter('place_id', ids).order('created_at', ascending: false);

  final places = [for (final r in rows.values) _place(r)];
  final byId = {for (final p in places) p.id: p};
  // Nome e telefone do responsável não vêm na view (privacidade): só o dono
  // do ponto e a equipe recebem, por esta função.
  if (ids.isNotEmpty) {
    for (final c in await _db.rpc('place_contacts', params: {'ids': ids}) as List) {
      byId[c['id']]
        ?..responsible = c['responsible'] as String
        ..phone = c['phone'] as String;
    }
  }
  for (final g in goalRows) {
    byId[g['place_id']]?.goals.add(_goal(g));
  }
  for (final r in reviewRows) {
    byId[r['place_id']]?.reviews.add(
      Review(r['author_name'] as String, _time(r['created_at'])!, r['stars'] as int, r['comment'] as String),
    );
  }
  // "Indicada por": o banco guarda o id; a tela mostra o nome.
  for (final r in rows.values) {
    final by = r['indicated_by'] as String?;
    if (by != null) byId[r['id']]!.indicatedBy = byId[by]?.name ?? 'outra instituição';
  }

  // Uma conta, um ponto. A conta de teste do seed tem 14: fica o primeiro
  // ativo (o mais recente; no empate, o menor id), sempre o mesmo.
  final ranked = [...mine]
    ..sort((a, b) {
      int rank(Map r) => r['status'] == 'active' ? 0 : 1;
      final byStatus = rank(a).compareTo(rank(b));
      if (byStatus != 0) return byStatus;
      final byDate = (b['created_at'] as String).compareTo(a['created_at'] as String);
      return byDate != 0 ? byDate : (a['id'] as String).compareTo(b['id'] as String);
    });
  final myPointId = ranked.isEmpty ? null : ranked.first['id'] as String;

  // Doações: as minhas e, para a instituição, as que o ponto recebeu.
  final rated = {for (final r in ratedRows) r['donation_id'] as String};
  final donationRows = {for (final r in myDonationRows) r['id'] as String: r};
  final monthlyRows = {for (final r in myMonthlyRows) r['id'] as String: r};
  if (myPointId != null) {
    for (final r in await _db.from('donations').select().eq('place_id', myPointId)) {
      donationRows[r['id'] as String] = r;
    }
    for (final r in await _db.from('monthly_gifts').select().eq('place_id', myPointId)) {
      monthlyRows[r['id'] as String] = r;
    }
  }
  final donations = [for (final r in donationRows.values) _donation(r, uid, rated)];

  final monthly = [for (final r in monthlyRows.values) _monthly(r, uid)];
  for (final m in monthly) {
    for (final r in myDonationRows.where((d) => d['monthly_gift_id'] == m.id)) {
      final d = _time(r['created_at'])!;
      m.paidMonths.add(DateTime(d.year, d.month));
    }
  }

  // Equipe: a fila e as denúncias que ainda estão abertas.
  final queue = <Submission>[];
  final reports = <Report>[];
  if (isTeam) {
    for (final r in await _db.from('submissions').select().isFilter('resolved_at', null)) {
      final p = byId[r['place_id']];
      if (p == null) continue;
      queue.add(
        Submission(
          id: r['id'] as String,
          place: p,
          kind: _enum(SubmissionKind.values, r['kind'] as String),
          sentAt: _time(r['sent_at'])!,
          changes: (r['changes'] as Map).map((k, v) => MapEntry(k as String, '$v')),
        ),
      );
    }
    for (final r in await _db.from('reports').select().isFilter('resolved_at', null)) {
      reports.add(
        Report(
          placeId: r['place_id'] as String,
          reason: r['reason'] as String,
          text: r['body'] as String,
          date: _time(r['created_at'])!,
        ),
      );
    }
  }

  return Snapshot(
    places: places,
    myPointId: myPointId,
    donations: donations,
    monthly: monthly,
    followed: {for (final r in followRows) r['place_id'] as String},
    notices: [for (final r in noticeRows) _notice(r)],
    queue: queue,
    reports: reports,
  );
}

Place _place(Map<String, dynamic> r) {
  final lat = r['lat'] as num?;
  final lng = r['lng'] as num?;
  return Place(
    id: r['id'] as String,
    name: r['name'] as String,
    point: lat == null || lng == null ? const LatLng(0, 0) : LatLng(lat.toDouble(), lng.toDouble()),
    kind: PlaceKind.values.byName(r['kind'] as String),
    typeLabel: r['type_label'] as String,
    neighborhood: r['neighborhood'] as String,
    street: r['street'] as String,
    number: r['number'] as String,
    complement: r['complement'] as String,
    cep: r['cep'] as String,
    city: r['city'] as String,
    hours: r['hours'] as String,
    receiveDays: {...(r['receive_days'] as List).cast<int>()},
    about: r['about'] as String,
    distributes: r['distributes'] as String?,
    causes: {...(r['causes'] as List).cast<String>()},
    verifiedAt: _time(r['verified_at']),
    cnpj: r['cnpj'] as String?,
    legalName: r['legal_name'] as String,
    cnpjStatus: r['cnpj_status'] as String,
    accepts: _helpTypes(r['accepts']),
    pixKeyType: r['pix_key_type'] as String?,
    pixKey: r['pix_key'] as String?,
    payee: r['payee'] as String?,
    status: _enum(PlaceStatus.values, r['status'] as String),
    pixPaused: r['pix_paused'] as bool,
    lastReviewed: _time(r['last_reviewed']),
    responsible: r['responsible'] as String? ?? '',
    phone: r['phone'] as String? ?? '',
    photo: r['photo_path'] as String?,
    statusReason: r['status_reason'] as String?,
    statusMessage: r['status_message'] as String?,
  );
}

Goal _goal(Map<String, dynamic> r) {
  final type = HelpType.values.byName(r['type'] as String);
  return Goal(
    id: r['id'] as String,
    type: type,
    deadline: _date(r['deadline']),
    reason: r['reason'] as String,
    target: _num(r['target']),
    current: _num(r['current']),
    item: r['item'] as String,
    unit: r['unit'] as String,
    cause: r['cause'] as String?,
    action: type == HelpType.voluntariado
        ? VolunteerAction(
            name: r['action_name'] as String,
            task: r['action_task'] as String? ?? '',
            day: _date(r['action_day']),
            start: r['action_start'] as int,
            end: r['action_end'] as int,
          )
        : null,
    status: GoalStatus.values.byName(r['status'] as String),
    doneAt: _time(r['done_at']),
    helpers: r['helpers'] as int,
    enrolled: r['enrolled'] as int,
    published: r['published'] as bool,
  )..seenDone = r['seen_done'] as bool;
}

Donation _donation(Map<String, dynamic> r, String uid, Set<String> rated) => Donation(
  id: r['id'] as String,
  placeId: r['place_id'] as String,
  goalId: r['goal_id'] as String? ?? '',
  type: HelpType.values.byName(r['type'] as String),
  amount: _num(r['amount']),
  date: _time(r['created_at'])!,
  donor: r['donor_name'] as String,
  mine: r['donor_id'] == uid,
  when: r['scheduled_for'] == null ? null : _date(r['scheduled_for']),
  receiptPath: r['receipt_path'] as String?,
  status: _enum(DonationStatus.values, r['status'] as String),
  confirmedAt: _time(r['confirmed_at']),
  rated: rated.contains(r['id']),
);

MonthlyGift _monthly(Map<String, dynamic> r, String uid) => MonthlyGift(
  id: r['id'] as String,
  placeId: r['place_id'] as String,
  amount: _num(r['amount']),
  day: r['day'] as int,
  donor: r['donor_name'] as String,
  mine: r['donor_id'] == uid,
  since: _date(r['since']),
)..paused = r['paused'] as bool;

Notice _notice(Map<String, dynamic> r) => Notice(
  id: r['id'] as String,
  kind: _enum(NoticeKind.values, r['kind'] as String),
  title: r['title'] as String,
  text: r['body'] as String,
  date: _time(r['created_at'])!,
  placeId: r['place_id'] as String?,
  read: r['read'] as bool,
);

// ── Tempo real ───────────────────────────────────────────────

/// Avisa [onChange] quando chega um aviso novo para a pessoa e, para a
/// equipe, quando a fila ou as denúncias mudam (fase 7).
RealtimeChannel listen({required bool isTeam, required void Function() onChange}) {
  final channel = _db
      .channel('escora-$_uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'notices',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: _uid),
        callback: (_) => onChange(),
      );
  if (isTeam) {
    for (final table in ['submissions', 'reports']) {
      channel.onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: table, callback: (_) => onChange());
    }
  }
  return channel..subscribe();
}

Future<void> stopListening(RealtimeChannel channel) => _db.removeChannel(channel);

// ── Arquivos (Storage) ───────────────────────────────────────

/// Envia uma foto do aparelho para `balde/id-da-pessoa/nome.jpg`.
/// Devolve o caminho dentro do balde.
Future<String> _upload(String bucket, String localPath, String name) async {
  final path = '$_uid/$name.jpg';
  await _db.storage.from(bucket).upload(path, File(localPath), fileOptions: const FileOptions(contentType: 'image/jpeg'));
  return path;
}

/// Foto pública (ponto ou perfil): devolve o link que o app mostra.
Future<String> uploadPublicPhoto(String bucket, String localPath) async {
  final path = await _upload(bucket, localPath, newId());
  return _db.storage.from(bucket).getPublicUrl(path);
}

/// Comprovante privado: só um link temporário (1 hora) para quem pode ver.
Future<String> receiptUrl(String path) => _db.storage.from('receipts').createSignedUrl(path, 3600);

// ── Escrita: doador (fase 4) ─────────────────────────────────

Future<void> insertDonation(Donation d, {String? monthlyGiftId, String? receiptFile}) async {
  final receipt = receiptFile == null ? null : await _upload('receipts', receiptFile, d.id);
  await _db.from('donations').insert({
    'id': d.id,
    'place_id': d.placeId,
    'goal_id': d.goalId.isEmpty ? null : d.goalId,
    'donor_id': _uid,
    'monthly_gift_id': monthlyGiftId,
    'type': d.type.name,
    'amount': d.amount,
    'scheduled_for': d.when == null ? null : _day(d.when!),
    'receipt_path': receipt,
  });
}

Future<void> cancelEnrollment(String donationId) => _db.rpc('cancel_enrollment', params: {'donation': donationId});

Future<void> follow(String placeId) => _db.from('follows').upsert({'user_id': _uid, 'place_id': placeId});

Future<void> unfollow(String placeId) => _db.from('follows').delete().eq('user_id', _uid).eq('place_id', placeId);

Future<void> rate(Donation d, int stars, String comment) => _db.from('reviews').insert({
  'donation_id': d.id,
  'place_id': d.placeId,
  'author_id': _uid,
  'stars': stars,
  'comment': comment,
});

Future<void> report(String placeId, String reason, String text) =>
    _db.from('reports').insert({'place_id': placeId, 'author_id': _uid, 'reason': reason, 'body': text});

Future<void> markRead(String noticeId) => _db.from('notices').update({'read': true}).eq('id', noticeId);

Future<void> markAllRead() => _db.from('notices').update({'read': true}).eq('user_id', _uid).eq('read', false);

Future<void> insertMonthly(MonthlyGift m) => _db.from('monthly_gifts').insert({
  'id': m.id,
  'donor_id': _uid,
  'place_id': m.placeId,
  'amount': m.amount,
  'day': m.day,
});

Future<void> updateMonthly(MonthlyGift m) =>
    _db.from('monthly_gifts').update({'amount': m.amount, 'day': m.day, 'paused': m.paused}).eq('id', m.id);

Future<void> deleteMonthly(String id) => _db.from('monthly_gifts').delete().eq('id', id);

// ── Escrita: instituição (fase 5) ────────────────────────────

Future<void> confirmDonation(String id) => _db.rpc('confirm_donation', params: {'donation': id});

Future<void> markNotFound(String id) => _db.rpc('mark_not_found', params: {'donation': id});

Future<void> markAbsent(String id) => _db.rpc('mark_absent', params: {'donation': id});

Future<void> cancelAction(String goalId) => _db.rpc('cancel_action', params: {'goal': goalId});

Future<void> closeGoal(String goalId) => _db.rpc('close_goal', params: {'goal': goalId});

Future<void> extendGoal(String goalId, DateTime deadline) =>
    _db.rpc('extend_goal', params: {'goal': goalId, 'new_deadline': _day(deadline)});

Future<void> markGoalSeen(String goalId) => _db.from('goals').update({'seen_done': true}).eq('id', goalId);

Future<void> insertGoal(String placeId, Goal g) => _db.from('goals').insert({
  'id': g.id,
  'place_id': placeId,
  'type': g.type.name,
  'target': g.target,
  'item': g.item,
  'unit': g.unit,
  'cause': g.cause,
  'deadline': _day(g.deadline),
  'reason': g.reason,
  'published': g.published,
  if (g.action case final a?) ...{
    'action_name': a.name,
    'action_task': a.task,
    'action_day': _day(a.day),
    'action_start': a.start,
    'action_end': a.end,
  },
});

/// Cadastro do ponto: grava (ou corrige) a linha em places e manda para a fila.
/// [isNew]: primeira vez (INSERT como rascunho); senão, corrige a linha que
/// voltou com ajuste (o RLS deixa o dono editar em draft e adjust).
Future<void> savePlace(Place p, {required bool isNew, String? indicatedById, bool cnpjUnchecked = false}) async {
  var photo = p.photo;
  if (photo != null && !photo.startsWith('http') && !photo.startsWith('assets/')) {
    photo = await uploadPublicPhoto('places', photo);
  }
  final row = {
    'name': p.name,
    'type_label': p.typeLabel,
    'kind': p.kind.name,
    'responsible': p.responsible,
    'phone': p.phone,
    'cnpj': p.cnpj,
    'legal_name': p.legalName,
    'cnpj_status': p.cnpjStatus,
    'cnpj_unchecked': cnpjUnchecked,
    'indicated_by': indicatedById,
    'about': p.about,
    'causes': p.causes.toList(),
    'accepts': [for (final t in p.accepts) t.name],
    'cep': p.cep,
    'street': p.street,
    'number': p.number,
    'complement': p.complement,
    'neighborhood': p.neighborhood,
    'city': p.city,
    'location': 'POINT(${p.point.longitude} ${p.point.latitude})',
    'hours': p.hours,
    'receive_days': p.receiveDays.toList()..sort(),
    'photo_path': photo,
    'pix_key_type': p.pixKeyType,
    'pix_key': p.pixKey,
    'payee': p.payee,
    'draft_step': 5,
  };
  if (isNew) {
    await _db.from('places').insert({...row, 'id': p.id, 'owner_id': _uid, 'status': 'draft'});
  } else {
    await _db.from('places').update(row).eq('id', p.id);
  }
  await _db.rpc('submit_place', params: {'place': p.id});
}

/// Textos que não passam pela equipe (nome, sobre, o que distribui, horários).
Future<void> editPlace(Place p) => _db.rpc(
  'edit_place',
  params: {
    'place': p.id,
    'patch': {
      'name': p.name,
      'about': p.about,
      'distributes': p.distributes,
      'hours': p.hours,
      'receive_days': p.receiveDays.toList()..sort(),
    },
  },
);

Future<void> renewReview(String placeId) => _db.rpc('renew_review', params: {'place': placeId});

/// Mudança de dados sensíveis. [changes] é o que a equipe lê; daqui sai o
/// "patch" com as colunas de places que mudam se a equipe aprovar.
Future<void> requestChange(Place p, Map<String, String> changes) async {
  final shown = {...changes};
  final patch = <String, String>{};
  if (changes['Foto'] case final local?) {
    final url = local.startsWith('http') ? local : await uploadPublicPhoto('places', local);
    shown['Foto'] = url;
    patch['photo_path'] = url;
  }
  if (changes['Responsável'] case final v?) patch['responsible'] = v;
  if (changes['Endereço'] case final v?) {
    // "Rua Bahia, 512 · Vila Nova"
    final parts = v.split(' · ');
    final street = parts.first.split(', ');
    patch['street'] = street.first.trim();
    if (street.length > 1) patch['number'] = street.skip(1).join(', ').trim();
    if (parts.length > 1) patch['neighborhood'] = parts[1].trim();
  }
  await _db.rpc('request_change', params: {'place': p.id, 'changes': shown, 'patch': patch});
}

Future<void> changePixKey(String placeId, String type, String key, String payee) => _db.rpc(
  'change_pix_key',
  params: {'place': placeId, 'key_type': type, 'key': key, 'new_payee': payee},
);

// ── Escrita: equipe (fase 6) ─────────────────────────────────

Future<void> approve(String submissionId) => _db.rpc('approve_submission', params: {'sub': submissionId});

Future<void> askAdjust(String submissionId, String reasons, String message) =>
    _db.rpc('ask_adjust', params: {'sub': submissionId, 'reasons': reasons, 'message': message});

Future<void> refuse(String submissionId, String reason) =>
    _db.rpc('refuse_submission', params: {'sub': submissionId, 'reason': reason});

Future<void> keepOnMap(String placeId) => _db.rpc('keep_on_map', params: {'place': placeId});

Future<void> pausePlace(String placeId, String reason) =>
    _db.rpc('pause_place', params: {'place': placeId, 'reason': reason});

Future<void> removePlace(String placeId, String reason) =>
    _db.rpc('remove_place', params: {'place': placeId, 'reason': reason});

Future<void> reactivatePlace(String placeId) => _db.rpc('reactivate_place', params: {'place': placeId});

// ── Conta (fase 8) ───────────────────────────────────────────

/// Apaga as fotos e os comprovantes que a pessoa enviou (a pasta com o id
/// dela em cada balde). O Supabase não deixa apagar arquivos por SQL.
Future<void> deleteMyFiles() async {
  for (final bucket in ['avatars', 'places', 'receipts']) {
    final files = await _db.storage.from(bucket).list(path: _uid);
    if (files.isEmpty) continue;
    await _db.storage.from(bucket).remove([for (final f in files) '$_uid/${f.name}']);
  }
}

Future<void> deleteAccount() => _db.rpc('delete_account');

/// "awaitingIndication" → "awaiting_indication" (para quem precisar do nome no banco).
String dbName(Enum e) => _snake(e.name);
