# Kiến trúc & Luồng dữ liệu – Đề tài #32: Ôn tập trắc nghiệm song ngữ (+ Mở rộng AI)

> [!IMPORTANT]
> **QUY TẮC ĐỌC & TRIỂN KHAI KIẾN TRÚC:**
> - Tài liệu này là chuẩn tham chiếu chung cho cả 4 thành viên. Khi đọc sơ đồ luồng hoặc viết code nối giữa các tầng (`Screen` $\leftrightarrow$ `Provider` $\leftrightarrow$ `Repository` $\leftrightarrow$ `Service / Server`), **nếu có bất kỳ điểm nào chưa rõ hoặc thiếu ngữ cảnh thì PHẢI HỎI LẠI NGAY, TUYỆT ĐỐI KHÔNG ĐOÁN MÒ**.
> - Không tự ý gọi tắt qua các tầng (ví dụ: không gọi `ApiClient` hay `LocalDatabase` trực tiếp từ `Screen`) và không tự ý thay đổi kiểu trả về của `ViewState<T>` khi chưa hỏi ý kiến cả nhóm.

## 1. Tổng quan kiến trúc

Ứng dụng tách 3 tầng rõ ràng (Clean Architecture rút gọn + Provider):

| Tầng | Thư mục | Trách nhiệm | Được phép phụ thuộc |
|---|---|---|---|
| **UI** | `lib/screens/` | Vẽ giao diện, bắt sự kiện, render theo `ViewState` | providers, models |
| **State / Logic** | `lib/providers/`, `lib/core/logic/` | Quản lý trạng thái, nghiệp vụ (random, chấm điểm) | repositories (interface), models |
| **Data** | `lib/repositories/`, `lib/services/` | Đọc JSON, SQLite, gọi HTTP | models, core |
| **Backend** | `server/` | Giữ `GEMINI_API_KEY`, gọi Gemini | – |

```mermaid
flowchart TD
    subgraph Flutter["📱 Flutter App"]
        UI["screens/ (UI)"] -->|"context.read / watch"| P["providers/ (ChangeNotifier)"]
        P --> E["core/logic/QuizEngine (thuần Dart)"]
        P -->|"interface"| QR["QuizRepository"]
        P -->|"interface"| HR["HistoryRepository"]
        P -->|"interface"| AR["AIRepository"]
        QR --> JSON[("assets/data/questions.json")]
        HR --> DB[("SQLite - sqflite")]
        AR -->|"Demo Mode"| MOCK["DemoAIRepository (mock)"]
        AR -->|"Real Mode"| API["services/ApiClient (Dio, timeout 15s)"]
    end
    API -->|"POST /api/explain"| NODE["🟩 Node.js Express :3000"]
    NODE -->|"x-goog-api-key (chỉ ở server)"| GEM["☁️ Gemini API"]
```

### Nguyên tắc bắt buộc (map với Rubric)

| Rubric | Cách đáp ứng |
|---|---|
| Tách UI / logic / dữ liệu | UI chỉ gọi Provider; Provider chỉ biết **interface** repository. |
| Không gọi mạng trong `build()` | Mọi lần tải dữ liệu được kích hoạt trong `initState()` qua `addPostFrameCallback`. |
| Thay thế được bằng mock | `AppDependencies` (Composition Root) + constructor injection. Test dùng `FakeQuizRepository`, `FakeHistoryRepository`, `DemoAIRepository`, Dio adapter giả. |
| Timeout + try-catch + lỗi thân thiện | `ApiClient` timeout 15s; mọi lỗi → `AppException(message tiếng Việt)`. Server gọi Gemini có `AbortSignal.timeout(12s)`. |
| Loading / Error / Empty | `sealed class ViewState<T>` → `switch` trong UI bắt buộc xử lý đủ nhánh. |
| API key ở server | Key chỉ nằm trong `server/.env` (bị `.gitignore`). App Flutter không có key. |
| Chế độ Demo | (1) Công tắc Demo trong app; (2) mất mạng → tự fallback mock; (3) server chưa có key → server trả mock. |
| Hồ sơ AI | `docs/ai/` lưu lịch sử prompt. |

