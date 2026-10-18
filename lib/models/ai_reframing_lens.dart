enum ReframingLensType {
  compassion,
  growth,
  zoomOut,
}

class ReframingLens {
  final ReframingLensType type;
  final String label;
  final String emoji;
  final String description;

  const ReframingLens({
    required this.type,
    required this.label,
    required this.emoji,
    required this.description,
  });

  static const List<ReframingLens> all = [
    ReframingLens(
      type: ReframingLensType.compassion,
      label: 'Trắc ẩn',
      emoji: '🕊️',
      description: 'Dịu dàng với bản thân như đang an ủi một người bạn thân',
    ),
    ReframingLens(
      type: ReframingLensType.growth,
      label: 'Trưởng thành',
      emoji: '🌱',
      description: 'Nhận diện giá trị cốt lõi & bài học tiềm ẩn sau thử thách',
    ),
    ReframingLens(
      type: ReframingLensType.zoomOut,
      label: 'Thu phóng',
      emoji: '🔭',
      description: 'Nhìn từ tương lai và tập trung vào điều mình kiểm soát được',
    ),
  ];

  static String getThoughtFor({
    required ReframingLensType type,
    required String emotionKey,
    String? defaultThought,
  }) {
    switch (type) {
      case ReframingLensType.compassion:
        switch (emotionKey) {
          case 'stressed':
            return 'Bạn đang gánh vác rất nhiều việc. Cơ thể và tâm trí mỏi mệt là tín hiệu cần nghỉ ngơi chính đáng, không phải lỗi của bạn. Hãy thả lỏng đôi vai.';
          case 'anxious':
            return 'Cảm giác lo âu cho thấy bạn rất quan tâm và muốn mọi việc tốt đẹp. Nhưng bạn không cần phải hoàn hảo để xứng đáng được bình yên ngay lúc này.';
          case 'angry':
            return 'Cơn giận này là phản ứng tự nhiên khi bạn cảm thấy ranh giới của mình bị tổn thương. Hãy ôm lấy cảm xúc ấy một cách dịu dàng trước khi chọn hành động.';
          case 'sad':
            return 'Nỗi buồn là minh chứng trái tim bạn chân thành và biết yêu thương. Nếu một người bạn thân cũng buồn như thế này, bạn sẽ muốn ở bên ôm họ.';
          case 'happy':
          case 'calm':
          case 'grateful':
            return 'Bạn xứng đáng đón nhận niềm vui và sự an yên này trọn vẹn mà không cần cảm thấy âu lo về ngày mai.';
          default:
            return 'Dù mọi chuyện đang thế nào, hãy nhớ rằng bạn đã cố gắng hết sức trong khả năng của mình ngày hôm nay.';
        }

      case ReframingLensType.growth:
        switch (emotionKey) {
          case 'stressed':
            return 'Áp lực này đang cho bạn thấy ranh giới chịu tải của bản thân. Đây là cơ hội quý giá để học cách từ chối và thiết lập lại thứ tự ưu tiên.';
          case 'anxious':
            return 'Nỗi băn khoăn này nhắc bạn chuẩn bị kỹ càng, nhưng cũng là thao trường để tôi rèn khả năng thích nghi với sự bất định.';
          case 'angry':
            return 'Cơn tức giận làm sáng tỏ giá trị quan trọng nào bạn đang coi trọng. Bạn có thể biến năng lượng này thành tiếng nói quyết đoán và rõ ràng.';
          case 'sad':
            return 'Khoảng lặng của nỗi buồn giúp bạn nhìn nhận lại điều gì thực sự có ý nghĩa trong cuộc sống và buông bỏ những kỳ vọng không còn phù hợp.';
          case 'happy':
          case 'calm':
          case 'grateful':
            return 'Cảm xúc tích cực này là nguồn năng lượng tái tạo, nhắc bạn về những điều nuôi dưỡng tâm hồn bạn tốt nhất.';
          default:
            return 'Mỗi trải nghiệm phức tạp đều là một viên gạch giúp tôi hiểu sâu hơn về nội tâm và sự kiên cường của chính mình.';
        }

      case ReframingLensType.zoomOut:
        switch (emotionKey) {
          case 'stressed':
            return 'Sau 6 tháng hoặc 1 năm nữa, sự cố cụ thể này có còn quan trọng không? Hãy phân tách việc gì nằm trong tầm kiểm soát lúc này và bỏ qua phần còn lại.';
          case 'anxious':
            return 'Não bộ đang vẽ ra kịch bản xấu nhất để tự vệ. Nhưng trong quá khứ, bạn đã vượt qua 100% những ngày khó khăn tương tự để đứng ở đây hôm nay.';
          case 'angry':
            return 'Cách người khác cư xử là lựa chọn của họ và nằm ngoài tầm kiểm soát của bạn. Quyền năng duy nhất của bạn là cách bạn chọn giữ sự bình yên cho mình.';
          case 'sad':
            return 'Cảm xúc như thời tiết — có ngày giông bão, có ngày nắng ấm. Nỗi buồn này chỉ là một đám mây ghé qua, không phải là toàn bộ bầu trời của bạn.';
          case 'happy':
          case 'calm':
          case 'grateful':
            return 'Ghi nhớ khoảnh khắc này như một mỏ neo bình an để khi sóng gió ghé thăm, bạn luôn biết cách tìm đường quay về.';
          default:
            return 'Đặt sự việc vào bức tranh lớn của cuộc đời, mọi cảm xúc đều đến rồi sẽ đi như những đợt sóng biển.';
        }
    }
  }
}
