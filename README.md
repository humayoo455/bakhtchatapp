# Bakht

Bakht is a real-time communications app built with Flutter. It combines Firebase Authentication, Cloud Firestore, Cloud Storage, presence indicators, media messages, voice notes, delivery receipts, contact management, and Agora audio channels in one cross-platform mobile experience.

## Highlights

- Email/password authentication with email verification
- Deterministic one-to-one conversations
- Real-time text, image, and voice-note messages
- Sent, delivered, and seen receipts
- Unread-message counters and typing indicators
- Online presence and last-seen information
- User search and locally saved contact names
- Profile images and editable user profiles
- Agora-powered audio call channels
- Participant-based Firestore and Storage security rules
- Android and iOS platform configuration
- Automated formatting, analysis, tests, and Android debug builds in CI

## Technology

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Cloud Storage for Firebase
- Firebase Cloud Messaging foundation
- Agora RTC Engine
- `record` and `just_audio`
- `image_picker` and `cached_network_image`

## Project structure

```text
lib/
├── core/                 # Theme and reusable utilities
├── features/
│   ├── auth/             # Login, signup, and email verification
│   ├── call/             # Agora audio-call experience
│   ├── chat/             # Conversations and message widgets
│   └── home/             # Chat list and presence
├── profile/              # User profile experience
└── services/             # Contacts and supporting services
```

## Local setup

1. Install the current stable Flutter SDK and Android Studio or Xcode.
2. Clone the repository and install dependencies:

   ```bash
   git clone https://github.com/humayoo455/bakhtchatapp.git
   cd bakhtchatapp
   flutter pub get
   ```

3. Create a Firebase project with Authentication, Firestore, and Storage enabled.
4. Copy the public template and fill it with values from **your own** Firebase
   project. The local file is ignored by Git:

   ```bash
   cp firebase_options.example.json firebase_options.local.json
   ```

   Bakht intentionally contains no live Firebase project configuration. Every
   clone must use its own backend, quota, and billing account.
5. Deploy the included backend rules and indexes:

   ```bash
   firebase use --add
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

6. Run the app:

   ```bash
   flutter run --dart-define-from-file=firebase_options.local.json
   ```

Before distributing a configured build, enable Firebase App Check, enforce it
for supported Firebase products, restrict API keys to the required Firebase
APIs and app identifiers, and configure billing alerts.

## Agora configuration

Set your Agora App ID in `firebase_options.local.json`. If the Agora project
uses an App Certificate, generate short-lived tokens on a trusted backend.
Never commit a production token; the empty token in the template only works
with a test project configured without certificates.

```bash
flutter run --dart-define-from-file=firebase_options.local.json
```

Never place an App Certificate or other server secret in the mobile application.

## Verification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug \
  --dart-define-from-file=firebase_options.example.json
```

The Firebase rules and composite index are versioned alongside the client so backend access control is reviewable and reproducible.

## Author

Built by [Humaiyon Khan](https://github.com/humayoo455).
