# Prompt dùng trong sản phẩm (gửi Gemini qua server Node.js)

Nguồn: `server/src/services/prompt.builder.js`

## v1 – 2026-11-16 – Giải thích câu sai

- Model: `gemini-2.5-flash` (cấu hình qua `GEMINI_MODEL` trong `server/.env`)
- `temperature: 0.4`, `responseMimeType: application/json`

```text
Bạn là gia sư ôn thi trắc nghiệm song ngữ Việt - Anh.
Câu hỏi: {question}
Các lựa chọn:
A. ...
B. ...
Người học đã chọn: {selectedAnswer}
Đáp án đúng: {correctAnswer}

Giải thích chi tiết tại sao đáp án này sai và đưa ra ví dụ.
Yêu cầu:
- Trả lời bằng {Tiếng Việt|English}, ngắn gọn, dễ hiểu (tối đa ~200 từ).
- Trả về DUY NHẤT một JSON hợp lệ theo dạng:
{"whyWrong": "...", "correctExplanation": "...", "example": "...", "tip": "..."}
```

| Phiên bản | Thay đổi | Lý do |
|---|---|---|
| v1 | Bản đầu | Theo yêu cầu đề bài; ép JSON để app hiển thị có cấu trúc |