---

## 2. Luồng Offline – Làm bài trắc nghiệm

**Nạp 300 câu từ JSON → Random câu hỏi → Người dùng chọn → Chấm điểm → Thống kê**

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant HS as HomeScreen
    participant QS as QuizScreen
    participant QP as QuizProvider
    participant QE as QuizEngine
    participant QR as AssetQuizRepository
    participant HR as SqfliteHistoryRepository
    participant RS as ResultScreen

    U->>HS: Bấm "Làm bài ngẫu nhiên"
    HS->>QS: Navigator.push
    QS->>QP: initState → startQuiz()
    QP-->>QS: LoadingState (spinner)
    QP->>QR: loadAllQuestions()
    QR->>QR: rootBundle.loadString(questions.json) + jsonDecode (cache RAM)
    alt JSON lỗi
        QR-->>QP: throw AppException("Ngân hàng câu hỏi bị lỗi định dạng")
        QP-->>QS: ErrorState → nút "Thử lại"
    else Thành công (300 câu)
        QR-->>QP: List<Question>
        QP->>QE: pickRandom(bank, 20)
        alt Không có câu nào
            QP-->>QS: EmptyState
        else
            QP-->>QS: SuccessState(20 câu)
        end
    end
    loop Mỗi câu hỏi
        U->>QS: Chọn đáp án
        QS->>QP: selectAnswer(i) / next() / previous()
    end
    U->>QS: Nộp bài
    QS->>QP: submit()
    QP->>QE: grade(questions, answers)
    QE-->>QP: QuizResult (điểm, câu sai)
    QP->>HR: saveResult() → INSERT quiz_results + wrong_answers (transaction)
    Note over QP,HR: Lỗi lưu không chặn luồng → chỉ hiện SnackBar cảnh báo
    QS->>RS: pushReplacement(result)
    RS-->>U: Điểm, % đúng, danh sách câu sai
    U->>HS: Về trang chủ → HistoryProvider.load() → Thống kê (số lượt, điểm TB, cao nhất)
