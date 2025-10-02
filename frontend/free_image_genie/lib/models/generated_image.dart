import 'dart:typed_data';
import 'dart:convert';

class GeneratedImage {
  final String id;
  final String imageUrl;
  final String prompt;
  final String style;
  final DateTime timestamp;
  final Uint8List? imageBytes; // Add support for image bytes

  GeneratedImage({
    required this.id,
    required this.imageUrl,
    required this.prompt,
    required this.style,
    required this.timestamp,
    this.imageBytes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'prompt': prompt,
      'style': style,
      'timestamp': timestamp.toIso8601String(),
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
    };
  }

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      id: json['id'],
      imageUrl: json['imageUrl'],
      prompt: json['prompt'],
      style: json['style'],
      timestamp: DateTime.parse(json['timestamp']),
      imageBytes: json['imageBytes'] != null
          ? base64Decode(json['imageBytes'])
          : null,
    );
  }
}
