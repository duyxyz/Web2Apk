import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system, // Tự động nhận diện sáng tối
      home: const WebAppScreen(),
    );
  }
}

class WebAppScreen extends StatefulWidget {
  const WebAppScreen({super.key});

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  InAppWebViewController? webViewController;

  // Tối ưu mạnh mẽ Webview Engine mới với Hybrid Composition và Native OverScroll chặn 100% hiệu ứng cao su
  final InAppWebViewSettings settings = InAppWebViewSettings(
    userAgent: 'Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
    transparentBackground: true,
    overScrollMode: OverScrollMode.NEVER, // Chặn hiệu ứng loè viền cực xịn tận gốc C++ Android
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true, // Lưu bộ đệm tĩnh cục bộ thay vì load đi load lại
    useHybridComposition: true, // Ép dùng phần cứng ảo Native Layer của Android, lướt siêu nhanh không bị drop giật frame
  );

  @override
  Widget build(BuildContext context) {
    // Nhận diện giao diện Sáng / Tối từ hệ thống thiết bị
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: SafeArea(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri('https://www.example.com/')),
              initialSettings: settings,
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
            ),
          ),
        ),
      ),
    );
  }
}
