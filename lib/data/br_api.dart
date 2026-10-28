import 'dart:convert';

import 'package:http/http.dart' as http;

sealed class CnpjResult {
  const CnpjResult();
}

class CnpjFound extends CnpjResult {
  const CnpjFound(this.legalName, this.status);

  final String legalName;

  /// "ativa", "baixada", "suspensa"…
  final String status;

  bool get active => status == 'ativa';
}

class CnpjNotFound extends CnpjResult {
  const CnpjNotFound();
}

class CnpjOffline extends CnpjResult {
  const CnpjOffline();
}

class CepAddress {
  const CepAddress({required this.street, required this.neighborhood, required this.city, required this.uf});

  final String street;
  final String neighborhood;
  final String city;
  final String uf;
}

/// Free public Brazilian data, no key: BrasilAPI for CNPJ (Receita
/// Federal) and ViaCEP for addresses.
abstract final class BrApi {
  /// CNPJs used by the demo data answer locally, so the demo works offline.
  static const _demo = {
    '22333444000181': CnpjFound('Associação Cozinha Comunitária Vila Nova', 'ativa'),
    '11111111000191': CnpjFound('Associação Exemplo Inativa', 'baixada'),
  };

  static Future<CnpjResult> cnpj(String digits) async {
    if (_demo[digits] != null) return _demo[digits]!;
    try {
      final res = await http
          .get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$digits'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404 || res.statusCode == 400) return const CnpjNotFound();
      if (res.statusCode != 200) return const CnpjOffline();
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final name = (j['razao_social'] as String?)?.trim() ?? '';
      final status = ((j['descricao_situacao_cadastral'] as String?) ?? 'ATIVA').toLowerCase();
      return CnpjFound(_title(name), status);
    } catch (_) {
      return const CnpjOffline();
    }
  }

  static Future<CepAddress?> cep(String digits) async {
    try {
      final res = await http
          .get(Uri.parse('https://viacep.com.br/ws/$digits/json/'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (j['erro'] != null) return null;
      return CepAddress(
        street: j['logradouro'] as String? ?? '',
        neighborhood: j['bairro'] as String? ?? '',
        city: j['localidade'] as String? ?? '',
        uf: j['uf'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// "ASSOCIACAO DE MORADORES" → "Associacao De Moradores", keeping short
  /// connectors lowercase.
  static String _title(String s) {
    const lower = {'de', 'da', 'do', 'das', 'dos', 'e'};
    return s
        .toLowerCase()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => lower.contains(w) ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
