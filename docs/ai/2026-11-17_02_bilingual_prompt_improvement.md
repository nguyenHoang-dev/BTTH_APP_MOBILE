# 2026-11-17 – Cải thiện Prompt đa ngôn ngữ (Practice Mode)

## Thay đổi

**File:** `server/src/services/prompt.builder.js`

### Vấn đề cũ
Prompt trước đây viết instruction bằng tiếng Việt bất kể `language=en` hay `language=vi`.
Chỉ thay đổi câu "Trả lời bằng {lang}" ở cuối → Gemini vẫn bị ảnh hưởng bởi instruction tiếng Việt khi output tiếng Anh.

### Thay đổi mới
Tách thành 2 hàm độc lập:
- `_buildEnglishPrompt()` – toàn bộ instruction bằng tiếng Anh
- `_buildVietnamesePrompt()` – toàn bộ instruction bằng tiếng Việt

`buildExplainPrompt(payload)` điều phối dựa vào `payload.language`.

### Prompt tiếng Anh (language=en)
```
You are a bilingual (Vietnamese–English) quiz tutor.
Question: {question}
Options: ...
Student's answer: {selectedAnswer}
Correct answer: {correctAnswer}

Explain in detail why the student's answer is wrong and provide an example.
Requirements:
- Reply entirely in English, concise and easy to understand (max ~200 words).
- Return ONLY valid JSON in this exact format:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}
```

### Prompt tiếng Việt (language=vi) – không đổi về cấu trúc, chỉ làm sạch
```
Bạn là gia sư ôn thi trắc nghiệm song ngữ Việt - Anh.
Câu hỏi: {question}
Các lựa chọn: ...
Người học đã chọn: {selectedAnswer}
Đáp án đúng: {correctAnswer}

Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ.
Yêu cầu:
- Trả lời bằng Tiếng Việt, ngắn gọn, dễ hiểu (tối đa ~200 từ).
- Trả về DUY NHẤT một JSON hợp lệ theo dạng:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}
```

### JSON output contract (không đổi)
```json
{ "whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..." }
```

## Thêm field `category` vào request body

**File:** `server/src/controllers/explain.controller.js`

Field mới (optional): `"category": "grammar" | "vocabulary" | "flutter" | "network" | "dart"`

Dùng bởi `mock.service.js` để trả về tip phù hợp theo chủ đề khi ở Demo Mode.
Không ảnh hưởng đến Gemini prompt (category không được nhúng vào prompt).

## Lý do không nhúng category vào Gemini prompt
Câu hỏi đã chứa đầy đủ context (nội dung câu, options, đáp án đúng/sai).
Gemini tự suy ra category từ nội dung → không cần truyền thêm.
Truyền thêm category có thể bias Gemini giải thích sai hướng.

