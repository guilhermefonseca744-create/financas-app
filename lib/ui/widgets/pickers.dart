import 'package:flutter/material.dart';

/// Paleta de cores reutilizável para categorias, metas e contas.
const List<int> kColorPalette = [
  0xFFEF5350, 0xFF42A5F5, 0xFF7E57C2, 0xFFFFA726,
  0xFFEC407A, 0xFF26A69A, 0xFF8D6E63, 0xFF66BB6A,
  0xFF26C6DA, 0xFF9CCC65, 0xFF5C6BC0, 0xFF78909C,
];

/// Ícones disponíveis para categorias e metas.
const List<IconData> kIconChoices = [
  Icons.restaurant,
  Icons.directions_bus,
  Icons.home,
  Icons.movie,
  Icons.favorite,
  Icons.shopping_cart,
  Icons.receipt_long,
  Icons.work,
  Icons.laptop,
  Icons.trending_up,
  Icons.attach_money,
  Icons.flight,
  Icons.school,
  Icons.pets,
  Icons.fitness_center,
  Icons.local_gas_station,
  Icons.phone_android,
  Icons.card_giftcard,
  Icons.savings,
  Icons.beach_access,
  Icons.directions_car,
  Icons.sports_esports,
  Icons.medical_services,
  Icons.category,
];

class ColorPickerWrap extends StatelessWidget {
  const ColorPickerWrap({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kColorPalette)
          Semantics(
            button: true,
            selected: selected == c,
            label: 'Cor',
            child: InkWell(
              onTap: () => onSelect(c),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == c
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: selected == c
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class IconPickerWrap extends StatelessWidget {
  const IconPickerWrap({
    super.key,
    required this.selectedCode,
    required this.color,
    required this.onSelect,
  });
  final int selectedCode;
  final Color color;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final ic in kIconChoices)
          Semantics(
            button: true,
            selected: selectedCode == ic.codePoint,
            child: InkWell(
              onTap: () => onSelect(ic.codePoint),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selectedCode == ic.codePoint
                      ? color.withValues(alpha: 0.2)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedCode == ic.codePoint
                        ? color
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(ic,
                    color: selectedCode == ic.codePoint
                        ? color
                        : scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }
}