```

**Chi tiết từng bước**

1. **Nạp dữ liệu**: `AssetQuizRepository` đọc `assets/data/questions.json` (offline 100%), parse thành `List<Question>`, cache lại để lần sau không đọc file nữa.
2. **Random**: `QuizEngine.pickRandom()` xáo trộn bản sao và lấy `AppConfig.questionsPerQuiz` (20) câu không trùng. Chế độ "Ôn lại câu sai" lọc theo `question_id` trong bảng `wrong_answers`.
3. **Chọn đáp án**: `QuizProvider` lưu `Map<indexCâu, indexĐápÁn>`; UI tự rebuild nhờ `notifyListeners()`.
4. **Chấm điểm**: `QuizEngine.grade()` (hàm thuần → unit test được) trả `QuizResult` gồm số câu đúng, điểm thang 10, danh sách `UserAnswer` sai.
5. **Thống kê**: kết quả lưu SQLite; `HistoryProvider` đọc lại để tính số lượt, điểm trung bình, điểm cao nhất.

**Lược đồ SQLite** (`lib/services/local_database.dart`)

```mermaid
erDiagram
    quiz_results ||--o{ wrong_answers : "có"
    quiz_results {
        INTEGER id PK
        INTEGER total_questions
        INTEGER correct_count
        INTEGER duration_seconds
        TEXT taken_at
    }
    wrong_answers {
        INTEGER id PK
        INTEGER result_id FK
        INTEGER question_id
        INTEGER selected_index
        TEXT created_at
    }
```

---

## 3. Luồng AI – Giải thích câu sai

**UI gọi `explainAnswer()` → Provider → `AIRepository` → (Demo: mock | Real: Node.js, timeout 15s) → Gemini → App → Dialog**

```mermaid
sequenceDiagram
    actor U as Người dùng
    participant RS as ResultScreen
    participant D as AIExplanationDialog
    participant AP as AIProvider
    participant AR as AIRepositoryImpl
    participant DM as DemoAIRepository
    participant AC as ApiClient (Dio 15s)
    participant N as Node.js /api/explain
    participant G as Gemini API

    U->>RS: Bấm "Hỏi AI tại sao sai"
    RS->>D: showDialog
    D->>AP: initState → explainAnswer(answer, lang)
    AP->>AP: Có cache? → SuccessState ngay
    AP-->>D: LoadingState ("AI đang phân tích...")
    AP->>AR: explainAnswer()
    alt Demo Mode BẬT
        AR->>DM: explainAnswer()
        DM-->>AR: AIExplanation(source = demo)
    else Real Mode
        AR->>AC: POST /api/explain {question, options, selectedAnswer, correctAnswer, language}
        AC->>N: HTTP (connect/send/receive timeout 15s)
        alt Server chưa có GEMINI_API_KEY
            N-->>AC: 200 {source: "demo", ...}
        else Có key
            N->>G: generateContent (prompt + AbortSignal.timeout 12s)
            G-->>N: JSON text
            N->>N: parse JSON {whyWrong, correctExplanation, example, tip}
            N-->>AC: 200 {source: "gemini", ...}
        end
        alt Mất mạng / timeout
            AC-->>AR: AppException(network/timeout)
            AR->>DM: fallback mock
            DM-->>AR: AIExplanation(demo) + notice "Đang hiển thị dữ liệu Demo"
        else Server lỗi 4xx/5xx
            AC-->>AR: AppException(message thân thiện)
            AR-->>AP: rethrow
        end
    end
    AR-->>AP: AIExplanation
    alt Thành công
        AP-->>D: SuccessState → hiển thị 4 mục (Vì sao sai / Đáp án đúng / Ví dụ / Mẹo)
    else Nội dung rỗng
        AP-->>D: EmptyState
    else Lỗi
        AP-->>D: ErrorState → "Thử lại" hoặc "Chuyển sang Chế độ Demo"
    end
```

**Prompt gửi Gemini** (`server/src/services/prompt.builder.js`):

> Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ.
> (kèm câu hỏi, các lựa chọn, đáp án người học chọn, đáp án đúng; yêu cầu trả về JSON `{whyWrong, correctExplanation, example, tip}`)

**Hợp đồng API**

```http
POST /api/explain
Content-Type: application/json

{
  "question": "Choose the correct tense: \"She ___ here since 2010.\"",
  "options": ["lives", "lived", "has lived", "is living"],
  "selectedAnswer": "lived",
  "correctAnswer": "has lived",
  "language": "en"
}
```

```json
200 OK
{
  "source": "gemini",
  "whyWrong": "...",
  "correctExplanation": "...",
  "example": "...",
  "tip": "..."
}
```

Lỗi: `{ "error": { "message": "<thông báo thân thiện>" } }` với mã 400 / 429 / 502 / 504.

---

## 4. Ma trận Base URL (tự nhận diện thiết bị)

Xử lý tại `lib/services/base_url_resolver.dart`:

| Môi trường | Base URL | Lưu trữ lịch sử | Cách chạy |
|---|---|---|---|
| Android Emulator | `http://10.0.2.2:3000` | SQLite (`sqflite`) | `flutter emulators --launch pixel_avd` rồi `flutter run -d emulator-5554` |
| Web (Chrome / Edge) | `http://localhost:3000` | RAM (`InMemoryHistoryRepository`) | `flutter run -d chrome` |
| iOS Simulator | `http://localhost:3000` | SQLite (`sqflite`) | `flutter run` |
| Thiết bị thật | IP LAN của máy tính | SQLite (`sqflite`) | `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000` |
| Ghi đè thủ công | giá trị `API_BASE_URL` | theo nền tảng | luôn được ưu tiên nếu có |

> Thiết bị thật nhưng quên `API_BASE_URL` → request lỗi kết nối → `AIRepositoryImpl` tự fallback Demo, app không bị crash.

