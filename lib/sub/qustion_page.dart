import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../detail/detail_page.dart';

class QuestionPage extends StatefulWidget {
  final Map<String, dynamic> question; // Firebase에서 받은 1개 테스트

  const QuestionPage({super.key, required this.question});

  @override
  State<StatefulWidget> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  int? _selectedIndex;
  late final String _title;
  late final String _questionText;
  late final List<dynamic> _selects;
  late final List<dynamic> _answers;

  final FirebaseDatabase _database = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _title = widget.question['title']?.toString() ?? '심리테스트';
    _questionText = widget.question['question']?.toString() ?? '';
    _selects = (widget.question['selects'] as List<dynamic>? ?? []);
    _answers = (widget.question['answer'] as List<dynamic>? ?? []);
  }

  Future<void> _onSubmit() async {
    if (_selectedIndex == null) return;
    final int index = _selectedIndex!;
    if (index < 0 || index >= _answers.length) return;

    final String resultText = _answers[index].toString();
    final String selectedText = _selects[index].toString();

    // 결과 Firebase Realtime Database에 저장 (/results)
    final ref = _database.ref('results').push();
    await ref.set({
      'title': _title,
      'question': _questionText,
      'selectedIndex': index,
      'selectedText': selectedText,
      'resultText': resultText,
      'createdAt': ServerValue.timestamp,
    });

    // Analytics 로그
    await FirebaseAnalytics.instance.logEvent(
      name: 'test_result',
      parameters: {
        'test_name': _title,
        'select_index': index,
        'select_text': selectedText,
      },
    );

    // 결과 페이지로 이동
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DetailPage(
          question: _questionText,
          answer: resultText,
          title: _title,
          selectedText: selectedText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _questionText,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _selects.length,
                itemBuilder: (context, index) {
                  final text = _selects[index].toString();
                  return Card(
                    margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: RadioListTile<int>(
                      title: Text(text),
                      value: index,
                      groupValue: _selectedIndex,
                      onChanged: (int? value) {
                        setState(() {
                          _selectedIndex = value;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton(
                onPressed: _selectedIndex == null ? null : _onSubmit,
                child: const Text('결과 보기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
