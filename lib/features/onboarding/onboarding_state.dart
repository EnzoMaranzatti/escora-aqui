import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

enum HelpType {
  pix('Pix', 'Doe qualquer valor direto para a instituição, sem taxa.'),
  itens('Itens', 'Leve alimentos, roupas ou outros itens até o ponto.'),
  voluntariado('Voluntariado', 'Doe seu tempo em ações com dia e hora marcados.');

  const HelpType(this.label, this.description);

  final String label;
  final String description;
}

const causes = [
  'Alimentos',
  'Roupas e agasalhos',
  'Material escolar',
  'Higiene e limpeza',
  'Crianças',
  'Idosos',
  'Pessoas em situação de rua',
  'Animais',
  'Saúde',
  'Educação',
];

/// Choices made during onboarding, kept until the account is created
/// (copy: "Escolhas antes da conta ficam guardadas no aparelho").
class OnboardingState extends ChangeNotifier {
  String? city;
  String? uf;
  LatLng? position;
  bool fromGps = false;
  final helpTypes = <HelpType>{};
  final selectedCauses = <String>{};
  bool notifications = false;
  String? name;

  void setPlace({required String city, String? uf, required LatLng position, required bool fromGps}) {
    this.city = city;
    this.uf = uf;
    this.position = position;
    this.fromGps = fromGps;
    notifyListeners();
  }

  void toggleHelp(HelpType t) {
    helpTypes.contains(t) ? helpTypes.remove(t) : helpTypes.add(t);
    notifyListeners();
  }

  void toggleCause(String c) {
    selectedCauses.contains(c) ? selectedCauses.remove(c) : selectedCauses.add(c);
    notifyListeners();
  }
}

/// Single app-wide instance. Fine for the prototype; swap for a provider
/// (Riverpod/Provider) once there is a backend.
final onboarding = OnboardingState();
