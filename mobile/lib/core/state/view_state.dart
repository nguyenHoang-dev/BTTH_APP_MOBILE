/// Trạng thái chung cho mọi màn hình / provider.
///
/// Rubric yêu cầu xử lý đủ: Đang tải – Lỗi – Rỗng (và Thành công).
/// Dùng `sealed` để `switch` trong UI bắt buộc xử lý hết các nhánh
/// (thiếu nhánh => compiler báo lỗi).
sealed class ViewState<T> {
  const ViewState();

  bool get isLoading => this is LoadingState<T>;
  T? get dataOrNull => switch (this) {
        SuccessState<T>(:final data) => data,
        _ => null,
      };
}

/// Chưa làm gì (trước khi gọi load lần đầu).
final class IdleState<T> extends ViewState<T> {
  const IdleState();
}

final class LoadingState<T> extends ViewState<T> {
  const LoadingState();
}

final class SuccessState<T> extends ViewState<T> {
  const SuccessState(this.data);
  final T data;
}

/// Tải xong nhưng không có dữ liệu (vd. chưa có lịch sử làm bài).
final class EmptyState<T> extends ViewState<T> {
  const EmptyState([this.message = 'Chưa có dữ liệu']);
  final String message;
}

/// Lỗi đã được chuyển thành thông báo thân thiện với người dùng.
final class ErrorState<T> extends ViewState<T> {
  const ErrorState(this.message, {this.error});
  final String message;
  final Object? error;
}

