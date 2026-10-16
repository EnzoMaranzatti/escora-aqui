import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets/kit.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../data/store.dart';
import '../shared/done_view.dart';
import '../shell/donor_shell.dart';
import 'monthly_screen.dart';

/// "Doação registrada": closes the three flows and separates what the
/// person did from what still depends on the institution.
class RegisteredScreen extends StatelessWidget {
  const RegisteredScreen._({required this.title, required this.text, this.place, this.amount});

  factory RegisteredScreen.pix({required Place place, required double amount}) => RegisteredScreen._(
    title: 'Doação de ${Fmt.money(amount)} registrada.',
    text: 'Agora é com a ${place.name}. Quando ela confirmar o recebimento, a meta avança e você recebe um aviso.',
    place: place,
    amount: amount,
  );

  factory RegisteredScreen.items({required Place place, required String quantity, required DateTime date}) =>
      RegisteredScreen._(
        title: 'Combinado: $quantity até ${Fmt.day(date)}.',
        text: 'Leve os itens em ${place.address}, ${place.hours}. A ${place.name} confirma quando receber.',
      );

  factory RegisteredScreen.volunteer({required Place place, required String when}) => RegisteredScreen._(
    title: 'Inscrição feita para $when.',
    text: 'Vamos te lembrar na véspera. Se não puder ir, cancele em Minhas doações para liberar a vaga.',
  );

  final String title;
  final String text;

  /// Set for Pix: offers to repeat the same amount every month.
  final Place? place;
  final double? amount;

  @override
  Widget build(BuildContext context) {
    return DoneView(
      title: title,
      text: text,
      primary: 'Voltar ao mapa',
      onPrimary: () => goToTab(context, 0),
      secondary: 'Ver minhas doações',
      onSecondary: () => goToTab(context, 1),
      extra: place == null
          ? null
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) => store.monthlyFor(place!.id) != null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SoftButton(
                        label: 'Doar esse valor todo mês',
                        icon: PhosphorIconsRegular.arrowsClockwise,
                        onTap: () => context.push(MonthlySetupScreen(placeId: place!.id, suggested: amount)),
                      ),
                    ),
            ),
    );
  }
}
