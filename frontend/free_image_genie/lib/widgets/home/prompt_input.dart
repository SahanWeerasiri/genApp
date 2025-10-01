import 'package:flutter/material.dart';

class PromptInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const PromptInput({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Describe the image you want to generate...\n\nExample: A serene mountain landscape at sunset with a lake',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              Icons.edit_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
