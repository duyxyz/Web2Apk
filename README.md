# Web to App Converter 

This is a simple Flutter application that acts as a web wrapper. It automatically loads a specified website URL using an embedded `InAppWebView`.

## How to Build the App (via GitHub Actions)

1. **Fork this repository** to your own GitHub account.
2. Go to the **Actions** tab in your forked repository.
<img width="323" height="43" alt="image" src="https://github.com/user-attachments/assets/2e4885f6-2ebf-4974-84b4-9750d1ec4b48" />

3. Select the **Build Flutter APK** workflow on the left sidebar.
<img width="326" height="47" alt="image" src="https://github.com/user-attachments/assets/f5f9e4a7-439a-417a-8ce9-8e117df54278" />

4. Click on the **Run workflow** dropdown button.
<img width="131" height="44" alt="image" src="https://github.com/user-attachments/assets/eaabf5d1-1d11-41dc-9cc1-7357873858bb" />

5. Fill in the required parameters:
<img width="312" height="482" alt="image" src="https://github.com/user-attachments/assets/4c21422a-9639-4f8a-94b7-d24f93c56ecf" />

6. Click **Run workflow** and wait for the build to finish.
7. Once it completes, scroll down to the **Artifacts** section of the workflow run to download the generated `.apk` files for your device.

## Local Development (Optional)

If you'd like to run or modify the code locally instead:
1. Ensure you have the Flutter SDK installed (requires SDK version `^3.5.0`).
2. Clone this repository to your local machine.
3. Run `flutter pub get` in the project root to install dependencies.
4. Run `flutter run` to launch the application.
