import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:future_app/core/constants/app_constants.dart';

/// Fallback fullscreen video player using WebView when ExoPlayer fails (e.g. Source error).
/// Loads an HTML page with the video URL so the request comes from WebView with site origin.
class VideoWebViewFallbackScreen extends StatelessWidget {
  final String videoUrl;
  final String title;

  const VideoWebViewFallbackScreen({
    super.key,
    required this.videoUrl,
    this.title = 'الفيديو',
  });

  @override
  Widget build(BuildContext context) {
    final escapedUrl = videoUrl
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final html = '''
<!DOCTYPE html>
<html dir="rtl">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #000; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
    video { width: 100%; max-height: 100vh; }
  </style>
</head>
<body>
  <video src="$escapedUrl" controls playsinline webkit-playsinline></video>
</body>
</html>''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(html, baseUrl: AppConstants.websiteOrigin);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
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
      body: SafeArea(child: WebViewWidget(controller: controller)),
    );
  }
}
