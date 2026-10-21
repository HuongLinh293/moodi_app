// Port nguyên văn từ Cloud Function cũ để kết quả không đổi khi chuyển backend.
export interface CbtTemplate {
  possibleEmotions: string[];
  possibleTrigger: string;
  intensifyingThought: string;
  reflectionQuestion: string;
  balancedThought: string;
  recommendedExercise: string;
  recommendationReason: string;
  microGoalPrompt: string;
}

export const EMOTIONS = [
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

// Chỉ các mã bài tập mà app Flutter hiển thị được (ai_reflection_view.dart).
export const EXERCISES = ['grounding', 'thought_reframing', 'self_compassion', 'response_pause'];

// Mã cũ của Cloud Function/Gemini → mã app hiểu.
const EXERCISE_ALIASES: Record<string, string> = {
  box_breathing: 'response_pause',
  cognitive_reframing: 'thought_reframing',
  reframe: 'thought_reframing',
  muscle_relaxation: 'grounding',
  compassion: 'self_compassion',
  pause: 'response_pause',
};

export function normalizeExercise(value: unknown): string {
  const key = typeof value === 'string' ? value.trim() : '';
  const mapped = EXERCISE_ALIASES[key] ?? key;
  return EXERCISES.includes(mapped) ? mapped : 'grounding';
}

export const CRISIS_KEYWORDS = [
  'tự tử',
  'tự sát',
  'tự vẫn',
  'muốn chết',
  'không muốn sống',
  'không còn muốn sống',
  'kết liễu',
  'tự hại',
  'tự làm đau',
  'tổn thương bản thân',
  'cắt tay',
  'cắt cổ tay',
  'uống thuốc quá liều',
  'chết đi cho rảnh',
  'suicide',
  'self harm',
  'self-harm',
  'kill myself',
  'end my life',
  'end it all',
];

// Template CBT dự phòng theo emotionKey (port từ functions/index.js).
export const CBT_TEMPLATES: Record<string, CbtTemplate> = {
  stressed: {
    possibleEmotions: ['Căng thẳng', 'Quá tải', 'Lo âu'],
    possibleTrigger: 'Khối lượng công việc hoặc áp lực kỳ vọng',
    intensifyingThought: 'Tôi phải hoàn thành tất cả mọi thứ ngay bây giờ.',
    reflectionQuestion:
      'Điều tồi tệ nhất thực sự có thể xảy ra là gì, và bạn có thể xử lý nó như thế nào?',
    balancedThought: 'Mình chỉ có thể làm từng việc một. Hoàn thành tốt hơn hoàn hảo.',
    recommendedExercise: 'response_pause',
    recommendationReason:
      'Kỹ thuật thở hộp 4-4-4-4 giúp hạ nhịp tim và đưa hệ thần kinh trở về trạng thái bình tĩnh.',
    microGoalPrompt: 'Tôi sẽ chọn 1 nhiệm vụ nhỏ nhất và làm trong 15 phút, sau đó nghỉ ngơi.',
  },
  sad: {
    possibleEmotions: ['Buồn bã', 'Hụt hẫng', 'Cô đơn'],
    possibleTrigger: 'Sự mất mát, thất vọng hoặc cảm giác bị bỏ rơi',
    intensifyingThought: 'Cảm giác này sẽ kéo dài mãi mãi và không ai hiểu mình.',
    reflectionQuestion:
      'Nếu một người bạn thân đang cảm thấy như bạn lúc này, bạn sẽ nói gì với họ?',
    balancedThought:
      'Nỗi buồn là một phần tự nhiên của cuộc sống. Mình cho phép bản thân được cảm nhận và nghỉ ngơi.',
    recommendedExercise: 'self_compassion',
    recommendationReason:
      'Bài tập lòng trắc ẩn giúp bạn bao dung với bản thân thay vì tự trách móc.',
    microGoalPrompt: 'Tôi sẽ uống một ly nước ấm hoặc nghe một bản nhạc nhẹ nhàng yêu thích.',
  },
  anxious: {
    possibleEmotions: ['Bồn chồn', 'Bất an', 'Lo sợ'],
    possibleTrigger: 'Sự không chắc chắn về tương lai',
    intensifyingThought: 'Chắc chắn điều tồi tệ nhất sẽ xảy ra.',
    reflectionQuestion:
      'Những bằng chứng thực tế nào cho thấy dự đoán tiêu cực này chưa chắc đã xảy ra?',
    balancedThought:
      'Lo lắng không ngăn được điều xấu xảy ra, nó chỉ lấy đi sự bình yên của ngày hôm nay.',
    recommendedExercise: 'grounding',
    recommendationReason:
      'Kỹ thuật neo đậu 5-4-3-2-1 giúp kéo tâm trí trở về khoảnh khắc hiện tại.',
    microGoalPrompt: 'Tôi sẽ ghi lại 3 điều tôi có thể kiểm soát được ngay lúc này.',
  },
  angry: {
    possibleEmotions: ['Tức giận', 'Bực bội', 'Bất công'],
    possibleTrigger: 'Ranh giới cá nhân bị xâm phạm hoặc kế hoạch bị phá vỡ',
    intensifyingThought: 'Họ không có quyền đối xử với tôi như vậy!',
    reflectionQuestion:
      'Điều gì đang thực sự ẩn chứa bên dưới cơn tức giận này (sự tổn thương, thất vọng hay lo sợ)?',
    balancedThought:
      'Mình có quyền tức giận, nhưng mình chọn cách phản ứng bình tĩnh để bảo vệ chính mình.',
    recommendedExercise: 'muscle_relaxation',
    recommendationReason:
      'Thả lỏng cơ bắp từng phần giúp giải phóng năng lượng căng cứng do tức giận.',
    microGoalPrompt: 'Tôi sẽ bước ra ngoài hít thở không khí trong lành 5 phút trước khi phản hồi.',
  },
  calm: {
    possibleEmotions: ['Bình an', 'Thư thái', 'Nhẹ nhõm'],
    possibleTrigger: 'Khoảnh khắc tĩnh lặng hoặc hoàn thành một việc quan trọng',
    intensifyingThought: 'Cảm giác bình yên này liệu có kéo dài được lâu?',
    reflectionQuestion: 'Điều gì trong ngày hôm nay đã giúp bạn cảm nhận được sự tĩnh lặng này?',
    balancedThought:
      'Trân trọng từng khoảnh khắc bình yên và lưu giữ nó như một nguồn năng lượng tích cực.',
    recommendedExercise: 'mindful_walking',
    recommendationReason: 'Duy trì sự hiện diện trọn vẹn để nuôi dưỡng trạng thái bình an nội tâm.',
    microGoalPrompt: 'Tôi sẽ lưu lại khoảnh khắc bình yên này bằng một nụ cười nhẹ nhàng.',
  },
  happy: {
    possibleEmotions: ['Vui vẻ', 'Hân hoan', 'Biết ơn'],
    possibleTrigger: 'Một tin tốt, thành tựu hoặc sự kết nối ý nghĩa',
    intensifyingThought: 'Mình cần tận hưởng tối đa trước khi nó biến mất.',
    reflectionQuestion:
      'Bạn có thể chia sẻ niềm vui này hoặc ghi nhận nỗ lực của chính mình như thế nào?',
    balancedThought: 'Mình xứng đáng với niềm vui này và biết ơn vì những điều tốt đẹp xung quanh.',
    recommendedExercise: 'gratitude_journaling',
    recommendationReason: 'Viết ra những điều biết ơn giúp khắc sâu cảm xúc tích cực trong não bộ.',
    microGoalPrompt: 'Tôi sẽ gửi lời cảm ơn đến một người đã giúp đỡ tôi gần đây.',
  },
};
