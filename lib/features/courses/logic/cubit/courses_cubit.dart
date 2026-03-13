import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:future_app/features/courses/data/models/courses_model.dart';
import 'package:future_app/features/courses/data/repos/courses_repo.dart';
import 'package:future_app/features/courses/logic/cubit/courses_state.dart';
import 'package:future_app/core/models/banner_model.dart';

/// ترتيب الفرقة الدراسية: الأولى ثم الثانية ثم الثالثة ثم الرابعة ثم خريج ثم الباقي
const List<String> _studyLevelOrder = [
  'الفرقة الأولى',
  'الفرقة الثانية',
  'الفرقة الثالثة',
  'الفرقة الرابعة',
  'خريج',
];

int _levelOrderIndex(String level) {
  final idx = _studyLevelOrder.indexOf(level);
  return idx >= 0 ? idx : _studyLevelOrder.length;
}

List<CourseModel> _sortCoursesByStudyLevel(List<CourseModel> courses) {
  final list = List<CourseModel>.from(courses);
  list.sort(
      (a, b) => _levelOrderIndex(a.level).compareTo(_levelOrderIndex(b.level)));
  return list;
}

class CoursesCubit extends Cubit<CoursesState> {
  CoursesCubit(this._coursesRepo) : super(const CoursesState.initial());

  final CoursesRepo _coursesRepo;

  // Banners state
  List<BannerModel> _banners = [];

  // Pagination state
  int _currentPage = 1;
  final int _limit = 10;
  bool _hasMorePages = true;
  bool _isLoadingMore = false;
  List<CourseModel> _allCourses = [];
  PaginationData? _paginationData;

  /// Current grade filter (null = all). e.g. 44,52,59,65 for الفرقة الأولى..الرابعة
  int? _currentFiltersLevels;

  // Getters
  List<BannerModel> get banners => _banners;
  List<CourseModel> get allCourses => _allCourses;
  PaginationData? get paginationData => _paginationData;
  bool get hasMorePages => _hasMorePages;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  int? get currentFiltersLevels => _currentFiltersLevels;

  // Get banners
  Future<void> getBanners() async {
    print('🚀 CoursesCubit: Starting getBanners...');
    emit(const CoursesState.getBannersLoading());
    final response = await _coursesRepo.getBanners();
    response.when(
      success: (data) {
        print(
            '✅ CoursesCubit: Banners success - ${data.data.banners.length} banners');
        _banners = data.data.banners;
        emit(CoursesState.getBannersSuccess(data));
      },
      failure: (apiErrorModel) {
        print('❌ CoursesCubit: Banners failed - ${apiErrorModel.message}');
        emit(CoursesState.getBannersError(apiErrorModel));
      },
    );
  }

  /// Call before getCourses(refresh: true) to filter by grade. Pass null for "All".
  void setGradeFilter(int? filtersLevels) {
    _currentFiltersLevels = filtersLevels;
  }

  // Get courses (initial load or refresh)
  /// [filtersLevels] optional - filter by grade (null = all). e.g. 44,52,59,65
  Future<void> getCourses({bool refresh = false, int? filtersLevels}) async {
    if (refresh) {
      _resetPagination();
    }
    if (refresh) {
      _currentFiltersLevels = filtersLevels;
    } else if (filtersLevels != null) {
      _currentFiltersLevels = filtersLevels;
    }

    emit(const CoursesState.getCoursesLoading());
    final response = await _coursesRepo.getCourses(
      page: _currentPage,
      limit: _limit,
      filtersLevels: filtersLevels ?? _currentFiltersLevels,
    );
    response.when(
      success: (data) {
        _allCourses = _sortCoursesByStudyLevel(data.data);
        _paginationData = data.pagination;
        _hasMorePages = data.pagination.hasNextPage;
        emit(CoursesState.getCoursesSuccess(GetCoursesResponseModel(
          success: data.success,
          message: data.message,
          data: _allCourses,
          pagination: data.pagination,
        )));
      },
      failure: (apiErrorModel) {
        emit(CoursesState.getCoursesError(apiErrorModel));
      },
    );
  }

  // Load more courses (pagination)
  Future<void> loadMoreCourses() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingMore || !_hasMorePages) {
      return;
    }

    _isLoadingMore = true;
    _currentPage++;

    emit(const CoursesState.loadMoreCoursesLoading());
    final response = await _coursesRepo.getCourses(
      page: _currentPage,
      limit: _limit,
      filtersLevels: _currentFiltersLevels,
    );
    response.when(
      success: (data) {
        _allCourses.addAll(data.data);
        _allCourses = _sortCoursesByStudyLevel(_allCourses);
        _paginationData = data.pagination;
        _hasMorePages = data.pagination.hasNextPage;
        _isLoadingMore = false;
        emit(CoursesState.loadMoreCoursesSuccess(GetCoursesResponseModel(
          success: data.success,
          message: data.message,
          data: _allCourses,
          pagination: data.pagination,
        )));
      },
      failure: (apiErrorModel) {
        _currentPage--; // Revert page increment on error
        _isLoadingMore = false;
        emit(CoursesState.loadMoreCoursesError(apiErrorModel));
      },
    );
  }

  // Reset pagination state
  void _resetPagination() {
    _currentPage = 1;
    _hasMorePages = true;
    _isLoadingMore = false;
    _allCourses = [];
    _paginationData = null;
  }

  // Public method to reset and reload (keeps current grade filter)
  Future<void> refresh() async {
    await getCourses(refresh: true, filtersLevels: _currentFiltersLevels);
  }

  // Get single course by ID
  Future<void> getSingleCourse(String courseId) async {
    emit(const CoursesState.getSingleCourseLoading());
    final response = await _coursesRepo.getSingleCourse(courseId);
    response.when(
      success: (data) {
        emit(CoursesState.getSingleCourseSuccess(data));
      },
      failure: (apiErrorModel) {
        emit(CoursesState.getSingleCourseError(apiErrorModel));
      },
    );
  }

  // Get course content
  Future<void> getCourseContent(String courseId) async {
    emit(const CoursesState.getCourseContentLoading());
    final response = await _coursesRepo.getCourseContent(courseId);
    response.when(
      success: (data) {
        emit(CoursesState.getCourseContentSuccess(data));
      },
      failure: (apiErrorModel) {
        emit(CoursesState.getCourseContentError(apiErrorModel));
      },
    );
  }
}
