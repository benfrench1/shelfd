import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/literary_quiz_questions.dart';
import '../models/literary_quiz_question.dart';

class LiteraryQuizService {
  static const _completedDateKey = 'literary_quiz_completed_date';
  static const _questionsPerQuiz = 5;

  static String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  static String _completedDateKeyForUid(String uid) =>
      '${_completedDateKey}_$uid';

  static List<LiteraryQuizQuestion> getQuizForToday() {
    final batchIndex = _batchIndexForToday();
    final start = batchIndex * _questionsPerQuiz;
    return literaryQuizQuestions.sublist(start, start + _questionsPerQuiz);
  }

  static Future<bool> isQuizCompletedToday() async {
    final uid = _currentUid();
    if (uid == null) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_completedDateKeyForUid(uid)) == _todayKey();
  }

  static Future<void> markQuizCompletedToday() async {
    final uid = _currentUid();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_completedDateKeyForUid(uid), _todayKey());
  }

  static int _batchIndexForToday() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year);
    final dayOfYear = now.difference(startOfYear).inDays;
    return dayOfYear % (literaryQuizQuestions.length ~/ _questionsPerQuiz);
  }

  static String _todayKey() {
    return DateTime.now().toIso8601String().substring(0, 10);
  }
}