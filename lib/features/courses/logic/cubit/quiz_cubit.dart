import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:future_app/features/courses/data/models/quiz_models.dart';
import 'package:future_app/features/courses/data/repos/quiz_repo.dart';
import 'package:future_app/features/courses/logic/cubit/quiz_state.dart';
import 'package:future_app/core/helper/shared_pref_keys.dart';
import 'package:future_app/core/network/api_error_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._quizRepo) : super(const QuizState.initial());

  final QuizRepo _quizRepo;
  Timer? _timer;
  int _remainingSeconds = 0;
  StartQuizResponseModel? _quizData;
  String? _currentQuizId;

  // Getters
  int get remainingSeconds => _remainingSeconds;
  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  StartQuizResponseModel? get quizData => _quizData;
  String? get currentQuizId => _currentQuizId;

  // Helper method to safely emit states
  void _safeEmit(QuizState state) {
    if (!isClosed) {
      emit(state);
    }
  }

  // Check if quiz was already started
  Future<bool> isQuizStarted(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('quiz_started_$quizId') ?? false;
  }

  // Mark quiz as started
  Future<void> _markQuizAsStarted(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiz_started_$quizId', true);
  }

  // Mark quiz as completed (allows restart)
  Future<void> markQuizAsCompleted(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quiz_started_$quizId');
  }

  // Save completed exam/quiz ID locally (when user answers and submits)
  Future<void> saveCompletedQuizId(String quizId) async {
    try {
      final id = quizId.toString();
      final prefs = await SharedPreferences.getInstance();
      final List<String> ids =
          prefs.getStringList(SharedPrefKeys.completedQuizIds) ?? [];
      if (!ids.contains(id)) {
        ids.add(id);
        await prefs.setStringList(SharedPrefKeys.completedQuizIds, ids);
        log('✅ QuizCubit: Saved completed quiz ID: $id (total: ${ids.length})');
      }
    } catch (e) {
      log('❌ QuizCubit: Failed to save completed quiz ID: $e');
    }
  }

  // Check if user has answered this quiz before
  Future<bool> isQuizAnswered(String quizId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> ids =
        prefs.getStringList(SharedPrefKeys.completedQuizIds) ?? [];
    return ids.contains(quizId.toString());
  }

  // Get all completed quiz IDs
  Future<List<String>> getCompletedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(SharedPrefKeys.completedQuizIds) ?? [];
  }

  static String _quizResultKey(String quizId) =>
      'quiz_result_${quizId.toString()}';

  /// Saves quiz result locally so we can show it when user re-opens this quiz.
  Future<void> saveQuizResult(
      String quizId, QuizResultResponseModel data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_quizResultKey(quizId), jsonEncode(data.toJson()));
    } catch (e) {
      log('❌ QuizCubit: Failed to save quiz result: $e');
    }
  }

  /// Returns cached result for this quiz if available.
  Future<QuizResultResponseModel?> getCachedQuizResult(String quizId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_quizResultKey(quizId));
      if (jsonStr == null) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return QuizResultResponseModel.fromJson(map);
    } catch (e) {
      log('❌ QuizCubit: Failed to load cached quiz result: $e');
      return null;
    }
  }

  /// If this quiz was already submitted, loads cached result and emits it. Returns true if result was shown.
  Future<bool> loadCachedResultIfSubmitted(String quizId) async {
    final answered = await isQuizAnswered(quizId);
    if (!answered) return false;
    final cached = await getCachedQuizResult(quizId);
    if (cached != null && !isClosed) {
      _safeEmit(QuizState.sendQuizResultSuccess(cached));
      return true;
    }
    return false;
  }

  // Start quiz
  Future<void> startQuiz(String quizId,
      {bool forceRestart = false, DateTime? quizCreatedAt}) async {
    // Always stop timer first to prevent conflicts
    _stopTimer();

    // If this is a different quiz, reset everything first
    if (_currentQuizId != null && _currentQuizId != quizId) {
      await _clearPreviousQuiz(_currentQuizId!);
      // Reset state completely
      _quizData = null;
      _remainingSeconds = 0;
      _currentQuizId = null;
      _safeEmit(const QuizState.initial());
    }

    // If force restart, clear the quiz flag first
    if (forceRestart) {
      await markQuizAsCompleted(quizId);
    }

    _currentQuizId = quizId;

    // Check if quiz was already started
    final wasStarted = await isQuizStarted(quizId);
    if (wasStarted && !forceRestart) {
      _safeEmit(QuizState.startQuizError(
        ApiErrorModel(message: 'لا يمكن إعادة بدء الاختبار بعد الخروج منه'),
      ));
      return;
    }

    _safeEmit(const QuizState.startQuizLoading());
    log('🔵 QuizCubit: Calling startQuiz for quizId: $quizId');
    final response = await _quizRepo.startQuiz(quizId);
    log('🔵 QuizCubit: Received response, processing...');
    response.when(
      success: (data) {
        log('✅ QuizCubit: Quiz data received successfully. Quiz ID: ${data.data.id}, Questions: ${data.data.questions.length}');
        try {
          // Make sure timer is stopped before starting new one
          _stopTimer();

          // Calculate time limit normally first
          if (data.data.timeLimit == 0) {
            // If time_limit is 0, set 10 seconds per question
            final questionCount = data.data.questions.length;
            _remainingSeconds = questionCount * 10;
          } else {
            // Convert minutes to seconds
            _remainingSeconds = data.data.timeLimit * 60;
          }

          log('🔵 QuizCubit: Time limit calculated: $_remainingSeconds seconds');

          // Always start the timer from now with the full time limit
          // quizCreatedAt is the quiz creation date, not the start time
          // We should always give the user the full time limit from when they start the quiz
          log('✅ QuizCubit: Starting quiz with full time limit from now');

          _quizData = data; // Save quiz data
          log('✅ QuizCubit: Quiz data saved. Starting timer...');
          _markQuizAsStarted(quizId);
          _startTimer();
          log('✅ QuizCubit: Emitting startQuizSuccess state');
          _safeEmit(QuizState.startQuizSuccess(data));
        } catch (e, stackTrace) {
          log('❌ QuizCubit: Error processing quiz data: $e');
          log('❌ QuizCubit: Stack trace: $stackTrace');
          _safeEmit(QuizState.startQuizError(
            ApiErrorModel(message: 'خطأ في معالجة بيانات الاختبار: $e'),
          ));
        }
      },
      failure: (apiErrorModel) {
        log('❌ QuizCubit: Quiz start failed: ${apiErrorModel.getAllErrorsAsString()}');
        _safeEmit(QuizState.startQuizError(apiErrorModel));
      },
    );
  }

  // Clear previous quiz data
  Future<void> _clearPreviousQuiz(String previousQuizId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quiz_started_$previousQuizId');
  }

  // Send quiz result
  Future<void> sendQuizResult(
      String quizId, Map<String, String> answers) async {
    if (isClosed) return;
    _safeEmit(const QuizState.sendQuizResultLoading());
    final request = QuizResultRequestModel(answers: answers);
    final response = await _quizRepo.sendQuizResult(quizId, request);
    response.when(
      success: (data) async {
        _stopTimer();
        // Mark quiz as completed so it can be restarted
        await markQuizAsCompleted(quizId);
        // Save quiz ID locally - user has answered this exam (must await to persist)
        await saveCompletedQuizId(quizId);
        // Save result so we can show it when user opens this quiz again
        await saveQuizResult(quizId, data);
        if (!isClosed) {
          _safeEmit(QuizState.sendQuizResultSuccess(data));
        }
      },
      failure: (apiErrorModel) {
        _safeEmit(QuizState.sendQuizResultError(apiErrorModel));
      },
    );
  }

  // Start timer
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _safeEmit(QuizState.quizTimerTick(_remainingSeconds));
      } else {
        _stopTimer();
        _safeEmit(const QuizState.quizTimeUp());
      }
    });
  }

  // Reset quiz data
  void resetQuiz() {
    // Stop timer first
    _stopTimer();
    // Clear all data
    _quizData = null;
    _remainingSeconds = 0;
    _currentQuizId = null;
    // Emit initial state
    _safeEmit(const QuizState.initial());
  }

  // Clear all quiz flags (for debugging/reset all)
  Future<void> clearAllQuizFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('quiz_started_')) {
        await prefs.remove(key);
      }
    }
  }

  // Stop timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }
}
