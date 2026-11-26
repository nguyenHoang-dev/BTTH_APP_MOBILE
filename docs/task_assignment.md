# Bảng Phân Công Nhiệm Vụ & Quy Trình Git (Nhóm 4 Thành Viên)

**Học phần:** INT1449 – Lập trình di động  
**Đề tài:** #32 – Ôn tập trắc nghiệm song ngữ (+ Mở rộng AI qua máy chủ riêng)

> [!CAUTION]
> **NGUYÊN TẮC LÀM VIỆC BẮT BUỘC – "KHÔNG HIỂU PHẢI HỎI NGAY, TUYỆT ĐỐI KHÔNG ĐOÁN MÒ":**
> 1. **Không đoán mò yêu cầu hay ngữ cảnh**: Khi đọc nhiệm vụ hoặc code của dự án, nếu bất kỳ thành viên nào (hoặc AI hỗ trợ thành viên đó) gặp chỗ **chưa hiểu rõ, thiếu ngữ cảnh (context), hoặc không chắc chắn hàm/biến đó hoạt động thế nào**, bắt buộc phải **hỏi lại ngay lập tức** trước khi viết code.
> 2. **Không tự ý phá vỡ hợp đồng giao tiếp (Interface / Schema)**: Nếu nhiệm vụ của bạn cần thêm trường vào `Question`, `QuizResult`, bảng SQLite hay JSON API `/api/explain`, hãy hỏi và thống nhất với thành viên phụ trách tầng đó trước — tuyệt đối không tự đoán rồi sửa một mình gây lỗi dây chuyền khi merge Git.
> 3. **Hiểu 100% từng dòng code mình commit**: Khi vấn đáp cuối kỳ, giảng viên sẽ mở ngẫu nhiên 1 file trong phần bạn phụ trách để hỏi từng dòng. Nếu AI gợi ý đoạn code nào bạn chưa hiểu, hãy yêu cầu giải thích cặn kẽ hoặc hỏi nhóm trưởng ngay.

---

## 1. Bảng phân công tổng quan (Dùng để nộp bài & tính hệ số cá nhân)

> Điền tên thật và MSSV của 4 thành viên vào bảng dưới đây trước khi nộp báo cáo cuối kỳ.

| STT | Thành viên | MSSV | Vai trò & Module phụ trách | Nhánh Git (`branch`) | Tỷ lệ đóng góp |
|:---:|---|---|---|---|---:|
| 1 | **[Họ tên TV1]** *(Nhóm trưởng)* | `2202xxxx` | **Kiến trúc lõi, Chế độ Thi thử & Đồng hồ đếm ngược (Countdown Timer)** | `feat/exam-timer` | **25%** |
| 2 | **[Họ tên TV2]** | `2202xxxx` | **Chế độ Luyện tập (Practice Mode), Đa ngôn ngữ & Ngân hàng 300 câu hỏi** | `feat/practice-bilingual` | **25%** |
| 3 | **[Họ tên TV3]** | `2202xxxx` | **Lưu trữ SQLite, Thống kê theo khối kiến thức & Ôn lại câu sai** | `feat/sqlite-stats` | **25%** |
| 4 | **[Họ tên TV4]** | `2202xxxx` | **Backend Node.js (Gemini API), Tích hợp AI, Chế độ Demo & Hồ sơ AI** | `feat/ai-backend` | **25%** |

---

## 2. Chi tiết công việc & File phụ trách của từng thành viên

Mỗi thành viên nắm rõ **các file mình sở hữu** để vừa không bị xung đột code (`merge conflict`) khi làm chung, vừa trả lời trôi chảy phần **Vấn đáp 5 phút mã nguồn** (giảng viên chọn ngẫu nhiên 1 file trong phần của mỗi thành viên để hỏi).

---

### 👤 Thành viên 1: Kiến trúc lõi + Chế độ Thi thử & Đồng hồ đếm ngược

#### Các file phụ trách chính (Cần nắm vững để vấn đáp)
- `mobile/lib/main.dart`, `mobile/lib/app.dart`
- `mobile/lib/core/state/view_state.dart`, `mobile/lib/core/di/app_dependencies.dart`
- `mobile/lib/core/logic/quiz_engine.dart`
- `mobile/lib/providers/quiz_provider.dart`
- `mobile/lib/screens/quiz_screen.dart`

