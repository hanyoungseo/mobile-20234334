import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sub/question_page.dart';
import '../history/history_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseDatabase database = FirebaseDatabase.instance;
  late DatabaseReference _testRef;

  // Remote Config 값
  String welcomeTitle = '오늘의 심리테스트';
  bool bannerUse = true;
  int itemHeight = 70;

  // DB 테스트 목록
  final List<Map<String, dynamic>> _tests = [];
  final List<Map<String, dynamic>> _filteredTests = [];

  // 검색
  final TextEditingController _searchController = TextEditingController();

  // 즐겨찾기 (title 기준)
  Set<String> _favoriteTitles = {};

  // AdMob
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _testRef = database.ref('test');
    _initRemoteConfig();
    _loadFavorites();
    _loadTests();
    _initBannerAd();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRemoteConfig() async {
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 10),
      ));

      await remoteConfig.fetchAndActivate();

      setState(() {
        welcomeTitle = remoteConfig.getString('welcome').isNotEmpty
            ? remoteConfig.getString('welcome')
            : '오늘의 심리테스트';
        bannerUse = remoteConfig.getBool('banner');
        final int h = remoteConfig.getInt('item_height');
        if (h > 0) itemHeight = h;
      });
    } catch (_) {
      // RemoteConfig 실패해도 기본값으로 진행
    }
  }

  Future<void> _loadTests() async {
    try {
      final snapshot = await _testRef.get();

      _tests.clear();

      for (final child in snapshot.children) {
        final value = child.value;
        if (value is Map) {
          final Map<String, dynamic> item =
          jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
          // Firebase key도 같이 보관하고 싶으면:
          item['id'] = child.key;
          _tests.add(item);
        }
      }

      _tests.sort((a, b) {
        final at = (a['title'] ?? '').toString();
        final bt = (b['title'] ?? '').toString();
        return at.compareTo(bt);
      });

      _filteredTests
        ..clear()
        ..addAll(_tests);

      setState(() {});
    } catch (e) {
      debugPrint('Failed to load tests: $e');
    }
  }

  // 검색 필터
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredTests
          ..clear()
          ..addAll(_tests);
      } else {
        _filteredTests
          ..clear()
          ..addAll(_tests.where((test) {
            final title = (test['title'] ?? '').toString().toLowerCase();
            return title.contains(query);
          }));
      }
    });
  }

  // 즐겨찾기 로컬 저장/불러오기
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorite_titles') ?? [];
    setState(() {
      _favoriteTitles = list.toSet();
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteTitles.contains(title)) {
        _favoriteTitles.remove(title);
      } else {
        _favoriteTitles.add(title);
      }
    });
    await prefs.setStringList('favorite_titles', _favoriteTitles.toList());
  }

  // AdMob 배너 초기화
  void _initBannerAd() {
    final BannerAd banner = BannerAd(
      size: AdSize.banner,
      adUnitId:
      'ca-app-pub-3940256099942544/6300978111', // 테스트용 배너 ID (Android)
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerLoaded = true;
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
      request: const AdRequest(),
    );

    banner.load();
  }

  // 랜덤 테스트 선택
  void _openRandomTest() {
    if (_tests.isEmpty) return;
    final random = Random();
    final index = random.nextInt(_tests.length);
    final selected = _tests[index];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionPage(question: selected),
      ),
    );
  }

  // 테스트 카드 위젯
  Widget _buildTestCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final bool isFavorite = _favoriteTitles.contains(title);

    return InkWell(
      onTap: () async {
        await FirebaseAnalytics.instance.logEvent(
          name: 'test_click',
          parameters: {'test_name': title},
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuestionPage(question: item),
          ),
        );
      },
      child: SizedBox(
        height: itemHeight.toDouble(),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.pink : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(title),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 즐겨찾기 필터 on/off (심플하게 토글은 생략, 필요하면 버튼 추가)
  List<Map<String, dynamic>> get _displayList => _filteredTests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(welcomeTitle),
        actions: [
          IconButton(
            tooltip: '랜덤 테스트',
            onPressed: _openRandomTest,
            icon: const Icon(Icons.casino),
          ),
          IconButton(
            tooltip: '내 테스트 기록',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '테스트 제목 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _displayList.isEmpty
                ? const Center(child: Text('등록된 테스트가 없습니다.'))
                : ListView.builder(
              itemCount: _displayList.length,
              itemBuilder: (context, index) {
                final item = _displayList[index];
                return _buildTestCard(item);
              },
            ),
          ),
          if (bannerUse && _isBannerLoaded && _bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),

      // 테스트 데이터 샘플 추가 버튼 (개발용)
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // 샘플 3개 추가
          _testRef.push().set({
            "title": "당신이 좋아하는 애완동물은?",
            "question": "무인도에 도착했는데, 상자를 열었을 때 보이는 것은?",
            "selects": ["생존키트", "휴대폰", "텐트", "무인도에서 살아남기"],
            "answer": [
              "당신은 현실주의! 동물을 안 키우는 타입!",
              "늘 함께 있는 걸 좋아하는 강아지 타입",
              "같은 공간을 공유하는 고양이 타입",
              "낭만을 즐기는 앵무새 타입",
            ]
          });

          _testRef.push().set({
            "title": "5초 MBTI I/E 편",
            "question": "친구와 함께 간 미술관, 당신이라면?",
            "selects": ["말이 많아짐", "생각이 많아짐"],
            "answer": ["당신의 성향은 E", "당신의 성향은 I"]
          });

          _testRef.push().set({
            "title": "당신은 어떤 사랑을 하고 싶나요?",
            "question": "목욕할 때 가장 먼저 비누칠하는 곳은?",
            "selects": ["머리", "상체", "하체"],
            "answer": [
              "당신은 자만추 스타일",
              "당신은 소개팅파",
              "당신은 운명적 만남을 꿈꾸는 타입"
            ]
          });

          _loadTests();
        },
      ),
    );
  }
}
