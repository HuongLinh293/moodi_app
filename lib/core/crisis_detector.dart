/// Phát hiện tín hiệu khủng hoảng trong văn bản người dùng viết.
///
/// Giữ khớp với `hasCrisisSignal` ở backend (reflections/cbt-templates.ts).
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

String _stripVietnamese(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final base = _accents.entries
        .where((e) => e.value.contains(char))
        .map((e) => e.key)
        .firstOrNull;
    buffer.write(base ?? char);
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
