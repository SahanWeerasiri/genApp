import 'package:flutter/material.dart';

class StyleSelector extends StatelessWidget {
  final String selectedStyle;
  final Function(String) onStyleChanged;
  final bool enabled;

  const StyleSelector({
    super.key,
    required this.selectedStyle,
    required this.onStyleChanged,
    this.enabled = true,
  });

  static const List<String> styles = [
    'Realistic',
    'Anime',
    'Digital Art',
    'Oil Painting',
    'Watercolor',
    'Sketch',
    '3D Render',
    'Pixel Art',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Style',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedStyle,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: styles.map((style) {
              return DropdownMenuItem(
                value: style,
                child: Text(style),
              );
            }).toList(),
            onChanged: enabled
                ? (value) {
                    if (value != null) {
                      onStyleChanged(value);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
