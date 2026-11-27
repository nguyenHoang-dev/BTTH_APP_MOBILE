# Đề tài #32 – Ôn tập trắc nghiệm song ngữ (+ Mở rộng AI)

**Học phần:** INT1449 – Lập trình di động  
**Kiến trúc:** Clean Architecture + Provider (Flutter) & Node.js Express (BFF giữ khóa Gemini).

📐 Kiến trúc & luồng dữ liệu: [docs/architecture_flow.md](docs/architecture_flow.md) · 👥 Phân công 4 thành viên: [docs/task_assignment.md](docs/task_assignment.md) · 🤖 Hồ sơ AI: [docs/ai/](docs/ai/README.md)

> [!IMPORTANT]
> **QUY TẮC BẮT BUỘC DÀNH CHO MỌI THÀNH VIÊN TRONG NHÓM (& TRỢ LÝ AI):**
> - Khi đọc tài liệu và triển khai code, **nếu có bất kỳ phần nào chưa hiểu rõ, thiếu ngữ cảnh (context), hoặc chưa chắc chắn về luồng dữ liệu / cấu trúc hàm**, bắt buộc phải **DỪNG LẠI VÀ HỎI NGAY** (hỏi nhóm trưởng hoặc các thành viên phụ trách module liên quan).
> - **TUYỆT ĐỐI KHÔNG ĐOÁN MÒ**, không tự ý giả định yêu cầu, không tự sửa cấu trúc dùng chung (`models/`, `repositories/`, `ViewState`, `api_client.dart`, schema SQLite) khi chưa trao đổi và thống nhất với cả nhóm.
> - Theo Rubric học phần: *"Mỗi thành viên phải giải thích được mọi dòng mã mình nộp; không giải thích được thì xử lý như mã không ghi nguồn"*. Vì vậy không bao giờ copy-paste hoặc commit đoạn code mà bản thân chưa hiểu 100%.

---

## 1. Mục đích dự án

Ứng dụng hỗ trợ người học ôn tập ngân hàng **300 câu hỏi trắc nghiệm song ngữ (Việt – Anh)** hoàn toàn offline, kết hợp **Trợ lý AI (Gemini)** giải thích chuyên sâu vì sao đáp án đã chọn bị sai kèm ví dụ minh họa và mẹo ghi nhớ.

- **Hoạt động Offline 100%** cho luồng làm bài trắc nghiệm, chấm điểm, thống kê và ôn lại câu sai.
- **Bảo mật tuyệt đối khóa API**: `GEMINI_API_KEY` chỉ nằm ở máy chủ Node.js (`server/.env`), không bao giờ xuất hiện trong mã nguồn Flutter hay file APK.
- **Chế độ Demo 3 lớp**: dùng được tính năng AI ngay cả khi chưa cấu hình khóa API hoặc khi mất mạng.

---

## 2. Cấu trúc thư mục

```text
BTL_APP/
├── docs/
│   ├── architecture_flow.md        # Sơ đồ kiến trúc, luồng Offline & luồng AI (Mermaid)
│   ├── task_assignment.md          # Bảng phân công nhiệm vụ & câu hỏi vấn đáp cho 4 thành viên
│   └── ai/                         # Hồ sơ lịch sử prompt AI (theo Rubric)
├── server/                         # Backend trung gian Node.js Express (port 3000)
│   ├── .env.example                # Mẫu cấu hình biến môi trường (không chứa khóa thật)
│   └── src/
│       ├── server.js, app.js
│       ├── config/env.js
│       ├── routes/explain.routes.js        # POST /api/explain
│       ├── controllers/explain.controller.js
│       ├── services/gemini.service.js      # Gọi Gemini REST API + timeout 12s
│       ├── services/prompt.builder.js      # Prompt giải thích câu sai
│       ├── services/mock.service.js        # Dữ liệu giả lập khi chưa có khóa
│       └── middlewares/error.middleware.js
└── mobile/                         # Ứng dụng Flutter (Android, iOS, Web)
    ├── assets/data/questions.json  # Ngân hàng câu hỏi song ngữ
    ├── lib/
    │   ├── main.dart               # Composition Root (khởi tạo DI & chọn kho lưu trữ theo nền tảng)
    │   ├── app.dart                # MultiProvider + MaterialApp
    │   ├── core/
    │   │   ├── config/app_config.dart     # Cấu hình dart-define & timeout 15s
    │   │   ├── state/view_state.dart      # Sealed class: Idle / Loading / Success / Empty / Error
    │   │   ├── errors/app_exception.dart  # Chuẩn hóa thông báo lỗi tiếng Việt thân thiện
    │   │   ├── logic/quiz_engine.dart     # Logic thuần: random câu hỏi & chấm điểm
    │   │   └── di/app_dependencies.dart
    │   ├── models/                 # Question, LocalizedText, QuizResult, AIExplanation
    │   ├── repositories/           # QuizRepository (JSON), HistoryRepository (SQLite/RAM), AIRepository
    │   ├── providers/              # QuizProvider, AIProvider, HistoryProvider, SettingsProvider
    │   ├── screens/                # HomeScreen, QuizScreen, ResultScreen, AIExplanationDialog
    │   └── services/               # ApiClient (Dio), BaseUrlResolver, LocalDatabase (sqflite)
    └── test/
        ├── helpers/fakes.dart      # Fake/Mock repositories phục vụ kiểm thử độc lập
        ├── quiz_logic_test.dart    # Unit tests cho logic, chấm điểm, Demo Mode & fallback mạng
        └── quiz_screen_test.dart   # Widget tests cho đủ trạng thái Loading / Error / Empty / Success
```

