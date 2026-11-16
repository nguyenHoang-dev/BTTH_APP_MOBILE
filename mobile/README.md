# Bilingual Quiz – Flutter Frontend (`mobile/`)

Đây là thư mục mã nguồn ứng dụng Flutter của đề tài **#32: Ôn tập trắc nghiệm song ngữ (+ Mở rộng AI)**.

👉 **Hướng dẫn cài đặt, cấu hình Server Node.js và cách chạy toàn bộ dự án:** Xem tại file [../README.md](../README.md) ở thư mục gốc.

> [!IMPORTANT]
> **Lưu ý cho thành viên nhóm:** Khi làm việc trong thư mục `mobile/`, nếu có bất kỳ phần code, luồng `Provider` hay cấu hình nào **không hiểu rõ hoặc thiếu ngữ cảnh**, bắt buộc phải **hỏi lại ngay**, **tuyệt đối không đoán mò** hay tự ý sửa các file lõi dùng chung (`lib/core/`, `lib/models/`).

## Lệnh thường dùng trong thư mục `mobile/`

```powershell
# Cài đặt dependencies
flutter pub get

# Chạy trên máy ảo Android (sau khi bật: flutter emulators --launch pixel_avd)
flutter run -d emulator-5554

# Chạy trên trình duyệt Chrome
flutter run -d chrome

# Kiểm tra lỗi tĩnh và chạy kiểm thử
flutter analyze
flutter test
```
