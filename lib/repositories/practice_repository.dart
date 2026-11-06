import '../core/http_client.dart';
import '../models/practice_record.dart';

class PracticeRepository {
  PracticeRepository({HttpClient? client}) : _client = client ?? HttpClient();
  final HttpClient _client;
  Future<void> save(PracticeRecord record) async {
    await _client.put('/practice/${record.id}', body: record.toJson());
  }

  Future<List<PracticeRecord>> fetch() async {
    final data = await _client.get('/practice');
    return (data as List)
        .whereType<Map>()
        .map((r) => PracticeRecord.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
}
