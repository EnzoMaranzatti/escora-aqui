import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../institution/institution_shell.dart';
import '../institution/register/register_flow.dart';
import '../map/pins.dart';
import '../place/place_screen.dart';
import 'edit_profile_screen.dart';
import '../shared/help_ui.dart';
import '../signup/city_sheet.dart';
import '../signup/places_service.dart';
import '../splash/splash_screen.dart';
import '../team/team_shell.dart';

/// Tab "Perfil": city, preferences, notices and account. Also the door to
/// the institution mode and, for team accounts, the team panel.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _changeCity(BuildContext context) async {
    final r = await showCitySheet(context);
    if (r is PickedCity) {
      onboarding.setPlace(city: r.city, uf: r.uf, position: r.point, fromGps: false);
      store.mapCenter = r.point;
      store.touch();
    } else if (r is UseMyLocation) {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
          return;
        }
        if (perm == LocationPermission.denied) return;
        final pos = await Geolocator.getCurrentPosition();
        final p = LatLng(pos.latitude, pos.longitude);
        final (city, uf) = await PlacesService.describe(p);
        onboarding.setPlace(city: city, uf: uf, position: p, fromGps: true);
        store.mapCenter = p;
        store.touch();
      } catch (_) {}
    }
  }

  void _soon(BuildContext context) =>
      Toast.show(context, 'Essa página chega na próxima versão.', icon: PhosphorIconsFill.info);

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: 'Sair da sua conta?',
      text: 'Suas preferências e seu histórico ficam salvos para quando você voltar.',
      confirm: 'Sair',
      cancel: 'Continuar no app',
    );
    if (ok == null || !context.mounted) return;
    store.setMode(AppMode.donor);
    context.replaceAll(const SplashScreen(startAtEnd: true));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, onboarding]),
      builder: (context, _) {
        final types = onboarding.helpTypes;
        final myCauses = onboarding.selectedCauses;
        final point = store.myPoint;
        final fullName = store.fullName.isEmpty ? store.name : store.fullName;
        return TabPage(
          title: 'Perfil',
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  AppCard(
                    onTap: () => context.push(const EditProfileScreen()),
                    child: Row(
                      children: [
                        ProfileAvatar(photo: store.avatar, name: fullName),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName == 'você' ? 'Sua conta' : fullName,
                                style: AppType.cardTitle(size: 18, color: AppColors.cinza900),
                              ),
                              if (store.email.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(store.email, style: AppType.body(size: 14)),
                              ],
                              const SizedBox(height: 6),
                              Text('Editar meus dados', style: AppType.label(size: 13.5, color: AppColors.petroleo700)),
                            ],
                          ),
                        ),
                        const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza400),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionTitle('Minhas preferências'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        InfoRow(
                          icon: PhosphorIconsRegular.mapPin,
                          title: 'Cidade',
                          value: onboarding.city ?? 'São José do Rio Preto',
                          action: 'Trocar',
                          onTap: () => _changeCity(context),
                        ),
                        const Hairline(indent: 48),
                        InfoRow(
                          icon: PhosphorIconsRegular.coins,
                          title: 'Formas de ajuda',
                          value: types.isEmpty
                              ? 'Todas'
                              : [for (final t in HelpType.values.where(types.contains)) t.label].join(', '),
                          action: 'Editar',
                          onTap: () => showAppSheet<void>(context, builder: (_) => const _HelpTypesSheet()),
                        ),
                        const Hairline(indent: 48),
                        InfoRow(
                          icon: PhosphorIconsRegular.tag,
                          title: 'Causas que acompanho',
                          value: myCauses.isEmpty ? 'Nenhuma' : myCauses.join(', '),
                          action: 'Editar',
                          onTap: () => showAppSheet<void>(context, builder: (_) => const _CausesSheet()),
                        ),
                        const Hairline(indent: 48),
                        InfoRow(
                          icon: PhosphorIconsRegular.bookmarkSimple,
                          title: 'Pontos que acompanho',
                          value: '${store.followed.length}',
                          action: 'Ver',
                          onTap: () => context.push(const FollowedScreen()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionTitle('Avisos'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        InfoRow(
                          title: 'Novas metas nas minhas causas',
                          trailing: AppSwitch(
                            value: store.notifyGoals,
                            onChanged: (v) => store
                              ..notifyGoals = v
                              ..touch(),
                          ),
                        ),
                        const Hairline(),
                        InfoRow(
                          title: 'Confirmação das minhas doações',
                          trailing: AppSwitch(
                            value: store.notifyConfirm,
                            onChanged: (v) => store
                              ..notifyConfirm = v
                              ..touch(),
                          ),
                        ),
                        const Hairline(),
                        InfoRow(
                          title: 'Lembretes de voluntariado',
                          trailing: AppSwitch(
                            value: store.notifyVolunteer,
                            onChanged: (v) => store
                              ..notifyVolunteer = v
                              ..touch(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const SectionTitle('Para instituições'),
                  if (point == null)
                    AppCard(
                      color: AppColors.petroleo50,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(PhosphorIconsFill.storefront, size: 28, color: AppColors.petroleo600),
                          const SizedBox(height: 10),
                          Text(
                            'Representa uma instituição?',
                            style: AppType.cardTitle(size: 18, color: AppColors.petroleo900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cadastre seu ponto de apoio para mostrar o que vocês precisam a quem está perto.',
                            style: AppType.body(size: 15, color: AppColors.petroleo800),
                          ),
                          const SizedBox(height: 14),
                          PrimaryButton(
                            label: 'Cadastrar meu ponto de apoio',
                            icon: null,
                            onPressed: () => openRegister(context),
                          ),
                        ],
                      ),
                    )
                  else
                    AppCard(
                      onTap: () {
                        store.setMode(AppMode.institution);
                        context.replaceAll(const InstitutionShell());
                      },
                      child: Row(
                        children: [
                          IconTile(icon: PhosphorIconsFill.storefront, color: AppColors.petroleo600, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ir para o modo instituição',
                                  style: AppType.label(
                                    color: AppColors.cinza900,
                                    size: 15.5,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text('${point.name} · ${statusLabel(point.status)}', style: AppType.body(size: 14)),
                              ],
                            ),
                          ),
                          const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza500),
                        ],
                      ),
                    ),
                  if (store.isTeam) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      onTap: () {
                        store.setMode(AppMode.team);
                        context.replaceAll(const TeamShell());
                      },
                      child: Row(
                        children: [
                          IconTile(icon: PhosphorIconsFill.shieldCheck, color: AppColors.cinza800, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Abrir painel da equipe',
                              style: AppType.label(
                                color: AppColors.cinza900,
                                size: 15.5,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza500),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  const SectionTitle('Conta'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        InfoRow(
                          icon: PhosphorIconsRegular.question,
                          title: 'Ajuda',
                          chevron: true,
                          onTap: () => _soon(context),
                        ),
                        const Hairline(indent: 48),
                        InfoRow(
                          icon: PhosphorIconsRegular.fileText,
                          title: 'Termos de uso e privacidade',
                          chevron: true,
                          onTap: () => _soon(context),
                        ),
                        const Hairline(indent: 48),
                        InfoRow(
                          icon: PhosphorIconsRegular.signOut,
                          title: 'Sair da conta',
                          titleColor: AppColors.erroTexto,
                          onTap: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String statusLabel(PlaceStatus s) => switch (s) {
  PlaceStatus.draft => 'Cadastro em andamento',
  PlaceStatus.review => 'Em análise',
  PlaceStatus.awaitingIndication => 'Aguardando indicação',
  PlaceStatus.adjust => 'Ajuste pedido',
  PlaceStatus.refused => 'Recusado',
  PlaceStatus.active => 'Verificado',
  PlaceStatus.paused => 'Pausado',
  PlaceStatus.removed => 'Removido',
};

class _HelpTypesSheet extends StatefulWidget {
  const _HelpTypesSheet();

  @override
  State<_HelpTypesSheet> createState() => _HelpTypesSheetState();
}

class _HelpTypesSheetState extends State<_HelpTypesSheet> {
  late final _picked = {...onboarding.helpTypes};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Formas de ajuda', style: AppType.title().copyWith(fontSize: 22)),
        const SizedBox(height: 16),
        for (final t in HelpType.values) ...[
          OptionTile(
            title: t.label,
            subtitle: t.description,
            icon: t.icon,
            iconColor: t.color,
            multi: true,
            selected: _picked.contains(t),
            onTap: () => setState(() => _picked.contains(t) ? _picked.remove(t) : _picked.add(t)),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Salvar',
          icon: null,
          onPressed: () {
            for (final t in HelpType.values) {
              if (_picked.contains(t) != onboarding.helpTypes.contains(t)) onboarding.toggleHelp(t);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _CausesSheet extends StatefulWidget {
  const _CausesSheet();

  @override
  State<_CausesSheet> createState() => _CausesSheetState();
}

class _CausesSheetState extends State<_CausesSheet> {
  late final _picked = {...onboarding.selectedCauses};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Causas que acompanho', style: AppType.title().copyWith(fontSize: 22)),
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
          label: 'Salvar',
          icon: null,
          onPressed: () {
            for (final c in causes) {
              if (_picked.contains(c) != onboarding.selectedCauses.contains(c)) onboarding.toggleCause(c);
            }
            store.filterCauses
              ..clear()
              ..addAll(_picked);
            store.touch();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

/// "Pontos que acompanho".
class FollowedScreen extends StatelessWidget {
  const FollowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = [for (final id in store.followed) ?store.placeOrNull(id)];
        return FlowScaffold(
          title: 'Pontos que acompanho',
          background: AppColors.cinza50,
          children: [
            if (list.isEmpty)
              const EmptyState(
                icon: PhosphorIconsRegular.bookmarkSimple,
                title: 'Nenhum ponto por enquanto.',
                text:
                    'Toque em "Acompanhar este ponto" no perfil de um ponto para receber um aviso quando ele abrir uma meta.',
              ),
            for (final p in list) ...[
              AppCard(
                onTap: () => context.push(PlaceScreen(placeId: p.id)),
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
                          const SizedBox(height: 2),
                          Text(
                            p.nextGoal?.headline ?? '${p.typeLabel} · ${p.neighborhood}',
                            style: AppType.body(size: 14),
                          ),
                        ],
                      ),
                    ),
                    LinkText(
                      'Deixar de acompanhar',
                      color: AppColors.cinza600,
                      size: 13,
                      onTap: () => store.unfollow(p.id),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
