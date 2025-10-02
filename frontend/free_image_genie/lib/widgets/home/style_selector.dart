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
    "Painted Anime",
    "Casual Photo",
    "Cinematic",
    "Digital Painting",
    "Concept Art",
    "𝗡𝗼 𝘀𝘁𝘆𝗹𝗲",
    "3D Disney Character",
    "2D Disney Character",
    "Disney Sketch",
    "Concept Sketch",
    "Painterly",
    "Oil Painting",
    "Oil Painting - Realism",
    "Oil Painting - Old",
    "Oil Painting - 70s Pulp",
    "Professional Photo",
    "Anime",
    "Drawn Anime",
    "Anime Screencap",
    "Cute Anime",
    "Soft Anime",
    "Fantasy Painting",
    "Fantasy Landscape",
    "Fantasy Portrait",
    "Studio Ghibli",
    "50s Enamel Sign",
    "Vintage Comic",
    "Franco-Belgian Comic",
    "Tintin Comic",
    "Medieval",
    "Pixel Art",
    "Furry - Oil",
    "Furry - Cinematic",
    "Furry - Painted",
    "Furry - Drawn",
    "Cute Figurine",
    "3D Emoji",
    "Illustration",
    "Cute Illustration",
    "Flat Illustration",
    "Watercolor",
    "1990s Photo",
    "1980s Photo",
    "1970s Photo",
    "1960s Photo",
    "1950s Photo",
    "1940s Photo",
    "1930s Photo",
    "1920s Photo",
    "Vintage Pulp Art",
    "50s Infomercial Anime",
    "3D Pokemon",
    "Painted Pokemon",
    "2D Pokemon",
    "Vintage Anime",
    "Neon Vintage Anime",
    "Manga",
    "Fantasy World Map",
    "Fantasy City Map",
    "Old World Map",
    "3D Isometric Icon",
    "Flat Style Icon",
    "Flat Style Logo",
    "Game Art Icon",
    "Digital Painting Icon",
    "Concept Art Icon",
    "Cute 3D Icon",
    "Cute 3D Icon 𝗦𝗲𝘁",
    "Crayon Drawing",
    "Pencil",
    "Tattoo Design",
    "Waifu",
    "YuGiOh Art",
    "Traditional Japanese",
    "Nihonga Painting",
    "Claymation",
    "Cartoon",
    "Cursed Photo",
    "MTG Card",
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
              return DropdownMenuItem(value: style, child: Text(style));
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
