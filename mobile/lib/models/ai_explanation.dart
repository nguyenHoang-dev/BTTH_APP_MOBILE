/// Nguồn sinh ra lời giải thích.
enum AISource {
  /// Gemini thật (qua server Node.js).
  gemini,

  /// Dữ liệu giả lập (Demo Mode ở app, hoặc server chưa có API key, hoặc mất mạng).
  demo,
}

/// Kết quả AI giải thích câu trả lời sai.
class AIExplanation {
  const AIExplanation({
    required this.whyWrong,
    required this.correctExplanation,
    required this.example,
    required this.tip,
    required this.source,
    this.notice,
  });

  final String whyWrong;
  final String correctExplanation;
  final String example;
  final String tip;
  final AISource source;

  /// Ghi chú hiển thị cho người dùng (vd. "Mất mạng – đang dùng dữ liệu Demo").
  final String? notice;

  bool get isDemo => source == AISource.demo;

  factory AIExplanation.fromJson(Map<String, dynamic> json) => AIExplanation(
        whyWrong: (json['whyWrong'] ?? '') as String,
        correctExplanation: (json['correctExplanation'] ?? '') as String,
        example: (json['example'] ?? '') as String,
        tip: (json['tip'] ?? '') as String,
        source: json['source'] == 'gemini' ? AISource.gemini : AISource.demo,
      );

  AIExplanation copyWith({String? notice}) => AIExplanation(
        whyWrong: whyWrong,
        correctExplanation: correctExplanation,
        example: example,
        tip: tip,
        source: source,
        notice: notice ?? this.notice,
      );
}

