import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final snapshot = await _database.ref('results').get();

      _results.clear();
      for (final child in snapshot.children) {
        final value = child.value;
        if (value is Map) {
          final map = Map<String, dynamic>.from(
              value.map((key, value) => MapEntry(key.toString(), value)));
          map['id'] = child.key;
          _results.add(map);
        }
      }

      _results.sort((a, b) {
        final at = (a['createdAt'] ?? 0) as int;
        final bt = (b['createdAt'] ?? 0) as int;
        return bt.compareTo(at); // 최신순
      });

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load results: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is int) {
      final dt =
      DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 테스트 기록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? const Center(child: Text('아직 저장된 결과가 없습니다.'))
          : ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final item = _results[index];
          final title = (item['title'] ?? '').toString();
          final resultText = (item['resultText'] ?? '').toString();
          final selectedText =
          (item['selectedText'] ?? '').toString();
          final createdAt = item['createdAt'];

          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedText.isNotEmpty)
                    Text('내 선택: $selectedText'),
                  const SizedBox(height: 4),
                  Text(
                    resultText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
