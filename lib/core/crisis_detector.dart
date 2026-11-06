/// Phát hiện tín hiệu khủng hoảng trong văn bản người dùng viết.
///
/// Giữ khớp với `hasCrisisSignal` ở backend (reflections/cbt-templates.ts).
/// Giới hạn đã biết: Dart không có chuẩn hóa NFC, nên các cụm chỉ có trong
/// danh sách có dấu (vd. "tự tử") viết ở dạng tổ hợp rời sẽ không được nhận
/// ra; bàn phím iOS/Android luôn nhập dạng dựng sẵn nên hiếm gặp.
library;

const crisisKeywords = [
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

/// Bản gõ không dấu. Cố ý bỏ "tu tu" (= "từ từ") và "tu van" (= "tư vấn").
const crisisKeywordsUnaccented = [
  'tu sat',
  'muon chet',
  'khong muon song',
  'khong con muon song',
  'ket lieu',
  'tu hai',
  'tu lam dau',
  'ton thuong ban than',
  'cat tay',
  'cat co tay',
  'uong thuoc qua lieu',
  'chet di cho ranh',
];

const _accents = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

/// Bảng tra ký tự có dấu (dạng dựng sẵn) → chữ gốc, mỗi ký tự tra một lần.
final Map<int, String> _baseOf = {
  for (final entry in _accents.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

String _stripVietnamese(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    // Dấu tổ hợp rời (văn bản dạng NFD, ví dụ dán từ macOS): bỏ đi, giống
    // normalize('NFD') + xóa dấu ở backend.
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    buffer.write(_baseOf[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

bool hasCrisisSignal(String text) {
  final lower = text.toLowerCase();
  if (crisisKeywords.any(lower.contains)) return true;
  final plain =
      ' ${_stripVietnamese(lower).replaceAll(RegExp(r'[^a-z0-9]+'), ' ')} ';
  return crisisKeywordsUnaccented.any((k) => plain.contains(' $k '));
}
