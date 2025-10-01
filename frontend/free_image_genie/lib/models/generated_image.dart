class GeneratedImage {
  final String id;
  final String imageUrl;
  final String prompt;
  final String style;
  final DateTime timestamp;

  GeneratedImage({
    required this.id,
    required this.imageUrl,
    required this.prompt,
    required this.style,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'prompt': prompt,
      'style': style,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      id: json['id'],
      imageUrl: json['imageUrl'],
      prompt: json['prompt'],
      style: json['style'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