---

## 3. Yêu cầu môi trường & Cài đặt (Dưới 15 phút)

- **Flutter SDK**: `>= 3.13` (Dart `>= 3.13`)
- **Node.js**: `>= 18` (dùng sẵn `fetch` và `AbortSignal.timeout`)
- **Thiết bị chạy**: Trình duyệt **Chrome** (chạy ngay không cần máy ảo), **Máy ảo Android (`pixel_avd`)**, hoặc **Điện thoại Android thật**.

### Bước 1: Cài đặt Backend Node.js
```powershell
cd server
npm install
# Tạo file .env từ mẫu (nếu chưa có):
Copy-Item .env.example .env
```
> **Cấu hình khóa AI (Tùy chọn):**
> - Để trống `GEMINI_API_KEY=` trong `server/.env` $\rightarrow$ Server tự động chạy ở **DEMO MODE** (trả dữ liệu giả lập).
> - Điền `GEMINI_API_KEY=your_key_here` (lấy tại Google AI Studio) $\rightarrow$ Server chạy **REAL MODE** gọi model `gemini-2.5-flash`.

### Bước 2: Cài đặt thư viện Flutter
```powershell
cd ../mobile
flutter pub get
```

---

## 4. Cách chạy dự án

Mở **2 cửa sổ Terminal** song song (hoặc dùng tính năng **Run and Debug (`Ctrl + Shift + D`)** trong VS Code / Antigravity):

### Terminal 1 – Chạy Server Node.js (Port 3000)
```powershell
cd server
npm run dev
# Kiểm tra nhanh: mở http://localhost:3000/api/health
```

### Terminal 2 – Chạy Ứng dụng Flutter

#### Cách A: Chạy trên Máy ảo Android (`pixel_avd` / `emulator-5554`)
Ứng dụng tự nhận diện máy ảo và gọi server qua `http://10.0.2.2:3000`, lưu lịch sử vào **SQLite (`sqflite`)**:
```powershell
cd mobile

# 1. Bật máy ảo Android (chạy ngầm – mất khoảng 15–25 giây để Android khởi động xong)
flutter emulators --launch pixel_avd

# 2. Chờ đến khi máy ảo hiện màn hình chính (hoặc gõ `flutter devices` thấy `emulator-5554`), rồi chạy:
flutter run -d emulator-5554 --device-timeout 60
```

#### Cách B: Chạy nhanh trên Trình duyệt Web (Chrome)
Khi máy chưa bật máy ảo, có thể chạy trực tiếp trên Chrome (tự trỏ về `http://localhost:3000` và lưu lịch sử trong bộ nhớ phiên làm việc):
```powershell
cd mobile
flutter run -d chrome
```

#### Cách C: Chạy trên Điện thoại Android thật (cùng mạng Wi-Fi với máy tính)
Lấy địa chỉ IPv4 LAN của máy tính (gõ `ipconfig` trong PowerShell, ví dụ `192.168.1.10`) và truyền qua `--dart-define`:
```powershell
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```
*(Lưu ý: nếu chạy trên điện thoại thật để build bản cài đặt khi đang bật giới hạn `x86_64` trong `android/app/build.gradle.kts`, hãy thêm `"arm64-v8a"` vào `abiFilters` và bỏ `"**/arm64-v8a/**"` khỏi `excludes`).*

#### Cách D: Chạy cưỡng bức ở Chế độ Demo (Offline 100%)
```powershell
cd mobile
flutter run --dart-define=DEMO_MODE=true
```

---

## 5. Cách chạy Kiểm thử & Phân tích mã nguồn

Đảm bảo cả 2 lệnh dưới đây đều đạt 100% trước khi commit code (Tiêu chí 5 & 7 trong Rubric):

```powershell
cd mobile

# 1. Kiểm tra quy chuẩn code & lỗi tĩnh (Yêu cầu: No issues found!)
flutter analyze

# 2. Chạy toàn bộ Unit Test & Widget Test (Yêu cầu: All tests passed!)
flutter test
```

