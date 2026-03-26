import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Web2APK',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
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
  PullToRefreshController? pullToRefreshController;

  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final InAppWebViewSettings settings = InAppWebViewSettings(
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
    transparentBackground: true,
    safeBrowsingEnabled: true,
    allowsInlineMediaPlayback: true,
    allowsBackForwardNavigationGestures: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    useHybridComposition: true,
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportZoom: false,
    builtInZoomControls: false,
    displayZoomControls: false,
    overScrollMode: OverScrollMode.NEVER,
    verticalScrollBarEnabled: false,
    horizontalScrollBarEnabled: false,
  );

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.none)) {
        setState(() => _isOffline = true);
      } else {
        if (_isOffline) {
          setState(() => _isOffline = false);
          webViewController?.reload();
        }
      }
    });

    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      setState(() => _isOffline = true);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _downloadFile(DownloadStartRequest request) async {
    final url = request.url.toString();
    final fileName = request.suggestedFilename ??
        (url.startsWith('data:')
            ? 'downloaded_file'
            : p.basename(url.split('?').first));

    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted ||
          await Permission.photos.request().isGranted) {
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }
    }

    try {
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        downloadsDirectory = Directory('/storage/emulated/0/Download');
        if (!await downloadsDirectory.exists()) {
          downloadsDirectory = await getExternalStorageDirectory();
        }
      } else {
        downloadsDirectory = await getDownloadsDirectory();
      }

      if (downloadsDirectory == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find downloads directory')),
          );
        }
        return;
      }

      final savePath = p.join(downloadsDirectory.path, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading $fileName...')),
        );
      }

      if (url.startsWith('data:')) {
        // Handle Data URL
        final data = url.split(',').last;
        final bytes = base64.decode(data);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
      } else if (url.startsWith('blob:')) {
        // Handle Blob URL via JavaScript
        final jsCode = """
          (async function() {
            try {
              const response = await fetch('$url');
              const blob = await response.blob();
              return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
              });
            } catch (e) {
              return null;
            }
          })();
        """;
        final base64String = await webViewController?.evaluateJavascript(source: jsCode);
        if (base64String != null && base64String is String && base64String.contains(',')) {
          final data = base64String.split(',').last;
          final bytes = base64.decode(data);
          final file = File(savePath);
          await file.writeAsBytes(bytes);
        } else {
          throw Exception("Could not fetch blob data");
        }
      } else {
        // Handle standard URL
        String? cookies;
        if (!kIsWeb) {
          final cookieManager = CookieManager.instance();
          final list = await cookieManager.getCookies(url: WebUri(url));
          cookies = list.map((e) => '${e.name}=${e.value}').join('; ');
        }

        final dio = Dio();
        await dio.download(
          url,
          savePath,
          options: Options(
            headers: {
              if (cookies != null && cookies.isNotEmpty) 'Cookie': cookies,
              'User-Agent': settings.userAgent,
            },
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download completed: $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                OpenFilex.open(savePath);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
          value: isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: SafeArea(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest:
                      URLRequest(url: WebUri('https://www.example.com/')),
                  initialSettings: settings,
                  pullToRefreshController: pullToRefreshController,
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onLoadStop: (controller, url) async {
                    pullToRefreshController?.endRefreshing();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController?.endRefreshing();
                    }
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    return NavigationActionPolicy.ALLOW;
                  },
                  onReceivedError: (controller, request, error) {
                    pullToRefreshController?.endRefreshing();
                    if (error.type ==
                            WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                        error.type == WebResourceErrorType.HOST_LOOKUP) {
                      setState(() => _isOffline = true);
                    }
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onDownloadStartRequest: (controller, request) {
                    _downloadFile(request);
                  },
                ),
                if (_isOffline) _buildOfflineScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineScreen() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No Internet Connection',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please check your network settings and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                _checkInitialConnectivity().then((_) {
                  if (!_isOffline) {
                    webViewController?.reload();
                  }
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
