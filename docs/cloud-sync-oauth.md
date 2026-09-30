# Cloud sync OAuth setup

Google Drive and OneDrive credentials are public native-app configuration, supplied with Dart defines at build time. **Do not add a client secret** to the application or repository. Access/refresh tokens are stored through `simple_secure_storage`, not preferences.

## Google Drive

1. In one Google Cloud project, enable **Google Drive API** and **Google Picker API**.
2. Create OAuth clients in that project:
   - **Desktop app** client for Linux/Windows/macOS OAuth.
   - Android OAuth clients for each package name and signing-certificate SHA-1 used by the shipped flavors. Android uses Google Identity Services; it does not use the desktop loopback flow.
   - A **Web application** client ID for Android's `serverClientId`.
3. The account requests only `https://www.googleapis.com/auth/drive.file`. The Picker API key and Cloud project number are also required to choose a parent folder.
4. Restrict the Picker API key to the Google Picker API. A Web referrer restriction may not match the app's embedded `http://localhost/` Picker origin; test your chosen key restrictions on each platform.

Build defines:

```text
CIYUE_GOOGLE_DRIVE_DESKTOP_CLIENT_ID
CIYUE_GOOGLE_DRIVE_DESKTOP_REDIRECT_URI   # optional; default http://localhost:43824
CIYUE_GOOGLE_ANDROID_SERVER_CLIENT_ID     # Web application client ID
CIYUE_GOOGLE_PICKER_API_KEY
CIYUE_GOOGLE_PROJECT_NUMBER               # numeric Cloud project number, not a client ID
```

`drive.file` intentionally does not grant access to arbitrary existing Drive files. The Picker chooses a **parent folder**; Ciyue creates/uses its own `Ciyue` directory and sync files beneath it. Keep the desktop and Android OAuth clients in the same Cloud project so they represent the same app. Users should not expect Ciyue to import unrelated files merely because they are inside the chosen folder.

## OneDrive

1. Create a Microsoft Entra app registration for a public/native client. Do not create or ship a client secret.
2. Add the delegated Microsoft Graph permission `Files.ReadWrite` and request user consent as required by your tenant. The default tenant is `common`; use a tenant ID/domain to restrict sign-in if desired.
3. Add the platform redirects:
   - **Mobile and desktop applications** for desktop, with `http://localhost` registered. Ciyue's loopback listener defaults to port `43824`; Entra ignores the port when matching localhost redirects.
   - **Android** for every Android application ID and signing certificate you distribute. Entra generates the `msauth://<package-name>/<signature-hash>` URI. Use the exact URI for the selected flavor/signing key.

Build defines:

```text
CIYUE_MICROSOFT_CLIENT_ID
CIYUE_MICROSOFT_TENANT                    # optional; defaults to common
CIYUE_MICROSOFT_DESKTOP_REDIRECT_URI       # optional; default http://localhost:43824
CIYUE_MICROSOFT_ANDROID_REDIRECT_URI       # exact Entra-generated msauth:// URI
```

Android application IDs are defined in `android/app/build.gradle.kts`: `org.eu.mumulhl.ciyue`, `.dev`, `.full`, and `.full.dev` (the suffixes are applied to the base ID). Register the package/signature combinations actually used for debug and release builds. The manifest callback filter uses `msauth`, the built application ID, and a `/` path prefix.

## Build example

Pass only the defines needed for the target platform/provider. Quote values containing punctuation so the shell does not interpret them:

```bash
flutter build linux --dart-define=CIYUE_GOOGLE_DRIVE_DESKTOP_CLIENT_ID='...apps.googleusercontent.com' \
  --dart-define=CIYUE_GOOGLE_PICKER_API_KEY='...' \
  --dart-define=CIYUE_GOOGLE_PROJECT_NUMBER='1234567890' \
  --dart-define=CIYUE_MICROSOFT_CLIENT_ID='...'
```

For Android, also pass `CIYUE_GOOGLE_ANDROID_SERVER_CLIENT_ID`; for OneDrive Android, pass the `CIYUE_MICROSOFT_ANDROID_REDIRECT_URI` generated for that flavor and signing certificate. OAuth credentials are currently not configured in the repository, so real account sign-in still needs an application owner to create these registrations and provide the public IDs.

The first sync remains preview-only until the user confirms. Dictionary packages remain opt-in individually; OAuth authorization itself does not upload user data.

Official setup references:

- [Google Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Google Picker integration](https://developers.google.com/workspace/drive/picker/guides/web-picker)
- [Google Sign-In Android integration](https://pub.dev/packages/google_sign_in_android#integration)
- [Microsoft redirect URI guidance](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [Microsoft Android redirect URI setup](https://learn.microsoft.com/en-us/entra/identity-platform/how-to-add-redirect-uri)
