import 'package:flutter/material.dart';

import '../../data/store.dart';

/// A medalha do nível, gerada no Magnific (`assets/images/levels/`). As
/// quatro saíram com o mesmo enquadramento, então o mesmo [size] dá o mesmo
/// tamanho óptico em qualquer nível.
///
/// O material sobe junto com o nível — argila fosca no Bronze e no Prata,
/// metal polido no Ouro, cristal com aro dourado no Black.
class LevelMedal extends StatelessWidget {
  const LevelMedal({super.key, required this.level, this.size = 48});

  final PointsLevel level;
  final double size;

  static String assetFor(PointsLevel level) => switch (level) {
    PointsLevel.bronze => 'assets/images/levels/bronze.png',
    PointsLevel.prata => 'assets/images/levels/prata.png',
    PointsLevel.ouro => 'assets/images/levels/ouro.png',
    PointsLevel.black => 'assets/images/levels/black.png',
  };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetFor(level),
      height: size,
      width: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Medalha do nível ${level.label}',
    );
  }
}