#### Nhiệm vụ cần code thêm (`TODO`)
1. **Đồng hồ đếm ngược (Countdown Timer)** *(Tính năng mở rộng trong Rubric Đề #32)*:
   - Thêm `Timer? _timer` và `int _remainingSeconds` vào `QuizProvider`.
   - Khi bắt đầu chế độ Thi thử (`startQuiz`), đếm ngược từ 15 phút (900 giây). Khi về `0` thì tự động chấm điểm và chuyển sang màn kết quả.
   - **Bắt buộc theo Rubric**: Hủy `_timer?.cancel()` trong hàm `dispose()` của `QuizProvider` để không rò rỉ bộ nhớ.
2. **Bảng điều hướng câu hỏi (Question Palette / BottomSheet)**:
   - Trên `QuizScreen`, thêm nút mở danh sách 20 ô số (câu đã chọn hiện màu xanh, câu chưa chọn màu xám) để nhảy nhanh tới câu bất kỳ (`jumpToQuestion(int index)`).
3. **Kiểm thử (Unit & Widget Test)**:
   - Viết thêm ít nhất 4 test trong `mobile/test/quiz_logic_test.dart` và `mobile/test/quiz_screen_test.dart` kiểm tra đồng hồ đếm ngược, nhảy câu hỏi và tự nộp bài khi hết giờ.

#### Câu hỏi vấn đáp thường gặp cho TV1
- *Trạng thái của màn hình `QuizScreen` nằm ở đâu, ai được thay đổi nó?* $\rightarrow$ Nằm trong `QuizProvider` (`_state`, `_currentIndex`, `_answers`), chỉ các hàm của `QuizProvider` thay đổi và gọi `notifyListeners()`.
- *Vì sao không gọi `startQuiz()` trực tiếp trong hàm `build()`?* $\rightarrow$ Vì `build()` chạy lại ở mỗi frame, gọi trong đó sẽ gây vòng lặp nạp dữ liệu vô tận; phải gọi 1 lần trong `initState()` qua `addPostFrameCallback`.

---

### 👤 Thành viên 2: Chế độ Luyện tập + Đa ngôn ngữ & Ngân hàng 300 câu hỏi

#### Các file phụ trách chính (Cần nắm vững để vấn đáp)
- `mobile/assets/data/questions.json`
- `mobile/lib/models/question.dart`, `mobile/lib/models/localized_text.dart`
- `mobile/lib/repositories/quiz_repository.dart`
- `mobile/lib/providers/settings_provider.dart`
- `mobile/lib/screens/practice_screen.dart` *(tạo mới hoặc tách chế độ trên `QuizScreen`)*

#### Nhiệm vụ cần code thêm (`TODO`)
1. **Hoàn thiện ngân hàng 300 câu hỏi song ngữ** *(Tính năng tối thiểu của Đề #32)*:
   - Mở rộng file `mobile/assets/data/questions.json` từ 10 câu mẫu lên đủ **300 câu** chia theo các khối kiến thức (`category`: Dart, Widget, Layout, State, Async, Network, SQLite, Testing, Grammar, Vocabulary...).
2. **Chế độ Luyện tập (Practice Mode)** *(Tính năng tối thiểu của Đề #32)*:
   - Khác với chế độ Thi thử: khi người dùng bấm chọn 1 đáp án ở chế độ Luyện tập, giao diện **hiện ngay màu Xanh (Đúng) / Đỏ (Sai)** và hiển thị luôn phần giải thích tĩnh (`question.explanation`) bên dưới câu hỏi + nút *"Hỏi AI giải thích sâu hơn"*.
3. **Chọn khối kiến thức (Filter by Category) & Chọn ngôn ngữ**:
   - Thêm bộ lọc cho phép người dùng chọn ôn tập theo từng khối kiến thức cụ thể (hoặc "Tất cả").
   - Đảm bảo mọi nhãn giao diện đổi theo `AppLanguage` (`vi` / `en` / `both`) và đảm bảo vùng chạm nút bấm $\ge 48\text{dp}$ (Rubric mục 2).
4. **Kiểm thử**:
   - Viết ít nhất 4 test kiểm tra đọc JSON, lọc theo `category`, xử lý JSON lỗi định dạng và hiển thị song ngữ.

#### Câu hỏi vấn đáp thường gặp cho TV2
- *Nếu file `questions.json` bị hỏng cú pháp thì app có bị văng (crash) không?* $\rightarrow$ Không, `AssetQuizRepository` bắt `FormatException` và ném `AppException('Ngân hàng câu hỏi bị lỗi định dạng')`, `QuizProvider` chuyển sang `ErrorState` hiển thị màn hình lỗi kèm nút "Thử lại".
- *Làm sao để test `QuizProvider` mà không cần đọc file JSON thật?* $\rightarrow$ Truyền `FakeQuizRepository` qua constructor của `QuizProvider`.

---

### 👤 Thành viên 3: Lưu trữ SQLite + Thống kê theo khối kiến thức & Làm lại câu sai

#### Các file phụ trách chính (Cần nắm vững để vấn đáp)
- `mobile/lib/services/local_database.dart`
- `mobile/lib/models/quiz_result.dart`
- `mobile/lib/repositories/history_repository.dart`
- `mobile/lib/providers/history_provider.dart`
- `mobile/lib/screens/home_screen.dart`, `mobile/lib/screens/result_screen.dart`

#### Nhiệm vụ cần code thêm (`TODO`)
1. **Thống kê theo khối kiến thức (Category Statistics)** *(Tính năng tối thiểu của Đề #32)*:
   - Lưu thêm trường `category` hoặc thống kê số câu đúng/tổng số câu theo từng `category` trong SQLite.
   - Trên `HomeScreen`, hiển thị bảng/thanh tiến độ (`LinearProgressIndicator`) tỷ lệ % làm đúng của từng khối kiến thức để người học biết mình đang yếu khối nào.
2. **Hoàn thiện luồng "Làm lại câu sai"**:
   - Khi người dùng vào chế độ **"Ôn lại câu sai"** và trả lời **ĐÚNG** một câu từng sai, tự động xóa `question_id` đó khỏi bảng `wrong_answers` trong SQLite (đánh dấu đã thuộc bài).
3. **Xóa lịch sử làm bài (An toàn dữ liệu)**:
   - Thêm nút xóa lịch sử trên `HomeScreen` kèm hộp thoại `AlertDialog` xác nhận trước khi xóa (`DELETE FROM quiz_results`).
4. **Kiểm thử**:
   - Viết ít nhất 4 test cho `HistoryProvider` (trạng thái `EmptyState` khi chưa có lịch sử, tính điểm trung bình, điểm cao nhất, cập nhật danh sách câu sai).

#### Câu hỏi vấn đáp thường gặp cho TV3
- *Muốn đổi cách lưu trữ từ SQLite sang một cơ sở dữ liệu khác (vd. Hive/Isar), nhóm phải sửa những tệp nào?* $\rightarrow$ Nhờ tách interface `HistoryRepository`, chỉ cần viết class mới `implements HistoryRepository` và đổi 1 dòng khởi tạo trong `main.dart`. Tuyệt đối không phải sửa `QuizProvider`, `HistoryProvider` hay bất kỳ màn hình UI nào.
- *Nếu lưu SQLite bị lỗi giữa chừng thì người dùng có mất kết quả bài vừa làm không?* $\rightarrow$ Không, `QuizProvider.submit()` dùng `db.transaction` và `try-catch`: vẫn trả về `QuizResult` để mở `ResultScreen`, đồng thời gán `saveWarning` để hiện `SnackBar` báo cho người dùng.

---

### 👤 Thành viên 4: Backend Node.js (Gemini) + Tích hợp AI + Chế độ Demo & Hồ sơ AI

#### Các file phụ trách chính (Cần nắm vững để vấn đáp)
- Toàn bộ thư mục `server/` (`server.js`, `app.js`, `routes/`, `controllers/`, `services/gemini.service.js`, `prompt.builder.js`, `mock.service.js`)
- `mobile/lib/services/api_client.dart`, `mobile/lib/services/base_url_resolver.dart`
- `mobile/lib/core/errors/app_exception.dart`
- `mobile/lib/models/ai_explanation.dart`
- `mobile/lib/repositories/ai_repository.dart`, `mobile/lib/repositories/demo_ai_repository.dart`
- `mobile/lib/providers/ai_provider.dart`
- `mobile/lib/screens/ai_explanation_dialog.dart`
- Thư mục `docs/ai/` và `docs/architecture_flow.md`

#### Nhiệm vụ cần code thêm (`TODO`)
1. **Giới hạn lượt gọi (Rate Limiting) trên Server Node.js** *(Điểm cộng bảo mật AI)*:
   - Thêm middleware giới hạn số request theo IP (ví dụ tối đa 15 lần gọi AI / phút) trong `server/src/middlewares/` để bảo vệ hạn mức khóa Gemini.
2. **Nâng cấp trải nghiệm `AIExplanationDialog`**:
   - Hiển thị rõ câu hỏi, đáp án người dùng đã chọn và đáp án đúng ngay trên đầu Dialog.
   - Thêm nút **"Sao chép lời giải thích"** (`Clipboard.setData`) hoặc nút **"Tạo 1 câu hỏi tương tự"** để người học kiểm tra lại ngay.
3. **Quản lý Hồ sơ AI (`docs/ai/`)**:
   - Ghi lại các prompt quan trọng của cả nhóm vào `docs/ai/` theo đúng mẫu `docs/ai/_TEMPLATE.md`.
4. **Kiểm thử**:
   - Viết ít nhất 4 test kiểm tra `ApiClient` timeout, `AIRepositoryImpl` ở chế độ Demo, tự động fallback khi mất mạng, và chống race-condition trong `AIProvider`.

#### Câu hỏi vấn đáp thường gặp cho TV4
- *Khóa API nằm ở đâu? Nếu ai đó giải nén file APK thì thấy gì?* $\rightarrow$ `GEMINI_API_KEY` chỉ nằm trong file `server/.env` trên máy chủ Node.js (và bị chặn bởi `.gitignore`). Nếu giải nén APK sẽ chỉ thấy URL của máy chủ trung gian (`/api/explain`), hoàn toàn không có bất kỳ khóa API nào.
- *Nếu đang gọi AI mà tắt Wi-Fi / mất mạng thì app xử lý thế nào?* $\rightarrow$ `ApiClient` có timeout 15 giây, bắt `DioException` và đổi thành `AppException(type: network/timeout)`. `AIRepositoryImpl` bắt lỗi này và tự động fallback sang `DemoAIRepository` kèm thông báo *"Đang hiển thị dữ liệu Demo"*, hoặc hiển thị nút *"Thử lại" / "Chuyển sang Chế độ Demo"* trên Dialog.

---

## 3. Quy trình làm việc trên Git để đạt điểm tối đa (Tiêu chí 7 trong Rubric: 10 điểm)

Rubric quy định: **"Mỗi thành viên có commit đều đặn của mình (không dồn commit vào cuối kỳ)"** và **"flutter analyze không báo lỗi, flutter test đạt"**.

### Bước 1: Tạo nhánh riêng cho từng thành viên
```bash
git checkout -b feat/exam-timer          # Thành viên 1
git checkout -b feat/practice-bilingual  # Thành viên 2
git checkout -b feat/sqlite-stats        # Thành viên 3
git checkout -b feat/ai-backend          # Thành viên 4
```

### Bước 2: Kiểm tra trước mỗi lần commit & push
Trước khi `git commit`, mỗi thành viên bắt buộc chạy 2 lệnh sau trong thư mục `mobile/`:
```powershell
flutter analyze
flutter test
```
Chỉ khi báo `No issues found!` và `All tests passed!` mới tạo Pull Request để merge vào nhánh `main`.

### Bước 3: Lưu ý tuyệt đối về Bảo mật (Tránh bị trừ 10 điểm)
- **KHÔNG BAO GIỜ** commit file `server/.env` chứa khóa thật lên Git (đã có trong `.gitignore`).
- Chỉ commit file mẫu `server/.env.example`.