---

## 6. Dữ liệu lưu ở đâu & Quyền riêng tư (Tiêu chí 6 trong Rubric)

| Loại dữ liệu | Nơi lưu trữ | Chi tiết |
|---|---|---|
| **Ngân hàng câu hỏi** | `mobile/assets/data/questions.json` | Đóng gói sẵn trong ứng dụng (chỉ đọc, hoạt động offline). |
| **Lịch sử làm bài & Câu làm sai** | **SQLite cục bộ** (`bilingual_quiz.db`) | Nằm trong thư mục ứng dụng trên thiết bị (`getDatabasesPath()`), gồm 2 bảng `quiz_results` và `wrong_answers`. Trên bản Web dùng `InMemoryHistoryRepository`. Không đồng bộ lên đám mây. |
| **Cài đặt ngôn ngữ & Demo Mode** | Bộ nhớ trạng thái (`SettingsProvider`) | Lưu trong phiên chạy ứng dụng. |
| **Khóa `GEMINI_API_KEY`** | `server/.env` (trên máy chủ) | Đã loại trừ khỏi Git qua `.gitignore`. Không tồn tại trong APK. |

**Quyền ứng dụng (`AndroidManifest.xml`):**
- Chỉ xin duy nhất quyền `android.permission.INTERNET` để gửi câu hỏi sang máy chủ Node.js khi người dùng chủ động bấm **"Hỏi AI tại sao sai"**. Không xin quyền camera, vị trí, danh bạ hay bộ nhớ ngoài.

---

## 7. Mục "Dùng AI" (Theo quy định học thuật của Rubric)

- **Công cụ AI đã sử dụng trong quá trình phát triển**: Antigravity (hỗ trợ khởi tạo khung kiến trúc Clean Architecture + Provider, cấu hình Gradle và viết tài liệu luồng dữ liệu).
- **Lịch sử các đoạn hội thoại & prompt quan trọng**: Lưu trữ đầy đủ tại thư mục [docs/ai/](docs/ai/README.md).
- **Cam kết của nhóm**: Toàn bộ thành viên đã tự chạy thử, kiểm chứng bằng `flutter analyze` & `flutter test`, và nắm vững từng dòng mã trong phần việc được phân công tại [docs/task_assignment.md](docs/task_assignment.md).


## 8. Hướng dẫn Build APK & Kết nối chạy trên Điện thoại Android thật
## Phân tích & Hướng kết nối hiệu quả nhất trên điện thoại thật
   App có 2 phần chức năng:
   - **Làm bài 300 câu hỏi, chấm điểm, lưu lịch sử SQLite, ôn câu sai**: chạy **100% Offline** ngay trong APK, không cần server.
   - **Tính năng "Hỏi AI tại sao sai"**: gọi `POST {baseUrl}/api/explain` tới server Node.js (hoặc tự fallback về Demo nếu bật **Chế độ Demo AI** / mất kết nối).

### Phương án A: Cắm cáp USB + `adb reverse` (Hiệu quả & ổn định nhất khi demo/test)
   - **Cách hoạt động**: Dùng `app-release.apk` mặc định (trỏ về `http://localhost:3000` trên điện thoại), rồi dùng lệnh `adb reverse tcp:3000 tcp:3000` để chuyển tiếp cổng `3000` từ điện thoại thẳng về cổng `3000` của PC qua cáp USB.
   - **Ưu điểm**:
   - Không phụ thuộc IP Wi-Fi (ra quán cafe hay lên phòng bảo vệ đồ án đổi mạng vẫn chạy ngay).
   - Không bị tường lửa Windows Firewall hoặc tính năng *AP/Client Isolation* của Wi-Fi công cộng/trường học chặn.
### Phương án B: Chạy độc lập 100% Offline (Demo Mode)
   - Cài `app-release.apk` lên điện thoại (gửi qua Zalo/Drive/USB đều được), bật công tắc **"Chế độ Demo AI"** ngay trên màn hình chính. Phù hợp khi không bật laptop/server.
   Lấy file mobile/build/app/outputs/flutter-apk/app-release.apk (hoặc mobile/build/app/outputs/flutter-apk/bilingual-quiz-usb-offline.apk):
   • Cách 1 (Không cần cáp/ADB): Gửi file app-release.apk sang điện thoại (qua Zalo Cloud của tôi, Google Drive, Telegram, hoặc copy vào bộ nhớ máy) -> mở file trên điện thoại -> cho phép "Cài đặt ứng dụng từ nguồn không xác
   định" -> bấm Cài đặt.
   • Cách 2 (Dùng cáp USB): Cắm điện thoại bật USB Debugging rồi chạy:
      & "C:\Users\TuHuynh\AppData\Local\Android\sdk\platform-tools\adb.exe" install -r "C:\Users\TuHuynh\OneDrive\Desktop\BTL App\BTTH_APP_MOBILE\mobile\build\app\outputs\flutter-apk\app-release.apk"
   ---
