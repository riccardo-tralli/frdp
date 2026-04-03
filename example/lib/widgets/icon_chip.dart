import 'package:flutter/material.dart';
import 'package:frdp_example/const/rradius.dart';
import 'package:frdp_example/const/spaces.dart';
import 'package:hugeicons/hugeicons.dart';

class IconChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final IconChipType type;

  const IconChip({
    super.key,
    required this.icon,
    required this.label,
    this.type = IconChipType.info,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Spaces.small,
      vertical: Spaces.extraSmall,
    ),
    decoration: BoxDecoration(
      color: type.color.withAlpha(50),
      borderRadius: BorderRadius.circular(RRadius.large),
    ),
    child: Row(
      spacing: Spaces.extraSmall,
      children: [
        HugeIcon(icon: icon, color: type.color, size: 26),
        Text(label, style: TextStyle(color: type.color)),
      ],
    ),
  );
}

enum IconChipType {
  info(Colors.blue),
  success(Colors.green),
  warning(Colors.amber),
  error(Colors.red);

  final Color color;
  const IconChipType(this.color);
}
