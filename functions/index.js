const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const { authorizeReflection } = require("./security");
const { GoogleGenAI } = require("@google/genai");

setGlobalOptions({
  maxInstances: 10,
  region: "asia-southeast1", // Optimal for Vietnam/SEA
});

// Crisis keywords for safety check
const CRISIS_KEYWORDS = [
  "tự tử",
  "muốn chết",
  "tự hại",
  "tổn thương bản thân",
  "không muốn sống",
  "chết đi",
  "suicide",
  "self harm",
  "kill myself",
  "end my life",
];

// Fallback CBT reflection templates by emotionKey
const CBT_TEMPLATES = {
  stressed: {
    possibleEmotions: ["Căng thẳng", "Quá tải", "Lo âu"],
    possibleTrigger: "Khối lượng công việc hoặc áp lực kỳ vọng",
    intensifyingThought: "Tôi phải hoàn thành tất cả mọi thứ ngay bây giờ.",
    reflectionQuestion: "Điều tồi tệ nhất thực sự có thể xảy ra là gì, và bạn có thể xử lý nó như thế nào?",
    balancedThought: "Mình chỉ có thể làm từng việc một. Hoàn thành tốt hơn hoàn hảo.",
    recommendedExercise: "box_breathing",
    recommendationReason: "Kỹ thuật thở hộp 4-4-4-4 giúp hạ nhịp tim và đưa hệ thần kinh trở về trạng thái bình tĩnh.",
    microGoalPrompt: "Tôi sẽ chọn 1 nhiệm vụ nhỏ nhất và làm trong 15 phút, sau đó nghỉ ngơi.",
  },
  sad: {
    possibleEmotions: ["Buồn bã", "Hụt hẫng", "Cô đơn"],
    possibleTrigger: "Sự mất mát, thất vọng hoặc cảm giác bị bỏ rơi",
    intensifyingThought: "Cảm giác này sẽ kéo dài mãi mãi và không ai hiểu mình.",
    reflectionQuestion: "Nếu một người bạn thân đang cảm thấy như bạn lúc này, bạn sẽ nói gì với họ?",
    balancedThought: "Nỗi buồn là một phần tự nhiên của cuộc sống. Mình cho phép bản thân được cảm nhận và nghỉ ngơi.",
    recommendedExercise: "self_compassion",
    recommendationReason: "Bài tập lòng trắc ẩn giúp bạn bao dung với bản thân thay vì tự trách móc.",
    microGoalPrompt: "Tôi sẽ uống một ly nước ấm hoặc nghe một bản nhạc nhẹ nhàng yêu thích.",
  },
  anxious: {
    possibleEmotions: ["Bồn chồn", "Bất an", "Lo sợ"],
    possibleTrigger: "Sự không chắc chắn về tương lai",
    intensifyingThought: "Chắc chắn điều tồi tệ nhất sẽ xảy ra.",
    reflectionQuestion: "Những bằng chứng thực tế nào cho thấy dự đoán tiêu cực này chưa chắc đã xảy ra?",
    balancedThought: "Lo lắng không ngăn được điều xấu xảy ra, nó chỉ lấy đi sự bình yên của ngày hôm nay.",
    recommendedExercise: "grounding",
    recommendationReason: "Kỹ thuật neo đậu 5-4-3-2-1 giúp kéo tâm trí trở về khoảnh khắc hiện tại.",
    microGoalPrompt: "Tôi sẽ ghi lại 3 điều tôi có thể kiểm soát được ngay lúc này.",
  },
  angry: {
    possibleEmotions: ["Tức giận", "Bực bội", "Bất công"],
    possibleTrigger: "Ranh giới cá nhân bị xâm phạm hoặc kế hoạch bị phá vỡ",
    intensifyingThought: "Họ không có quyền đối xử với tôi như vậy!",
    reflectionQuestion: "Điều gì đang thực sự ẩn chứa bên dưới cơn tức giận này (sự tổn thương, thất vọng hay lo sợ)?",
    balancedThought: "Mình có quyền tức giận, nhưng mình chọn cách phản ứng bình tĩnh để bảo vệ chính mình.",
    recommendedExercise: "muscle_relaxation",
    recommendationReason: "Thả lỏng cơ bắp từng phần giúp giải phóng năng lượng căng cứng do tức giận.",
    microGoalPrompt: "Tôi sẽ bước ra ngoài hít thở không khí trong lành 5 phút trước khi phản hồi.",
  },
  calm: {
    possibleEmotions: ["Bình an", "Thư thái", "Nhẹ nhõm"],
    possibleTrigger: "Khoảnh khắc tĩnh lặng hoặc hoàn thành một việc quan trọng",
    intensifyingThought: "Cảm giác bình yên này liệu có kéo dài được lâu?",
    reflectionQuestion: "Điều gì trong ngày hôm nay đã giúp bạn cảm nhận được sự tĩnh lặng này?",
    balancedThought: "Trân trọng từng khoảnh khắc bình yên và lưu giữ nó như một nguồn năng lượng tích cực.",
    recommendedExercise: "mindful_walking",
    recommendationReason: "Duy trì sự hiện diện trọn vẹn để nuôi dưỡng trạng thái bình an nội tâm.",
    microGoalPrompt: "Tôi sẽ lưu lại khoảnh khắc bình yên này bằng một nụ cười nhẹ nhàng.",
  },
  happy: {
    possibleEmotions: ["Vui vẻ", "Hân hoan", "Biết ơn"],
    possibleTrigger: "Một tin tốt, thành tựu hoặc sự kết nối ý nghĩa",
    intensifyingThought: "Mình cần tận hưởng tối đa trước khi nó biến mất.",
    reflectionQuestion: "Bạn có thể chia sẻ niềm vui này hoặc ghi nhận nỗ lực của chính mình như thế nào?",
    balancedThought: "Mình xứng đáng với niềm vui này và biết ơn vì những điều tốt đẹp xung quanh.",
    recommendedExercise: "gratitude_journaling",
    recommendationReason: "Viết ra những điều biết ơn giúp khắc sâu cảm xúc tích cực trong não bộ.",
    microGoalPrompt: "Tôi sẽ gửi lời cảm ơn đến một người đã giúp đỡ tôi gần đây.",
  },
};

