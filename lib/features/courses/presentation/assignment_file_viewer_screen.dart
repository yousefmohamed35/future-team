import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Full-screen viewer for assignment submitted files (PDF, image, etc.) via URL.
class AssignmentFileViewerScreen extends StatelessWidget {
  final String fileUrl;
  final String fileName;

  const AssignmentFileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1a1a1a))
      ..loadRequest(Uri.parse(fileUrl));

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        title: Text(
          fileName,
          style: const TextStyle(
            color: Color(0xFFd4af37),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFd4af37)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
