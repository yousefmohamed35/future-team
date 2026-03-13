import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/helper/shared_pref_helper.dart';
import 'package:future_app/core/helper/shared_pref_keys.dart';
import 'package:future_app/features/courses/presentation/assignment_file_viewer_screen.dart';
import 'package:future_app/features/courses/presentation/widgets/pdf_viewer_widget.dart';

/// Response model for GET /panel/assignments/{id}/my-submission
class AssignmentSubmissionData {
  final bool submitted;
  final int? submissionId;
  final String? submittedAt;
  final String? assignmentAnswer;
  final List<AssignmentSubmittedFile> files;

  AssignmentSubmissionData({
    required this.submitted,
    this.submissionId,
    this.submittedAt,
    this.assignmentAnswer,
    required this.files,
  });

  factory AssignmentSubmissionData.fromJson(Map<String, dynamic> json) {
    final filesList = json['files'] as List<dynamic>? ?? [];
    return AssignmentSubmissionData(
      submitted: json['submitted'] as bool? ?? false,
      submissionId: json['submission_id'] as int?,
      submittedAt: json['submitted_at'] as String?,
      assignmentAnswer: json['assignment_answer'] as String?,
      files: filesList
          .map((e) =>
              AssignmentSubmittedFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AssignmentSubmittedFile {
  final String name;
  final String url;
  final String? sizeReadable;

  AssignmentSubmittedFile({
    required this.name,
    required this.url,
    this.sizeReadable,
  });

  factory AssignmentSubmittedFile.fromJson(Map<String, dynamic> json) {
    return AssignmentSubmittedFile(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      sizeReadable: json['size_readable'] as String?,
    );
  }
}

class AssignmentScreen extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;
  final String? pdfUrl;
  final String? description;

  const AssignmentScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    this.pdfUrl,
    this.description,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  String? _cleanedPdfUrl;
  File? _selectedFile;
  bool _isSubmitting = false;
  bool _mySubmissionLoading = true;
  AssignmentSubmissionData? _mySubmission;
  String? _mySubmissionError;

  @override
  void initState() {
    super.initState();
    // Use pdfUrl only if non-null and non-empty; otherwise use description (API often puts URL in description when pdfUrl is "")
    final String? urlOrDescription =
        (widget.pdfUrl != null && widget.pdfUrl!.trim().isNotEmpty)
            ? widget.pdfUrl
            : widget.description;
    _cleanedPdfUrl = _extractUrlFromHtml(urlOrDescription ?? '');
    _loadMySubmission();
  }

  Future<void> _loadMySubmission() async {
    if (!mounted) return;
    setState(() {
      _mySubmissionLoading = true;
      _mySubmissionError = null;
    });
    try {
      final token =
          await SharedPrefHelper.getSecuredString(SharedPrefKeys.userToken);
      if (token.isEmpty) {
        setState(() {
          _mySubmissionLoading = false;
          _mySubmission = null;
          _mySubmissionError = 'يجب تسجيل الدخول أولاً';
        });
        return;
      }
      final dio = Dio();
      final url =
          '${ApiConstants.apiBaseUrl}panel/assignments/${widget.assignmentId}/my-submission';
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'x-api-key': ApiConstants.apiKey,
            'X-App-Source': ApiConstants.appSource,
            'Accept': 'application/json',
          },
        ),
      );
      if (!mounted) return;
      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] != null) {
        setState(() {
          _mySubmission = AssignmentSubmissionData.fromJson(
              data['data'] as Map<String, dynamic>);
          _mySubmissionLoading = false;
          _mySubmissionError = null;
        });
      } else {
        setState(() {
          _mySubmission = null;
          _mySubmissionLoading = false;
          _mySubmissionError = 'لم يتم جلب التسليم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mySubmission = null;
          _mySubmissionLoading = false;
          _mySubmissionError = e is DioException && e.response != null
              ? (e.response?.data is Map &&
                      (e.response?.data as Map)['message'] != null
                  ? (e.response?.data as Map)['message'].toString()
                  : 'فشل جلب التسليم')
              : 'تحقق من اتصال الإنترنت';
        });
      }
    }
  }

  /// استخراج الرابط من النص HTML
  String _extractUrlFromHtml(String? htmlText) {
    if (htmlText == null || htmlText.isEmpty) {
      return '';
    }

    // أولاً: استخراج من href إن وُجد (مثل <a href="https://...">)
    final hrefDouble = RegExp(r'href="([^"]+)"', caseSensitive: false);
    final hrefSingle = RegExp(r"href='([^']+)'", caseSensitive: false);
    var hrefMatch =
        hrefDouble.firstMatch(htmlText) ?? hrefSingle.firstMatch(htmlText);
    if (hrefMatch != null) {
      final url = hrefMatch.group(1)?.trim() ?? '';
      if (url.isNotEmpty &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        return url;
      }
    }

    // إزالة HTML tags
    String cleaned = htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '') // إزالة جميع HTML tags
        .trim();

    // البحث عن رابط HTTP أو HTTPS (محاولة أولى بدون تعديل)
    final urlRegex = RegExp(
      r'https?://[^\s<>\"]+',
      caseSensitive: false,
    );

    var match = urlRegex.firstMatch(cleaned);
    if (match != null) {
      final url = match.group(0) ?? '';
      // الرابط كامل إذا انتهى بـ .pdf
      if (url.toLowerCase().endsWith('.pdf')) {
        return url;
      }
    }

    // إذا فشلت المحاولة الأولى: الرابط قد يكون مقسوم بسطر جديد (من API)
    // إزالة المسافات والأسطر لربط الرابط
    final normalized = cleaned.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    match = urlRegex.firstMatch(normalized);
    if (match != null) {
      return match.group(0) ?? '';
    }

    // محاولة أخيرة: البحث عن https:// حتى .pdf
    final pdfUrlRegex = RegExp(
      r'https?://[\s\S]+?\.pdf',
      caseSensitive: false,
    );
    match = pdfUrlRegex.firstMatch(cleaned);
    if (match != null) {
      return match.group(0)!.replaceAll(RegExp(r'[\r\n\t\s]+'), '');
    }

    return cleaned;
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الملف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitAssignment() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار ملف للإرسال'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token =
          await SharedPrefHelper.getSecuredString(SharedPrefKeys.userToken);
      if (token.isEmpty) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final dio = Dio();
      final url =
          '${ApiConstants.apiBaseUrl}panel/assignments/${widget.assignmentId}/submit';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          _selectedFile!.path,
          filename: _selectedFile!.path.split(Platform.pathSeparator).last,
        ),
        'assignment_answer': 'تم التسليم من التطبيق.',
      });

      final headers = {
        'Authorization': 'Bearer $token',
        'x-api-key': ApiConstants.apiKey,
        'X-App-Source': ApiConstants.appSource,
        'Accept': 'application/json',
      };

      developer.log(
        'Assignment submit REQUEST\n'
        'URL: $url\n'
        'assignmentId: ${widget.assignmentId}\n'
        'file: ${_selectedFile!.path}\n'
        'headers: $headers',
        name: 'AssignmentSubmit',
      );

      final response = await dio.post(
        url,
        data: formData,
        options: Options(headers: headers),
      );

      developer.log(
        'Assignment submit RESPONSE\n'
        'statusCode: ${response.statusCode}\n'
        'data: ${response.data}',
        name: 'AssignmentSubmit',
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text('تم إرسال الواجب بنجاح'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Clear selected file and refresh my submission
          setState(() {
            _selectedFile = null;
          });
          _loadMySubmission();
        } else {
          throw Exception('فشل إرسال الواجب');
        }
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        developer.log(
          'Assignment submit ERROR RESPONSE\n'
          'statusCode: ${e.response?.statusCode}\n'
          'data: ${e.response?.data}',
          name: 'AssignmentSubmit',
        );
      }
      if (mounted) {
        String errorMessage = 'خطأ في إرسال الواجب';
        if (e is DioException) {
          if (e.response != null) {
            final data = e.response?.data;
            if (data is Map && data['message'] != null) {
              final msg = data['message'];
              errorMessage = msg is String ? msg : msg.toString();
            }
          } else {
            errorMessage = 'تحقق من اتصال الإنترنت';
          }
        } else {
          errorMessage = e.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        title: Text(
          widget.assignmentTitle,
          style: const TextStyle(
            color: Color(0xFFd4af37),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFd4af37)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // PDF card: tap to open on separate page with title
          Padding(
            padding: const EdgeInsets.all(16),
            child: _cleanedPdfUrl != null && _cleanedPdfUrl!.isNotEmpty
                ? Material(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PDFViewerWidget(
                              pdfUrl: _cleanedPdfUrl!,
                              title: widget.assignmentTitle,
                              isDownloadable: true,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFd4af37).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Color(0xFFd4af37),
                              size: 40,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.assignmentTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'اضغط لعرض الملزمة',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              color: Color(0xFFd4af37),
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2a2a2a),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFd4af37).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Color(0xFFd4af37),
                          size: 40,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'لا يوجد ملف PDF متاح',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // My Submission + Submit Section (scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // My Submission Section
                  _buildMySubmissionSection(),
                  const SizedBox(height: 20),
                  // Submit Section
                  _buildSubmitSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySubmissionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFd4af37).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_turned_in,
                  color: Color(0xFFd4af37), size: 22),
              SizedBox(width: 8),
              Text(
                'تسليمي',
                style: TextStyle(
                  color: Color(0xFFd4af37),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_mySubmissionLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFd4af37)),
                ),
              ),
            )
          else if (_mySubmissionError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _mySubmissionError!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else if (_mySubmission == null)
            const Text(
              'لم يتم جلب التسليم',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            )
          else if (!_mySubmission!.submitted)
            const Text(
              'لم يتم تسليم هذه الوظيفة بعد.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_mySubmission!.submittedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'تاريخ التسليم: ${_mySubmission!.submittedAt}',
                      style: const TextStyle(
                        color: Color(0xFFd4af37),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (_mySubmission!.files.isEmpty)
                  const Text(
                    'لا توجد ملفات مرفقة',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  )
                else
                  ..._mySubmission!.files.map((file) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: const Color(0xFF1a1a1a),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AssignmentFileViewerScreen(
                                    fileUrl: file.url,
                                    fileName: file.name,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    color: Color(0xFFd4af37),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          file.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (file.sizeReadable != null &&
                                            file.sizeReadable!.isNotEmpty)
                                          Text(
                                            file.sizeReadable!,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.open_in_new,
                                    color: Color(0xFFd4af37),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File Selection Button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a1a),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFd4af37).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickFile,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        color: Color(0xFFd4af37),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اختر ملف للإرسال',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _selectedFile!.path
                                      .split(Platform.pathSeparator)
                                      .last,
                                  style: const TextStyle(
                                    color: Color(0xFFd4af37),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedFile != null)
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedFile = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Submit Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFd4af37),
                  const Color(0xFFd4af37).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFd4af37).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isSubmitting ? null : _submitAssignment,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSubmitting)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.send,
                          color: Colors.black,
                          size: 24,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        _isSubmitting ? 'جاري الإرسال...' : 'إرسال الواجب',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
