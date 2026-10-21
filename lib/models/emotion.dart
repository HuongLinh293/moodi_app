import 'package:flutter/material.dart';

import '../core/theme/colors.dart';

enum EmotionCategory {
  calm('Bình yên', AppColors.mint),
  positive('Tích cực', AppColors.yellow),
  low('Trầm lắng', AppColors.blue),
  stress('Căng thẳng', AppColors.purple),
  high('Cường độ cao', AppColors.orange);

  final String label;
  final Color color;
  const EmotionCategory(this.label, this.color);
}

class EmotionInfo {
  final String key;
  final String vi;
  final String face;
  final EmotionCategory category;
  final Color tone;
  final String promptTitle;
  final String promptSubtitle;
  final String defaultThought;
  final String reflectionQuestion;
  final String balancedThought;

  const EmotionInfo({
    required this.key,
    required this.vi,
    required this.face,
    required this.category,
    required this.tone,
    required this.promptTitle,
    required this.promptSubtitle,
    required this.defaultThought,
    required this.reflectionQuestion,
    required this.balancedThought,
  });
}

class MindraEmotions {
  static const Map<String, EmotionInfo> all = {
    'calm': EmotionInfo(
      key: 'calm',
      vi: 'Bình yên',
      face: 'calm',
      category: EmotionCategory.calm,
      tone: AppColors.mint,
      promptTitle: 'Bình yên.',
      promptSubtitle: 'Có vẻ bạn đang có một khoảng thở.',
      defaultThought: 'Mình đang ổn và muốn ghi nhận điều đó.',
      reflectionQuestion: 'Điều gì giúp bạn thấy như vậy?',
      balancedThought: 'Mình có thể nhớ lại khoảnh khắc này.',
    ),
    'happy': EmotionInfo(
      key: 'happy',
      vi: 'Vui',
      face: 'happy',
      category: EmotionCategory.positive,
      tone: AppColors.yellow,
      promptTitle: 'Có điều gì làm bạn vui?',
      promptSubtitle: 'Giữ lại một chút ánh sáng của hôm nay.',
      defaultThought: 'Khoảnh khắc này thật đáng trân trọng.',
      reflectionQuestion: 'Điều gì góp phần tạo nên khoảnh khắc này?',
      balancedThought: 'Mình có thể giữ cảm giác này làm điểm tựa.',
    ),
    'stressed': EmotionInfo(
      key: 'stressed',
      vi: 'Căng thẳng',
      face: 'stressed',
      category: EmotionCategory.stress,
      tone: AppColors.orange,
      promptTitle: 'Đang hơi quá tải?',
      promptSubtitle: 'Mình có thể bắt đầu bằng một bước rất nhỏ.',
      defaultThought: 'Mình phải làm tốt mọi thứ ngay lập tức.',
      reflectionQuestion: 'Bạn sẽ nói gì với một người bạn ở hoàn cảnh này?',
      balancedThought: 'Đây chỉ là một khoảnh khắc, không phải toàn bộ mình.',
    ),
    'sad': EmotionInfo(
      key: 'sad',
      vi: 'Buồn',
      face: 'sad',
      category: EmotionCategory.low,
      tone: AppColors.blue,
      promptTitle: 'Một ngày hơi nặng?',
      promptSubtitle: 'Bạn không cần phải đi qua nó một mình.',
      defaultThought: 'Mọi chuyện sẽ không khá hơn.',
      reflectionQuestion: 'Lúc này bạn cần điều gì nhất?',
      balancedThought: 'Cảm giác này thật, và sẽ thay đổi.',
    ),
    'anxious': EmotionInfo(
      key: 'anxious',
      vi: 'Lo lắng',
      face: 'anxious',
      category: EmotionCategory.stress,
      tone: AppColors.pink,
      promptTitle: 'Có điều gì đang làm bạn lo?',
      promptSubtitle: 'Mình cùng gọi tên nó thật chậm.',
      defaultThought: 'Có điều gì đó sẽ đi sai.',
      reflectionQuestion: 'Điều gì đang thật sự xảy ra lúc này?',
      balancedThought: 'Mình có thể lo và vẫn làm từng bước.',
    ),
    'angry': EmotionInfo(
      key: 'angry',
      vi: 'Tức giận',
      face: 'angry',
      category: EmotionCategory.high,
      tone: AppColors.orange,
      promptTitle: 'Có điều gì đang làm bạn tức?',
      promptSubtitle: 'Mình cùng hạ nhiệt trước khi chọn bước tiếp theo.',
      defaultThought: 'Họ không tôn trọng mình.',
      reflectionQuestion: 'Điều gì quan trọng với bạn ở đây?',
      balancedThought: 'Mình có thể giận và vẫn chọn cách đáp lại.',
    ),
    'tired': EmotionInfo(
      key: 'tired',
      vi: 'Mệt mỏi',
      face: 'tired',
      category: EmotionCategory.low,
      tone: AppColors.gray,
      promptTitle: 'Bạn đang cần nghỉ?',
      promptSubtitle: 'Cơ thể cũng đang cố gắng cùng bạn.',
      defaultThought: 'Mình không còn đủ sức để tiếp tục.',
      reflectionQuestion: 'Điều nhỏ nào giúp bạn nghỉ ngơi?',
      balancedThought: 'Nghỉ ngơi cũng là một cách tiếp tục.',
    ),
    'ashamed': EmotionInfo(
      key: 'ashamed',
      vi: 'Xấu hổ',
      face: 'ashamed',
      category: EmotionCategory.low,
      tone: AppColors.softYellow,
      promptTitle: 'Có điều gì khiến bạn ngại?',
      promptSubtitle: 'Mình có thể nhìn lại mà không phán xét.',
      defaultThought: 'Mình chưa đủ tốt.',
      reflectionQuestion: 'Có điều gì cho thấy bức tranh khác không?',
      balancedThought: 'Một sai sót không định nghĩa mình.',
    ),
    'grateful': EmotionInfo(
      key: 'grateful',
      vi: 'Biết ơn',
      face: 'happy',
      category: EmotionCategory.positive,
      tone: AppColors.yellow,
      promptTitle: 'Điều gì đáng được giữ lại?',
      promptSubtitle: 'Một điều nhỏ cũng có thể làm ngày dịu hơn.',
      defaultThought: 'Có những điều bình dị thật quý giá.',
      reflectionQuestion: 'Ai hoặc điều gì đã mang lại sự ấm áp?',
      balancedThought: 'Biết ơn giúp tâm trí tìm về sự an bình.',
    ),
    'numb': EmotionInfo(
      key: 'numb',
      vi: 'Trống rỗng',
      face: 'tired',
      category: EmotionCategory.low,
      tone: AppColors.lavender,
      promptTitle: 'Mọi thứ đang hơi trống rỗng?',
      promptSubtitle: 'Mình bắt đầu bằng một tín hiệu nhỏ từ cơ thể nhé.',
      defaultThought: 'Mình không cảm thấy gì rõ ràng cả.',
      reflectionQuestion: 'Cơ thể bạn lúc này đang cảm thấy thế nào?',
      balancedThought: 'Trống rỗng cũng là một tín hiệu cần sự lắng nghe.',
    ),
  };

  static const List<String> primaryKeys = [
    'calm',
    'happy',
    'stressed',
    'sad',
    'anxious',
    'angry',
    'tired',
    'ashamed',
    'grateful',
    'numb',
  ];

  static EmotionInfo get(String? key) => all[key] ?? all['calm']!;
}
