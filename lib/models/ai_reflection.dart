class AIReflection {
  final List<String> possibleEmotions;
  final String possibleTrigger;
  final String intensifyingThought;
  final String reflectionQuestion;
  final String balancedThought;
  final String recommendedExercise;
  final String recommendationReason;
  final String microGoalPrompt;
  final bool safetyFlag;
  final String? safetyReason;
  final String? userFeedback;
  final bool recommendationsDismissed;

  const AIReflection({
    required this.possibleEmotions,
    required this.possibleTrigger,
    required this.intensifyingThought,
    required this.reflectionQuestion,
    required this.balancedThought,
    required this.recommendedExercise,
    required this.recommendationReason,
    required this.microGoalPrompt,
    this.safetyFlag = false,
    this.safetyReason,
    this.userFeedback,
    this.recommendationsDismissed = false,
  });

  AIReflection copyWith({
    List<String>? possibleEmotions,
    String? possibleTrigger,
    String? intensifyingThought,
    String? balancedThought,
    String? reflectionQuestion,
    String? recommendedExercise,
    String? recommendationReason,
    String? microGoalPrompt,
    bool? safetyFlag,
    String? safetyReason,
    String? userFeedback,
    bool? recommendationsDismissed,
  }) {
    return AIReflection(
      possibleEmotions: possibleEmotions ?? this.possibleEmotions,
      possibleTrigger: possibleTrigger ?? this.possibleTrigger,
      intensifyingThought: intensifyingThought ?? this.intensifyingThought,
      balancedThought: balancedThought ?? this.balancedThought,
      reflectionQuestion: reflectionQuestion ?? this.reflectionQuestion,
      recommendedExercise: recommendedExercise ?? this.recommendedExercise,
      recommendationReason: recommendationReason ?? this.recommendationReason,
      microGoalPrompt: microGoalPrompt ?? this.microGoalPrompt,
      safetyFlag: safetyFlag ?? this.safetyFlag,
      safetyReason: safetyReason ?? this.safetyReason,
      userFeedback: userFeedback ?? this.userFeedback,
      recommendationsDismissed:
          recommendationsDismissed ?? this.recommendationsDismissed,
    );
  }

  factory AIReflection.forEmotion({
    required String emotionKey,
    required int intensity,
    String? situation,
    String? thought,
  }) {
    // Check safety triggers (S21)
    final textToCheck = '${situation ?? ''} ${thought ?? ''}'.toLowerCase();
    final crisisKeywords = [
      'tự tử',
      'muốn chết',
      'tự hại',
      'tổn thương bản thân',
      'không muốn sống',
      'chết đi',
      'suicide',
      'self harm',
      'kill myself',
      'end my life',
    ];

    final isCrisis = crisisKeywords.any((k) => textToCheck.contains(k));
    if (isCrisis) {
      return const AIReflection(
        possibleEmotions: ['Nguy cấp', 'Cần hỗ trợ'],
        possibleTrigger: 'Khủng hoảng tâm lý',
        intensifyingThought: 'Mọi thứ quá sức chịu đựng với tôi.',
        reflectionQuestion: 'Bạn có thể cho phép một người đáng tin cậy hoặc chuyên gia hỗ trợ bạn lúc này không?',
        balancedThought: 'Cảm giác đau đớn này là có thật, nhưng bạn không phải trải qua nó một mình. Luôn có sự trợ giúp dành cho bạn.',
        recommendedExercise: 'grounding',
        recommendationReason: 'Hít thở và chạm vào mặt đất để cơ thể lấy lại cảm giác an toàn ngay bây giờ.',
        microGoalPrompt: 'Tôi sẽ dừng lại và gọi điện hoặc nhắn tin cho một người tôi tin tưởng.',
        safetyFlag: true,
        safetyReason: 'Phát hiện tín hiệu khủng hoảng hoặc tự tổn thương. Chuyển sang luồng an toàn.',
      );
    }

    switch (emotionKey) {
      case 'stressed':
        return AIReflection(
          possibleEmotions: ['Căng thẳng', 'Áp lực', 'Quá tải'],
          possibleTrigger: situation?.isNotEmpty == true ? 'Khối lượng việc hoặc áp lực kỳ vọng' : 'Áp lực dồn dập',
          intensifyingThought: thought?.isNotEmpty == true ? thought! : 'Tôi phải hoàn thành mọi thứ một cách hoàn hảo ngay lúc này.',
          reflectionQuestion: 'Điều tồi tệ nhất thực sự có thể xảy ra là gì, và bạn có thể giải quyết từng phần nhỏ ra sao?',
          balancedThought: 'Tôi không cần làm xong tất cả ngay hôm nay. Từng bước nhỏ và nghỉ ngơi hợp lý là cách tốt nhất.',
          recommendedExercise: 'grounding',
          recommendationReason: 'Kỹ thuật tiếp đất 5-4-3-2-1 giúp làm dịu hệ thần kinh đang bị kích hoạt quá mức.',
          microGoalPrompt: 'Khi cảm thấy choáng ngợp, tôi sẽ dừng lại 1 phút và hít thở sâu 3 nhịp trước khi tiếp tục.',
        );

      case 'anxious':
        return AIReflection(
          possibleEmotions: ['Lo lắng', 'Bồn chồn', 'Bất an'],
          possibleTrigger: situation?.isNotEmpty == true ? 'Sự bất định trong tương lai' : 'Tình huống chưa rõ kết quả',
          intensifyingThought: thought?.isNotEmpty == true ? thought! : 'Chắc chắn điều tồi tệ sẽ xảy ra và tôi sẽ không chịu nổi.',
          reflectionQuestion: 'Bạn đang lo lắng về điều có thật hay chỉ là một viễn cảnh do tâm trí tưởng tượng?',
          balancedThought: 'Lo lắng là một cảm xúc tự nhiên, nhưng lo lắng không phải là sự thật. Tôi có năng lực thích ứng với những gì xảy ra.',
          recommendedExercise: 'thought_reframing',
          recommendationReason: 'Tái đóng khung suy nghĩ giúp tách rời sự thật khỏi nỗi sợ tưởng tượng.',
          microGoalPrompt: 'Khi bắt đầu suy nghĩ tiêu cực, tôi sẽ viết ra 1 bằng chứng ngược lại.',
        );

      case 'angry':
        return AIReflection(
          possibleEmotions: ['Tức giận', 'Bực bội', 'Bất công'],
          possibleTrigger: situation?.isNotEmpty == true ? 'Ranh giới cá nhân bị xâm phạm' : 'Kỳ vọng không được đáp ứng',
          intensifyingThought: thought?.isNotEmpty == true ? thought! : 'Họ cố tình chống lại tôi / Điều này hoàn toàn không thể chấp nhận được!',
          reflectionQuestion: 'Cơn giận này đang cố gắng bảo vệ giá trị hoặc nhu cầu sâu xa nào của bạn?',
          balancedThought: 'Tôi có quyền cảm thấy tức giận, nhưng tôi có toàn quyền lựa chọn hành động để không làm tổn thương chính mình.',
          recommendedExercise: 'response_pause',
          recommendationReason: 'Tạm dừng phản ứng tạo khoảng trống quan trọng giữa cảm xúc bộc phát và lời nói/hành động.',
          microGoalPrompt: 'Trước khi trả lời tin nhắn hay nói điều gì khi giận, tôi sẽ đếm chậm từ 1 đến 10.',
        );

      case 'sad':
        return AIReflection(
          possibleEmotions: ['Buồn bã', 'Hụt hẫng', 'Mệt mỏi'],
          possibleTrigger: situation?.isNotEmpty == true ? 'Sự mất mát hoặc cảm giác bị từ chối' : 'Kỳ vọng không thành',
          intensifyingThought: thought?.isNotEmpty == true ? thought! : 'Tôi chẳng làm được điều gì nên hồn cả.',
          reflectionQuestion: 'Nếu một người bạn thân cũng đang ở vị trí này, bạn sẽ nói lời gì với họ?',
          balancedThought: 'Nỗi buồn là bằng chứng tôi quan tâm sâu sắc. Cảm giác này sẽ qua đi, và tôi xứng đáng được đối xử dịu dàng.',
          recommendedExercise: 'self_compassion',
          recommendationReason: 'Thực hành tự trắc ẩn nhắc nhở bạn rằng đau khổ là một phần trải nghiệm chung của con người.',
          microGoalPrompt: 'Hôm nay tôi sẽ cho phép mình nghỉ ngơi 15 phút mà không phán xét bản thân.',
        );

      case 'happy':
      case 'calm':
      case 'grateful':
        return AIReflection(
          possibleEmotions: ['Thanh thản', 'Bình an', 'Biết ơn'],
          possibleTrigger: situation?.isNotEmpty == true ? 'Khoảnh khắc kết nối và hiện diện' : 'Một ngày thuận lợi',
          intensifyingThought: 'Tôi đang trân trọng khoảnh khắc hiện tại.',
          reflectionQuestion: 'Yếu tố nào trong ngày hôm nay đã giúp bạn cảm nhận được sự bình yên này?',
          balancedThought: 'Tôi ghi nhận và lưu giữ cảm xúc ấm áp này để nuôi dưỡng tâm trí khi gặp khó khăn.',
          recommendedExercise: 'self_compassion',
          recommendationReason: 'Ghi nhận và bồi đắp trạng thái hài lòng với bản thân và thế giới xung quanh.',
          microGoalPrompt: 'Tôi sẽ dành 30 giây để nói lời cảm ơn đến một người đã giúp tôi hôm nay.',
        );

      default:
        return AIReflection(
          possibleEmotions: ['Phức tạp', 'Lẫn lộn'],
          possibleTrigger: 'Nhiều yếu tố đan xen',
          intensifyingThought: thought?.isNotEmpty == true ? thought! : 'Tôi cảm thấy khó giải thích cảm giác này.',
          reflectionQuestion: 'Cảm xúc này đang muốn truyền tải thông điệp gì đến bạn?',
          balancedThought: 'Không nhất thiết phải gọi tên chính xác mọi thứ ngay lập tức. Cứ để cảm xúc hiện diện tự nhiên.',
          recommendedExercise: 'grounding',
          recommendationReason: 'Quay về với hơi thở và cơ thể để cảm thấy an toàn và vững vàng hơn.',
          microGoalPrompt: 'Tôi sẽ uống một ly nước ấm và hít thở nhẹ nhàng.',
        );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'possibleEmotions': possibleEmotions,
      'possibleTrigger': possibleTrigger,
      'intensifyingThought': intensifyingThought,
      'reflectionQuestion': reflectionQuestion,
      'balancedThought': balancedThought,
      'recommendedExercise': recommendedExercise,
      'recommendationReason': recommendationReason,
      'microGoalPrompt': microGoalPrompt,
      'safetyFlag': safetyFlag,
      'safetyReason': safetyReason,
      'userFeedback': userFeedback,
      'recommendationsDismissed': recommendationsDismissed,
    };
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory AIReflection.fromFirestore(Map<String, dynamic> data) {
    return AIReflection(
      possibleEmotions: (data['possibleEmotions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      possibleTrigger: data['possibleTrigger'] as String? ?? '',
      intensifyingThought: data['intensifyingThought'] as String? ?? '',
      reflectionQuestion: data['reflectionQuestion'] as String? ?? '',
      balancedThought: data['balancedThought'] as String? ?? '',
      recommendedExercise: data['recommendedExercise'] as String? ?? 'grounding',
      recommendationReason: data['recommendationReason'] as String? ?? '',
      microGoalPrompt: data['microGoalPrompt'] as String? ?? '',
      safetyFlag: data['safetyFlag'] as bool? ?? false,
      safetyReason: data['safetyReason'] as String?,
      userFeedback: data['userFeedback'] as String?,
      recommendationsDismissed:
          data['recommendationsDismissed'] as bool? ?? false,
    );
  }

  factory AIReflection.fromJson(Map<String, dynamic> json) {
    return AIReflection.fromFirestore(json);
  }
}

