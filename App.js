import { StatusBar } from 'expo-status-bar';
import { StyleSheet, useColorScheme, Alert, Platform, View, AppState } from 'react-native';
import { WebView } from 'react-native-webview';
import * as SplashScreen from 'expo-splash-screen';
import { useCallback, useState, useEffect, useRef } from 'react';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import * as MediaLibrary from 'expo-media-library';

// Keep the splash screen visible while we fetch resources
SplashScreen.preventAutoHideAsync();

export default function App() {
  const colorScheme = useColorScheme();
  const [appIsReady, setAppIsReady] = useState(false);
  const [webViewOpacity, setWebViewOpacity] = useState(0);
  const [key, setKey] = useState(0);

  const appState = useRef(AppState.currentState);
  const lastBackgroundTime = useRef(null);

  // Xử lý khi quay lại app (Resume) sau 1 phút
  useEffect(() => {
    const subscription = AppState.addEventListener('change', async (nextAppState) => {
      if (appState.current.match(/inactive|background/) && nextAppState === 'active') {
        const now = Date.now();
        const backgroundDuration = lastBackgroundTime.current ? now - lastBackgroundTime.current : 0;

        if (backgroundDuration > 60000) {
          setAppIsReady(false);
          setWebViewOpacity(0);
          await SplashScreen.preventAutoHideAsync();
          setKey(prev => prev + 1);
        }
      }
      if (nextAppState === 'background') {
        lastBackgroundTime.current = Date.now();
      }
      appState.current = nextAppState;
    });
    return () => subscription.remove();
  }, []);

  const handleLoadEnd = useCallback(async () => {
    if (!appIsReady) {
      setTimeout(async () => {
        setWebViewOpacity(1);
        setAppIsReady(true);
        await SplashScreen.hideAsync();
      }, 500);
    }
  }, [appIsReady]);

  // Hàm chủ động xin quyền và lưu ảnh
  const processMediaDownload = async (uri) => {
    try {
      // Kiểm tra quyền hiện tại
      let { status, canAskAgain } = await MediaLibrary.getPermissionsAsync();

      // Nếu chưa có quyền, chủ động hiện bảng xin quyền
      if (status !== 'granted' && canAskAgain) {
        const ask = await MediaLibrary.requestPermissionsAsync();
        status = ask.status;
      }

      if (status === 'granted') {
        const asset = await MediaLibrary.createAssetAsync(uri);
        await MediaLibrary.createAlbumAsync('Download', asset, false);
        // Lưu im lặng, không hiện Alert theo ý bạn
      } else {
        // Nếu người dùng từ chối, dùng Sharing làm phương án dự phòng
        await Sharing.shareAsync(uri);
      }
    } catch (e) {
      await Sharing.shareAsync(uri);
    }
  };

  const handleMessage = async (event) => {
    try {
      const data = JSON.parse(event.nativeEvent.data);
      if (data.type === 'download') {
        const { base64, fileName, contentType } = data;
        const fileUri = FileSystem.cacheDirectory + fileName;
        await FileSystem.writeAsStringAsync(fileUri, base64, { encoding: 'base64' });

        const isImage = contentType?.startsWith('image/') || /\.(jpg|jpeg|png|gif|webp)$/i.test(fileName);

        if (isImage) {
          await processMediaDownload(fileUri);
        } else {
          await Sharing.shareAsync(fileUri);
        }
      }
    } catch (e) {
      console.error('Message error:', e);
    }
  };

  const injectedJavaScript = `
    (function() {
      const originalCreateObjectURL = window.URL.createObjectURL;
      window.URL.createObjectURL = function(blob) {
        const url = originalCreateObjectURL(blob);
        if (blob instanceof Blob && blob.type.startsWith('image/')) {
          const reader = new FileReader();
          reader.onloadend = function() {
            const base64data = reader.result.split(',')[1];
            window.ReactNativeWebView.postMessage(JSON.stringify({
              type: 'download',
              base64: base64data,
              fileName: 'img_' + Date.now() + (blob.type === 'image/jpeg' ? '.jpg' : blob.type === 'image/png' ? '.png' : ''),
              contentType: blob.type
            }));
          };
          reader.readAsDataURL(blob);
        }
        return url;
      };
    })();
  `;

  const handleDownload = async (event) => {
    const { url, contentDisposition, mimetype } = event.nativeEvent;
    let fileName = 'file_' + Date.now();
    if (contentDisposition) {
      const match = contentDisposition.match(/filename="?([^";]+)"?/);
      if (match) fileName = match[1];
    } else {
      const urlParts = url.split('/');
      const lastPart = urlParts[urlParts.length - 1].split('?')[0];
      if (lastPart) fileName = lastPart;
    }
    fileName = fileName.replace(/[/\\?%*:|"<>]/g, '_');

    if (!fileName.includes('.') && mimetype) {
      const ext = mimetype.split('/')[1]?.split('+')[0];
      if (ext) fileName += `.${ext}`;
    }

    const fileUri = FileSystem.cacheDirectory + fileName;

    try {
      const downloadResumable = FileSystem.createDownloadResumable(url, fileUri);
      const { uri } = await downloadResumable.downloadAsync();

      const isImage = mimetype?.startsWith('image/') || /\.(jpg|jpeg|png|gif|webp)$/i.test(fileName);

      if (isImage) {
        await processMediaDownload(uri);
      } else {
        await Sharing.shareAsync(uri);
      }
    } catch (e) {
      console.error('Download error:', e);
    }
  };

  const themeContainerStyle = colorScheme === 'dark' ? styles.containerDark : styles.containerLight;
  const webviewBackground = colorScheme === 'dark' ? '#000000' : '#ffffff';

  return (
    <SafeAreaProvider>
      <View style={[styles.container, themeContainerStyle]}>
        <SafeAreaView style={styles.container} edges={['top', 'right', 'left', 'bottom']}>
          <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
          <WebView
            key={key}
            source={{ uri: 'https://duyxyz.github.io/' }}
            style={[styles.webview, { backgroundColor: webviewBackground, opacity: webViewOpacity }]}
            containerStyle={{ backgroundColor: webviewBackground }}
            onLoadEnd={handleLoadEnd}
            onError={handleLoadEnd}
            onDownloadStart={handleDownload}
            useDownloadManager={true}
            onMessage={handleMessage}
            injectedJavaScript={injectedJavaScript}
            userAgent="Mozilla/5.0 (Linux; Android 13; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36"
            overScrollMode="never"
            bounces={false}
            allowsBackForwardNavigationGestures={true}
            javaScriptEnabled={true}
            domStorageEnabled={true}
            allowFileAccess={true}
            allowFileAccessFromFileURLs={true}
            allowUniversalAccessFromFileURLs={true}
            mixedContentMode="always"
            incognito={false}
            cacheEnabled={true}
          />
        </SafeAreaView>
      </View>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  containerLight: { backgroundColor: '#fff' },
  containerDark: { backgroundColor: '#000' },
  webview: { flex: 1, backgroundColor: 'transparent' },
});
