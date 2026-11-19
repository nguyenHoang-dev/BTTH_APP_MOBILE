# [02] Thiết kế dữ liệu Offline: Ngân hàng câu hỏi JSON & Lưu trữ SQLite

- **Ngày:** 2026-11-17
- **Công cụ AI:** Antigravity / Gemini
- **Mục đích:** Chuẩn hóa cấu trúc dữ liệu câu hỏi song ngữ (`LocalizedText`, `Question`) và thiết kế bảng SQLite (`quiz_results`, `wrong_answers`) cho ứng dụng ôn tập trắc nghiệm.

## Prompt

```text
Thiết kế tầng dữ liệu offline cho ứng dụng Flutter Ôn tập trắc nghiệm song ngữ (Việt - Anh):
1. Model `Question` và `LocalizedText` đọc từ `assets/data/questions.json`. Hỗ trợ 3 chế độ hiển thị: Tiếng Việt (vi), Tiếng Anh (en) và Song ngữ (both). Nếu `correctIndex` nằm ngoài phạm vi mảng `options` thì phải ném `FormatException` để Repository bắt lỗi định dạng.
2. Dịch vụ SQLite (`LocalDatabase` và `SqliteHistoryRepository`):
   - Bảng `quiz_results`: lưu số câu đúng, tổng số câu, thời gian làm bài, thời điểm nộp bài.
   - Bảng `wrong_answers`: lưu `question_id` các câu làm sai để phục vụ tính năng "Ôn lại câu sai".
   - Dùng `db.transaction` khi lưu kết quả để đảm bảo toàn vẹn dữ liệu.
```

## Kết quả AI trả về (tóm tắt)

- Sinh model `LocalizedText` với hàm `resolve(AppLanguage)` tự động fallback nếu thiếu 1 ngôn ngữ.
- Sinh `Question.fromJson` kiểm tra chặt `correctIndex >= 0 && correctIndex < options.length`.
- Sinh `AssetQuizRepository` bọc lỗi `FormatException` thành `AppException('Ngân hàng câu hỏi bị lỗi định dạng.')`.
- Sinh `LocalDatabase` và `SqliteHistoryRepository` dùng `ConflictAlgorithm.replace` cho bảng `wrong_answers`.

## Sinh viên đã chỉnh sửa / kiểm chứng

- [x] Đã đọc hiểu code sinh ra
- [x] Đã chạy `flutter analyze` / `flutter test`
- Thay đổi thủ công:
  - Bổ sung `FakeQuizRepository` và `FakeHistoryRepository` trong `test/helpers/fakes.dart` để chạy unit test trên RAM không phụ thuộc SQLite thật.
  - Bổ sung cơ chế `saveWarning` trong `QuizProvider.submit()` để nếu SQLite lỗi thì người dùng vẫn xem được màn hình kết quả bài thi.

## Bài học rút ra

- Luôn tách `QuizRepository` và `HistoryRepository` thành `abstract interface class` để có thể mock/fake 100% khi viết Unit Test và Widget Test.
