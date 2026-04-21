import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _isSpecialExternalScheme(Uri uri) {
    const externalSchemes = {
      'intent',
      'market',
      'mailto',
      'tel',
      'sms',
      'tg',
      'whatsapp',
      'zalo',
      'fb',
      'facebook',
      'instagram',
      'youtube',
    };

    return externalSchemes.contains(uri.scheme.toLowerCase());
  }

  Future<bool> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadFile(DownloadStartRequest request) async {
    final url = request.url.toString();
    final opened = await _openExternally(url);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened download link in your default browser'
              : 'Could not open this download link externally',
        ),
      ),
    );
  }

  Future<void> _handleExternalNavigation(String url) async {
    final opened = await _openExternally(url);
    if (!mounted) {
      return;
    }

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link with an external app'),
        ),
      );
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
                    FlutterNativeSplash.remove();
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      pullToRefreshController?.endRefreshing();
                      FlutterNativeSplash.remove();
                    }
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    final url = navigationAction.request.url?.toString();
                    final uri = url == null ? null : Uri.tryParse(url);
                    if (uri != null && _isSpecialExternalScheme(uri)) {
                      await _handleExternalNavigation(url!);
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                  onReceivedError: (controller, request, error) {
                    pullToRefreshController?.endRefreshing();
                    FlutterNativeSplash.remove();
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