/**
 * Cloud Function: generateReflection
 * Callable endpoint invoked from Mindra Flutter app
 */
exports.generateReflection = onCall(async (request) => {
  const { emotionKey, intensity, situation, thought } = authorizeReflection(request);

  // Safety trigger check
  const fullText = `${situation} ${thought}`.toLowerCase();
  const isCrisis = CRISIS_KEYWORDS.some((kw) => fullText.includes(kw));

  if (isCrisis) {
    return {
      possibleEmotions: ["Nguy cấp", "Cần hỗ trợ"],
      possibleTrigger: "Khủng hoảng tâm lý",
      intensifyingThought: "Mọi thứ quá sức chịu đựng với tôi.",
      reflectionQuestion: "Bạn có thể cho phép một người đáng tin cậy hoặc chuyên gia hỗ trợ bạn lúc này không?",
      balancedThought: "Cảm giác đau đớn này là có thật, nhưng bạn không phải trải qua nó một mình. Luôn có sự trợ giúp dành cho bạn.",
      recommendedExercise: "grounding",
      recommendationReason: "Hít thở và chạm vào mặt đất để cơ thể lấy lại cảm giác an toàn ngay bây giờ.",
      microGoalPrompt: "Tôi sẽ dừng lại và gọi điện hoặc nhắn tin cho một người tôi tin tưởng.",
      safetyFlag: true,
      safetyReason: "Phát hiện tín hiệu khủng hoảng hoặc tự tổn thương. Chuyển sang luồng an toàn.",
      recommendationsDismissed: false,
    };
  }

  // Attempt Gemini API call if key is available
  const apiKey = process.env.FUNCTIONS_EMULATOR === 'true'
    ? null // Emulator demos must never send text to an external provider.
    : process.env.GEMINI_API_KEY || process.env.GOOGLE_GENAI_API_KEY;

  if (apiKey) {
    try {
      const ai = new GoogleGenAI({ apiKey });
      const prompt = `
Bạn là chuyên gia tâm lý học lâm sàng theo liệu pháp Nhận thức Hành vi (CBT) cho ứng dụng Mindra.
Hãy phân tích cảm xúc của người dùng và đưa ra góc nhìn phản tư (Cognitive Reframing) nhẹ nhàng, trắc ẩn, không phán xét, bằng tiếng Việt.
Độ tuổi người dùng: thanh niên / người đi làm. Tông giọng: ấm áp, khoa học, trắc ẩn, không hoa mỹ rườm rà.

Thông tin người dùng nhập:
- Cảm xúc chính: ${emotionKey}
- Mức độ (1-5): ${intensity}
- Hoàn cảnh/Tình huống: ${situation || "Không ghi cụ thể"}
- Suy nghĩ tự động: ${thought || "Không ghi cụ thể"}

Yêu cầu trả về đúng định dạng JSON thuần túy (không bọc trong markdown code block nếu có thể) với các trường sau:
{
  "possibleEmotions": ["tối đa 3 cảm xúc phụ liên quan"],
  "possibleTrigger": "Nguyên nhân kích hoạt có thể có (ngắn gọn 1 câu)",
  "intensifyingThought": "Suy nghĩ tự động đang làm cảm xúc tăng nặng (1 câu)",
  "reflectionQuestion": "Một câu hỏi gợi mở CBT để nhìn nhận lại sự việc",
  "balancedThought": "Suy nghĩ cân bằng và thực tế hơn (Cognitive Reframe - 1-2 câu)",
  "recommendedExercise": "chọn một trong: 'grounding' | 'box_breathing' | 'cognitive_reframing' | 'self_compassion' | 'muscle_relaxation'",
  "recommendationReason": "Lý do bài tập này phù hợp với trạng thái hiện tại (1 câu)",
  "microGoalPrompt": "Một hành động vi mô (Micro-goal) người dùng có thể làm ngay trong 5 phút"
}
`;

      const response = await ai.models.generateContent({
        model: "gemini-2.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          temperature: 0.7,
        },
      });

      const text = response.text;
      if (text) {
        const cleaned = text.replace(/```json/g, "").replace(/```/g, "").trim();
        const parsed = JSON.parse(cleaned);

        return {
          possibleEmotions: Array.isArray(parsed.possibleEmotions) ? parsed.possibleEmotions : ["Căng thẳng"],
          possibleTrigger: parsed.possibleTrigger || "Tình huống chưa rõ ràng",
          intensifyingThought: parsed.intensifyingThought || thought || "Suy nghĩ tự động",
          reflectionQuestion: parsed.reflectionQuestion || "Điều gì đang thực sự diễn ra?",
          balancedThought: parsed.balancedThought || "Mọi chuyện rồi sẽ ổn định trở lại.",
          recommendedExercise: parsed.recommendedExercise || "box_breathing",
          recommendationReason: parsed.recommendationReason || "Giúp điều hòa hơi thở và giảm căng thẳng.",
          microGoalPrompt: parsed.microGoalPrompt || "Dành 2 phút thở sâu và uống một ngụm nước.",
          safetyFlag: false,
          safetyReason: null,
          recommendationsDismissed: false,
        };
      }
    } catch (_) {
      logger.warn("reflection.provider_unavailable");
    }
  }

  // Graceful deterministic fallback
  const fallback = CBT_TEMPLATES[emotionKey] || CBT_TEMPLATES.stressed;
  return {
    possibleEmotions: fallback.possibleEmotions,
    possibleTrigger: situation && situation.trim().length > 0 ? situation : fallback.possibleTrigger,
    intensifyingThought: thought && thought.trim().length > 0 ? thought : fallback.intensifyingThought,
    reflectionQuestion: fallback.reflectionQuestion,
    balancedThought: fallback.balancedThought,
    recommendedExercise: fallback.recommendedExercise,
    recommendationReason: fallback.recommendationReason,
    microGoalPrompt: fallback.microGoalPrompt,
    safetyFlag: false,
    safetyReason: null,
    recommendationsDismissed: false,
  };
});

// Community gateway: direct Firestore/Storage client access stays denied.
exports.community = onCall({memory: '512MiB', timeoutSeconds: 60}, async request => {
  const {getApps, initializeApp} = require('firebase-admin/app');
  if (!getApps().length) initializeApp();
  const {getFirestore} = require('firebase-admin/firestore');
  const {getStorage} = require('firebase-admin/storage');
  const {createCommunityService} = require('./community');
  return createCommunityService(getFirestore(), getStorage().bucket()).handle(request);
});