## Hướng dẫn Build APK & Kết nối (từng bước)
### Bước 1: Bật Gỡ lỗi USB (USB Debugging) trên điện thoại Android
   1. Vào *Cài đặt (Settings)* -> *Giới thiệu điện thoại*.
   2. Nhấn *7 lần* liên tiếp vào *Số bản dựng*  để mở *Tùy chọn nhà phát triển (Developer options)*.
   3. Vào **Cài đặt** -> **Hệ thống / Cài đặt bổ sung** -> **Tùy chọn nhà phát triển** -> Bật **Gỡ lỗi USB (USB Debugging)**.
      
### Bước 2: Cắm cáp USB vào máy tính & Kiểm tra kết nối ADB
   1. Cắm cáp USB truyền dữ liệu, trên điện thoại chọn **Cho phép gỡ lỗi USB (Allow USB debugging)**.
   2. Chạy lệnh kiểm tra thiết bị trong PowerShell:
   ```powershell
   & "C:\Users\TuHuynh\AppData\Local\Android\sdk\platform-tools\adb.exe" devices -l
   ```
   Thấy dòng có chữ `device` (không phải `unauthorized`) là kết nối thành công.

### Bước 3: Cài APK lên điện thoại thật
   - **Nếu dùng Phương án A (USB + `adb reverse` - Khuyên dùng):**
   ```powershell
   & "C:\Users\TuHuynh\AppData\Local\Android\sdk\platform-tools\adb.exe" install -r "C:\Users\TuHuynh\OneDrive\Desktop\BTL App\BTTH_APP_MOBILE\mobile\build\app\outputs\flutter-apk\app-release.apk"
   ```
   - **Nếu dùng Phương án B (Wi-Fi LAN không dây `192.168.1.4`):**
   ```powershell
   & "C:\Users\TuHuynh\AppData\Local\Android\sdk\platform-tools\adb.exe" install -r "C:\Users\TuHuynh\OneDrive\Desktop\BTL App\BTTH_APP_MOBILE\mobile\build\app\outputs\flutter-apk\bilingual-quiz-wifi-192.168.1.4.apk"
   ```
   *(Hoặc copy file `.apk` vào điện thoại bằng cáp/Google Drive rồi mở trực tiếp trên điện thoại để cài đặt).*

### Bước 4: Khởi động Backend Server trên máy tính
   Mở PowerShell tại thư mục `server/`:
   ```powershell
   cd "C:\Users\TuHuynh\OneDrive\Desktop\BTL App\BTTH_APP_MOBILE\server"
   npm start
   ```
   - Nếu muốn dùng **Gemini AI thật** (thay vì Demo Mode): mở file `server/.env` và điền key của bạn vào `GEMINI_API_KEY=...`, sau đó chạy lại `npm start`.

### Bước 5: Mở đường kết nối từ điện thoại về Server
   - **Theo Phương án A (cắm cáp USB)**: Mở một cửa sổ PowerShell khác và chạy:
   ```powershell
   & "C:\Users\TuHuynh\AppData\Local\Android\sdk\platform-tools\adb.exe" reverse tcp:3000 tcp:3000
   ```
   *(Mỗi lần rút cáp cắm lại chỉ cần chạy lại dòng lệnh này).*

   - **Theo Phương án B (Wi-Fi LAN `192.168.1.4`)**:
   1. Mở cổng `3000` trên Windows Firewall (chạy PowerShell với quyền **Run as Administrator** 1 lần duy nhất):
      ```powershell
      New-NetFirewallRule -DisplayName "BTL Node Server 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow
      ```
   2. Test từ trình duyệt trên điện thoại: mở `http://192.168.1.4:3000/api/health` — nếu hiện `{"status":"ok",...}` là thông mạng hoàn toàn!

### Bước 6: Kiểm tra trên App
   1. Mở app **"Ôn tập song ngữ"** trên điện thoại.
   2. Làm thử bài trắc nghiệm -> kiểm tra lưu lịch sử sau khi thoát mở lại app (SQLite).
   3. Vào màn hình kết quả -> bấm **"Hỏi AI tại sao sai"** (tắt công tắc *Chế độ Demo AI* ở màn hình chính nếu muốn test gọi trực tiếp sang server Node.js trên máy tính).
   4. *(Tùy chọn cho bản nộp Google Play sau này)*: Hiện tại `release` đang ký bằng `debug.keystore` để cài test trực tiếp; nếu xuất bản lên Play Store thì cần tạo keystore riêng (`keytool`) và cấu hình `key.properties`.

