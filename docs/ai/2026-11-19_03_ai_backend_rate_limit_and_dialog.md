# [03] Bảo mật Backend Node.js (Rate Limiting) & Nâng cấp AI Explanation Dialog

- **Ngày:** 2026-11-19
- **Công cụ AI:** Antigravity (Gemini)
- **Mục đích:** Hoàn thiện nhiệm vụ Thành viên 5: thêm Rate Limiting theo IP trên máy chủ Node.js để bảo vệ khóa Gemini, nâng cấp giao diện `AIExplanationDialog`, và viết bộ Unit/Widget Test cho luồng AI.

## Prompt

```text
Đóng vai lập trình viên Backend Node.js & Flutter 10 năm kinh nghiệm, thực hiện nhiệm vụ của Thành viên 5:
1. Trên `server/src/middlewares/rate_limit.middleware.js`: Viết middleware giới hạn số request theo IP (tối đa 15 lần gọi AI / phút) cho route `POST /api/explain`, trả về mã HTTP 429 kèm header `X-RateLimit-*` và `Retry-After` chuẩn RFC khi vượt ngưỡng, đồng thời tự dọn bộ nhớ định kỳ để không bị memory leak.
2. Trên `mobile/lib/screens/ai_explanation_dialog.dart`:
   - Hiển thị rõ câu hỏi, đáp án người dùng đã chọn và đáp án đúng ngay trên đầu Dialog.
   - Thêm nút "Sao chép lời giải thích" (`Clipboard.setData`) kèm thông báo `SnackBar`.
   - Thêm nút chuyển nhanh sang Chế độ Demo khi mất mạng.
3. Viết đầy đủ unit test & widget test trong `mobile/test/ai_feature_test.dart` kiểm tra:
   - `ApiClient` xử lý timeout 15s -> ném `AppException(type: AppErrorType.timeout)`.
   - `AIRepositoryImpl` ở chế độ Demo không gọi mạng, và tự động fallback sang Demo khi mất mạng.
   - `AIProvider` chống race-condition khi người dùng mở/đóng hoặc gọi liên tiếp nhiều câu hỏi.
```

## Kết quả AI trả về (tóm tắt)

- Tạo `server/src/middlewares/rate_limit.middleware.js` cài đặt Sliding/Fixed Window theo IP (15 requests / 60s), gắn vào `POST /api/explain`.
- Cập nhật `AIExplanationDialog` thêm `_QuestionSummaryHeader`, nút `Sao chép lời giải thích` (`Clipboard.setData`) và nút chuyển nhanh sang Chế độ Demo.
- Tạo file test `mobile/test/ai_feature_test.dart` kiểm thử toàn diện `ApiClient`, `AIRepositoryImpl`, `AIProvider` và `AIExplanationDialog`.

## Sinh viên đã chỉnh sửa / kiểm chứng

- [x] Đã đọc hiểu code sinh ra
- [x] Đã chạy `flutter analyze` / `flutter test`
- Thay đổi thủ công:
  - Sử dụng `cleanupTimer.unref()` trong middleware Node.js để timer dọn rác không giữ tiến trình khi tắt server.
  - Chỉ cache kết quả khi `source == AISource.gemini` trong `AIProvider` để khi người dùng tắt Demo Mode sẽ gọi lại server thật thay vì dính cache Demo cũ.

## Bài học rút ra

- Tuyệt đối không nhúng `GEMINI_API_KEY` vào mã nguồn Flutter; khóa phải đặt ở `server/.env` kết hợp Rate Limiting trên server trung gian (BFF).
- Khi gọi bất đồng bộ trong `ChangeNotifier`, cần dùng biến đếm `_requestId` để loại bỏ kết quả trả về muộn (stale response / race-condition).
