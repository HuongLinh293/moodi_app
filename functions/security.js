const {HttpsError} = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const emotions = new Set(['calm', 'happy', 'stressed', 'sad', 'anxious', 'angry', 'tired', 'ashamed', 'grateful', 'numb']);

function authorizeReflection(request) {
  if (!request.auth?.uid) {
    logger.info('security.reflection', {outcome: 'denied', reason: 'unauthenticated'});
    throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập để tiếp tục.');
  }
  const data = request.data;
  const fields = ['emotionKey', 'intensity', 'situation', 'thought'];
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      Object.keys(data).some(key => !fields.includes(key))) {
    throw new HttpsError('invalid-argument', 'Dữ liệu yêu cầu không hợp lệ.');
  }
  const {emotionKey, intensity = 3, situation = '', thought = ''} = data;
  if (!emotions.has(emotionKey) || !Number.isInteger(intensity) || intensity < 1 || intensity > 5 ||
      typeof situation !== 'string' || situation.length > 4000 ||
      typeof thought !== 'string' || thought.length > 4000) {
    throw new HttpsError('invalid-argument', 'Kiểm tra cảm xúc, mức độ và giới hạn 4.000 ký tự.');
  }
  // This endpoint processes caller-supplied text only; it accepts no document
  // path, owner UID or role and never retrieves another user's journal.
  return {emotionKey, intensity, situation, thought};
}
module.exports = {authorizeReflection};
