/// Ngôn ngữ hiển thị của app song ngữ.
enum AppLanguage {
  vi('vi', 'Tiếng Việt'),
  en('en', 'English'),
  both('both', 'Song ngữ');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;
}

/// Một chuỗi có 2 phiên bản Việt – Anh.
class LocalizedText {
  const LocalizedText({required this.vi, required this.en});

  final String vi;
  final String en;

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
        vi: (json['vi'] ?? '') as String,
        en: (json['en'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'vi': vi, 'en': en};

  /// Lấy văn bản theo ngôn ngữ; `both` => "VI\nEN". Thiếu bản dịch -> dùng bản còn lại.
  String resolve(AppLanguage lang) {
    final safeVi = vi.isNotEmpty ? vi : en;
    final safeEn = en.isNotEmpty ? en : vi;
    return switch (lang) {
      AppLanguage.vi => safeVi,
      AppLanguage.en => safeEn,
      AppLanguage.both => safeVi == safeEn ? safeVi : '$safeVi\n$safeEn',
    };
  }
}

