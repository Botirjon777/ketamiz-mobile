# 📱 Push Notification (FCM) — Mobil (Flutter) integratsiya hujjati

Bu hujjat mobil dasturchi uchun. Backend tomoni **to'liq tayyor**. Sizning
vazifangiz: Flutter app'da FCM'ni sozlash, device tokenni olib backendga
yuborish va kelgan bildirishnomalarni ko'rsatish.

- **Firebase project:** `ketamiz-435ea`
- **Backend base URL:** `http://127.0.0.1:8000` (productionda o'zgaradi)
- **Auth:** JWT (login'dan keyingi `Bearer` token)

---

## 1. Firebase'ni loyihaga ulash

Firebase Console → `ketamiz-435ea` loyihasiga **Android** va **iOS** app qo'shing
(package name / bundle id realdagi bilan bir xil bo'lsin).

**Android:**
1. `google-services.json` faylini yuklab, `android/app/` ichiga qo'ying.
2. `android/build.gradle` → `classpath 'com.google.gms:google-services:4.4.2'`
3. `android/app/build.gradle` → eng pastga: `apply plugin: 'com.google.gms.google-services'`
4. `minSdkVersion` kamida **21**.

**iOS:**
1. `GoogleService-Info.plist` ni Xcode orqali `Runner` ga qo'shing.
2. Xcode → **Signing & Capabilities** → **Push Notifications** va
   **Background Modes → Remote notifications** ni yoqing.
3. Apple Developer'da **APNs key (.p8)** yarating va Firebase Console →
   **Project settings → Cloud Messaging → Apple app configuration** ga yuklang.
   > iOS'da push faqat APNs key ulangandan keyin ishlaydi.

---

## 2. Paketlar (`pubspec.yaml`)

```yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^18.0.1   # foreground'da banner ko'rsatish uchun
```

---

## 3. Ishga tushirish (`main.dart`)

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// App yopiq/fon holatida kelgan xabar shu yerda ushlanadi (top-level bo'lishi shart)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Kerak bo'lsa shu yerda log/local storage
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  runApp(const MyApp());
}
```

---

## 4. Ruxsat so'rash va token olish

**Muhim:** tokenni backendga **faqat foydalanuvchi login qilgandan keyin**
(JWT tayyor bo'lganda) yuboring. Aks holda qaysi userга tegishli ekani noma'lum.

```dart
Future<void> registerFcmToken(String jwt) async {
  final messaging = FirebaseMessaging.instance;

  // iOS/Android 13+ uchun ruxsat
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final token = await messaging.getToken();
  if (token == null) return;

  await _sendTokenToBackend(jwt, token);

  // Token yangilanganda (Firebase vaqti-vaqti bilan yangilaydi) — qayta yuboring
  messaging.onTokenRefresh.listen((newToken) => _sendTokenToBackend(jwt, newToken));
}
```

---

## 5. Backend endpointlari (SHARTNOMA)

### ➕ Tokenni saqlash / yangilash

```
POST /api/v1/device-token
Headers:
  Authorization: Bearer <JWT>
  Content-Type: application/json
  Accept: application/json
Body:
  {
    "device_token": "<FCM_TOKEN>",
    "device_platform": "android"   // yoki "ios"
  }
```

**Javob (200):**
```json
{ "success": true, "message": "Device token saqlandi" }
```

### 🗑 Logout'da tokenni o'chirish

Logout qilganda shu qurilmaga endi push kelmasligi uchun:

```
DELETE /api/v1/device-token
Headers:
  Authorization: Bearer <JWT>
  Accept: application/json
```

**Javob (200):**
```json
{ "success": true, "message": "Device token o'chirildi" }
```

### Flutter'da yuborish namunasi (dio bilan)

```dart
Future<void> _sendTokenToBackend(String jwt, String token) async {
  await dio.post(
    'http://127.0.0.1:8000/api/v1/device-token',
    data: {
      'device_token': token,
      'device_platform': Platform.isIOS ? 'ios' : 'android',
    },
    options: Options(headers: {
      'Authorization': 'Bearer $jwt',
      'Accept': 'application/json',
    }),
  );
}
```

> Logout funksiyangizda `dio.delete('.../api/v1/device-token', ...)` ni JWT
> hali amal qilayotganda (tokenni o'chirishdan **oldin**) chaqiring.

---

## 6. Kelgan bildirishnomalarni ko'rsatish

Backend quyidagi ko'rinishda yuboradi:

```jsonc
{
  "notification": { "title": "Sarlavha", "body": "Xabar matni" },
  "data": {
    "type": "broadcast",       // yoki "test"
    "broadcast_id": "123"      // e'lon id (string)
  }
}
```

- **App yopiq / fon holatida:** tizim bildirishnomasini Android/iOS **avtomatik**
  ko'rsatadi (siz hech narsa qilmaysiz). Foydalanuvchi bosganда app ochiladi.
- **App ochiq (foreground) holatida:** tizim banner ko'rsatmaydi — buni o'zingiz
  `flutter_local_notifications` bilan chiqarasiz:

```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  final n = message.notification;
  if (n != null) {
    // flutter_local_notifications orqali banner ko'rsating
    showLocalNotification(n.title ?? '', n.body ?? '');
  }
});

// Foydalanuvchi bildirishnomani bosib app'ni ochsa
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final type = message.data['type'];
  // Masalan: e'lonlar ekraniga o'tkazish
});
```

Android'da foreground banner uchun **notification channel** yarating
(`flutter_local_notifications` hujjatiga qarang).

---

## 7. Test qilish

1. App'ni telefonда ishga tushiring, login qiling.
2. Debug konsolda tokenni chop eting: `print(await FirebaseMessaging.instance.getToken());`
3. Backend jamoasiga o'sha tokenni bering — ular
   `php artisan fcm:test "<TOKEN>"` bilan sinov push yuborishadi.
4. Yoki admin panel → **E'lonlar (Push)** dan e'lon yuboriladi — telefonда
   bildirishnoma chiqishi kerak.

> Test paytida app **fon** yoki **yopiq** bo'lsin — shunda tizim banneri ko'rinadi.

---

## Qisqacha checklist ✅

- [ ] `google-services.json` (Android) + `GoogleService-Info.plist` (iOS) qo'shildi
- [ ] iOS uchun APNs key Firebase'ga ulandi
- [ ] `firebase_core`, `firebase_messaging` o'rnatildi
- [ ] Ruxsat so'raladi, token olinadi
- [ ] Login'dan keyin `POST /api/v1/device-token` chaqiriladi
- [ ] `onTokenRefresh` da token qayta yuboriladi
- [ ] Logout'da `DELETE /api/v1/device-token` chaqiriladi
- [ ] Foreground / background / terminated holatlarda xabar ko'rsatiladi
