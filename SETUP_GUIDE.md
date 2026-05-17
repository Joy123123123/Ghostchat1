# 👻 GhostChat — সম্পূর্ণ সেটআপ গাইড

## ফাইল স্ট্রাকচার

```
ghostchat/
├── lib/
│   ├── main.dart                  ← এন্ট্রি পয়েন্ট
│   └── screens/
│       ├── auth_screen.dart       ← সাইন-আপ স্ক্রিন
│       ├── home_screen.dart       ← ইউজার লিস্ট
│       └── chat_screen.dart       ← রিয়েল-টাইম চ্যাট
├── pubspec.yaml                   ← ডিপেন্ডেন্সি
└── firestore.rules                ← সিকিউরিটি রুলস
```

---

## ⚡ একদম দ্রুত রেডি করার শর্টকাট

```bash
cd /home/runner/work/Ghostchat1/Ghostchat1
bash scripts/bootstrap_project.sh
```

এতে missing Flutter project scaffolding (android/ios/web/etc.) + dependency install auto হয়ে যাবে।

---

## ধাপ ১: Flutter প্রজেক্ট তৈরি করুন

```bash
cd /home/runner/work/Ghostchat1/Ghostchat1
flutter create . --project-name ghostchat --org com.ghostchat.app
```

এই কমান্ড missing Android/iOS/Web/Desktop project files জেনারেট করবে।

---

## ধাপ ২: Firebase প্রজেক্ট সেটআপ

1. https://console.firebase.google.com এ যান
2. "Add project" → নাম দিন "GhostChat"
3. Google Analytics: Skip করুন (অথবা রাখতে পারেন)
4. প্রজেক্ট তৈরি হলে:

### Authentication চালু করুন:
- Build → Authentication → Get started
- Sign-in method → Email/Password → Enable করুন → Save

### Firestore Database চালু করুন:
- Build → Firestore Database → Create database
- "Start in test mode" → Next → Region: asia-south1 (India, বাংলাদেশের কাছাকাছি) → Enable

---

## ধাপ ৩: FlutterFire CLI দিয়ে Firebase কানেক্ট করুন

```bash
# FlutterFire CLI ইন্সটল
dart pub global activate flutterfire_cli

# Firebase CLI ইন্সটল (না থাকলে)
npm install -g firebase-tools
firebase login

# প্রজেক্টে Firebase কানেক্ট (ghostchat ফোল্ডারে থেকে)
flutterfire configure
```

এটি আপনার প্রজেক্টে `firebase_options.dart` ফাইল তৈরি করবে এবং platform config (যেমন `google-services.json`) যোগ করবে।

---

## ধাপ ৪: Dependencies ইন্সটল করুন

```bash
flutter pub get
```

---

## ধাপ ৫: Security Rules আপডেট করুন

Firebase Console → Firestore → Rules ট্যাবে গিয়ে `firestore.rules` ফাইলের কন্টেন্ট পেস্ট করুন → Publish করুন।

---

## ধাপ ৬: অ্যাপ রান করুন

```bash
# Android এ রান
flutter run

# Release APK বানান (শেয়ার করার জন্য)
flutter build apk --release
# APK পাবেন: build/app/outputs/flutter-apk/app-release.apk
```

---

## Live করার উপায়

### Option A: সরাসরি APK শেয়ার (সহজ)
```
build/app/outputs/flutter-apk/app-release.apk
```
এই ফাইলটি WhatsApp/Telegram-এ শেয়ার করুন। বন্ধুরা ইন্সটল করে ব্যবহার করতে পারবে।

### Option A2: Pull Request করলেই GitHub থেকে APK/ZIP ডাউনলোড
এই রিপোতে `PR Build Artifacts` GitHub Actions workflow যোগ করা হয়েছে।

1. Repo Settings → **Secrets and variables** → **Actions** এ যান
2. নতুন secret দিন: `ANDROID_GOOGLE_SERVICES_JSON_B64`
3. Secret এ আপনি **যেকোনো একটি** দিতে পারেন:
   - `google-services.json` এর raw JSON content (copy-paste)
   - অথবা base64-encoded content
4. base64 দিতে চাইলে:

```bash
base64 -w 0 android/app/google-services.json
```

5. এখন PR open/update করলেই workflow চলবে
6. PR → **Checks** / **Actions** → run খুলে **Artifacts** থেকে ডাউনলোড করুন:
   - `ghostchat-source-<run_number>` (source zip)
   - `ghostchat-android-<run_number>` (APK + ZIP, secret set থাকলে)

> নোট: secret missing/invalid হলে APK job fail না করে skip হবে, কিন্তু source zip artifact আসবে।

### Option B: Web live via GitHub Pages
এই repo-তে `Deploy Flutter Web to GitHub Pages` workflow যোগ করা হয়েছে।

1. `main` branch-এ push করুন (বা Actions থেকে manual run দিন)
2. Repo Settings → **Pages** এ যান
3. **Build and deployment** source হিসেবে **GitHub Actions** সিলেক্ট করুন
4. Workflow সফল হলে web app live হবে:

```
https://joy123123123.github.io/Ghostchat1/
```

> নোট: `https://joy123123123.github.io/` এ না গিয়ে repo path সহ URL ব্যবহার করবেন।

### Option C: Google Play Store
1. https://play.google.com/console → Developer account ($25 one-time)
2. `flutter build appbundle --release` দিয়ে `.aab` ফাইল বানান
3. Play Console-এ আপলোড করুন

### Option D: Apple App Store
1. Apple Developer Program ($99/year)
2. Mac কম্পিউটার প্রয়োজন
3. `flutter build ipa --release`

---

## অ্যাপের Unique Features

| Feature | কীভাবে কাজ করে |
|---------|----------------|
| 👻 Anonymous Login | শুধু নিকনেম — কোনো ফোন/ইমেইল নেই |
| ⚡ Real-time Chat | Firebase Firestore streams |
| ✓✓ Read Receipt | নীল টিক = মেসেজ পড়া হয়েছে |
| 💬 Typing Indicator | টাইপ করলেই ওপাশে দেখায় |
| ❤️ Reactions | Long-press → emoji picker |
| 🟢 Online Status | Real-time online/offline দেখায় |
| 🔔 Unread Badge | Home screen-এ unread count |
| 🌙 Dark Theme | চোখ-বান্ধব pure dark UI |

---

## সমস্যা হলে

**Error: google-services.json not found**
→ `flutterfire configure` আবার রান করুন

**Error: firebase_options.dart missing**
→ `flutterfire configure` আবার চালান এবং generated files প্রজেক্টে রাখুন

**App crash on start**
→ `flutter clean && flutter pub get && flutter run` রান করুন

---

শুভকামনা! 🚀 GhostChat বানিয়ে বন্ধুদের সাথে শেয়ার করুন!
