# Posilka (Parcel) + Push Notification — Flutter integratsiya qo'llanmasi

Bu hujjat **mobil ilova (Flutter)** tarafida qilinishi kerak bo'lgan hamma narsani
yig'ib beradi: posilka (pochta) yuborish/qabul qilish oqimi va push xabarlar
(FCM). Backend allaqachon tayyor — quyidagi endpoint'lar va push hodisalar ishlaydi.

> **Til:** har bir foydalanuvchining tili (`uz` / `ru` / `en`) backend'da saqlanadi.
> API javoblari va push matnlari **avtomatik** o'sha tilda qaytadi — Flutter tarafida
> alohida tarjima qilish shart emas.

---

## 0. Asosiy ma'lumot

| | |
|---|---|
| **Base URL** | `https://<domain>/api/v1` |
| **Auth** | Har bir so'rovda `Authorization: Bearer <token>` header |
| **Format** | So'rov va javob — JSON (`Content-Type: application/json`, `Accept: application/json`) |

### Javob konverti (hamma endpoint uchun bir xil)

**Muvaffaqiyat:**
```json
{
  "status": "success",
  "message": "...",       // foydalanuvchi tilida
  "data": { ... }          // yoki [ ... ]
}
```

**Xato:**
```json
{
  "status": "error",
  "message": "Xatolik matni"   // foydalanuvchi tilida, to'g'ridan-to'g'ri UI'da ko'rsatsa bo'ladi
}
```

HTTP status kodlar: `200` OK, `201` yaratildi, `404` topilmadi, `422` validatsiya/biznes
xatosi, `500` server xatosi. **Har doim `status` maydoniga qarab tekshiring.**

### Posilka endpoint'lari — qisqa ro'yxat

Hammasi `Authorization: Bearer <token>` bilan (`auth:api`). Base: `/api/v1`.

| Metod | Yo'l | Kim | Tavsif | Bo'lim |
|---|---|---|---|---|
| `GET` | `/parcel-types` | Hamma | Posilka turlari (forma uchun) | 2 |
| `POST` | `/client/parcel-bookings` | Mijoz | Posilka yuborish (pickup/dropoff majburiy) | 3.2 |
| `GET` | `/client/parcel-bookings` | Mijoz | Mening posilkalarim (ro'yxat) | 3.3 |
| `GET` | `/client/parcel-bookings/{id}` | Mijoz | Bitta posilka detali | 3.4 |
| `PATCH` | `/client/parcel-bookings/{id}/location` | Mijoz | Pickup/dropoff manzilini yangilash | 3.5 |
| `DELETE` | `/client/parcel-bookings/{id}/cancel` | Mijoz | Posilkani bekor qilish (komissiya bilan) | 3.6 |
| `GET` | `/driver/parcel-bookings` | Haydovchi | Barcha kelgan posilkalar | 4.2 |
| `GET` | `/driver/parcel-bookings/trip/{tripId}` | Haydovchi | Bitta safar posilkalari | 4.2 |
| `GET` | `/driver/trips/{id}` | Haydovchi | Safar detali — `google_map_url` + pickup/dropoff | 4.3 |
| `PATCH` | `/driver/trips/{id}/toggle-parcel-acceptance` | Haydovchi | Safar uchun pochta qabulini yoq/o'chir | 4.4 |

---

## 1. Push Notification (FCM) — eng muhimi

### 1.1. Device token'ni ro'yxatdan o'tkazish

Foydalanuvchi **login qilgandan keyin** (va token yangilanganda — `onTokenRefresh`)
FCM tokenni backend'ga yuboring:

```
POST /api/v1/device-token
Authorization: Bearer <token>

{
  "device_token": "<FCM registration token>",
  "device_platform": "android"   // yoki "ios"
}
```

Javob: `{ "success": true, "message": "Device token saqlandi" }`

**Logout / o'chirishda** tokenni tozalang (bu qurilmaga endi push kelmasin):
```
DELETE /api/v1/device-token
Authorization: Bearer <token>
```

> ⚠️ Token yuborilmasa yoki eskirsa — foydalanuvchiga push **kelmaydi**. Shuning uchun
> `FirebaseMessaging.instance.onTokenRefresh` ni tinglab, har safar yangilang.

### 1.2. Push xabarning strukturasi

Backend har bir push'ni **notification + data** ko'rinishida yuboradi:

- **notification** — `title` va `body` (foydalanuvchi tilida, tayyor matn). Buni faqat
  ko'rsatasiz.
- **data** — navigatsiya (deep-link) uchun. **Barcha qiymatlar `String`** (FCM talabi).
  Har doim `event` kaliti bo'ladi — u qaysi hodisa ekanini bildiradi.

Misol `data` payload (posilka bekor qilinganda):
```json
{
  "event": "parcel.cancelled_by_admin",
  "trip_id": "42",
  "parcel_booking_id": "108"
}
```

### 1.3. Flutter tarafida qanday ishlatish

`data['event']` ga qarab kerakli ekranga o'ting. Namuna:

```dart
void handleMessageTap(RemoteMessage message) {
  final data = message.data;
  final event = data['event'];

  switch (event) {
    // === Mijozga (posilka egasi) ===
    case 'parcel.cancelled_by_admin':   // admin bekor qildi, pul to'liq qaytdi
    case 'parcel.disabled':             // haydovchi pochta qabulini o'chirdi
      openParcelBooking(int.parse(data['parcel_booking_id']!));
      break;

    // === Haydovchiga ===
    case 'parcel.new':                       // yangi posilka keldi
    case 'parcel.cancelled_by_client':       // mijoz o'zi bekor qildi
    case 'parcel.cancelled_by_admin_driver': // admin bekor qildi
      openTripParcels(int.parse(data['trip_id']!));
      break;

    // === Booking (yo'lovchi) hodisalari ===
    case 'booking.new':
    case 'booking.passenger_added':
    case 'booking.cancelled_by_client':
    case 'booking.passenger_removed':
    case 'booking.passenger_cancelled_by_admin':
      openTrip(int.parse(data['trip_id']!));
      break;

    case 'trip.cancelled_by_admin':          // safar admin tomonidan bekor qilindi
      openTrip(int.parse(data['trip_id']!));
      break;
  }
}
```

Uchta holatni ham qamrab oling:
- **Foreground** (`FirebaseMessaging.onMessage`) — o'zingiz local notification ko'rsatasiz.
- **Background tap** (`FirebaseMessaging.onMessageOpenedApp`).
- **Terminated'dan ochilish** (`FirebaseMessaging.instance.getInitialMessage`).

### 1.4. Push hodisalar to'liq ro'yxati (reference)

| `event` kaliti | Kimga boradi | Qachon | `data` kalitlari |
|---|---|---|---|
| `parcel.new` | Haydovchi | Mijoz safarga posilka yubordi | `trip_id`, `parcel_booking_id` |
| `parcel.cancelled_by_client` | Haydovchi | Mijoz o'z posilkasini bekor qildi | `trip_id`, `parcel_booking_id` |
| `parcel.disabled` | Mijoz | Haydovchi/admin pochta qabulini o'chirdi (posilka bekor bo'ldi, pul qaytdi) | `trip_id` |
| `parcel.cancelled_by_admin` | Mijoz | Admin bitta posilkani bekor qildi — **pul to'liq qaytdi** | `trip_id`, `parcel_booking_id` |
| `parcel.cancelled_by_admin_driver` | Haydovchi | Admin safardagi posilkani bekor qildi | `trip_id`, `parcel_booking_id` |
| `booking.new` | Haydovchi | Yangi buyurtma (o'rin band qilindi) | `trip_id`, `booking_id` |
| `booking.passenger_added` | Haydovchi | Buyurtmaga yangi yo'lovchi qo'shildi | `trip_id`, `booking_id` |
| `booking.cancelled_by_client` | Haydovchi | Mijoz buyurtmani bekor qildi | `trip_id` |
| `booking.passenger_removed` | Haydovchi | Mijoz bitta yo'lovchini bekor qildi | `trip_id`, `booking_id` |
| `booking.passenger_cancelled_by_admin` | Mijoz | Admin bitta yo'lovchini bekor qildi | `trip_id`, `booking_id` |
| `trip.cancelled_by_admin` | Mijoz | Admin safarni bekor qildi (pul qaytadi) | `trip_id` |

> Eslatma: `data` ichidagi qiymatlar **String** bo'lib keladi (`"42"`), Flutter'da
> `int.parse(...)` bilan o'giring.

---

## 2. Posilka turlari (Parcel types)

Posilka yuborish formasida turlarni (checkbox/dropdown) ko'rsatish uchun.

```
GET /api/v1/parcel-types
Authorization: Bearer <token>
```

Javob:
```json
{
  "status": "success",
  "message": "Pochta turlari muvaffaqiyatli olindi",
  "data": [
    { "id": 1, "name": "Hujjat / konvert", "icon": "..." },
    { "id": 2, "name": "O'rta quti",        "icon": "..." }
  ]
}
```

`name` — foydalanuvchi tilida. `id` ni booking yaratishda yuborasiz.

---

## 3. MIJOZ tarafi (posilka yuborish)

### 3.1. Qaysi safar posilka qabul qilishini bilish

Safarlar ro'yxati / detali javobida har bir trip'da quyidagi maydonlar bor:

```json
{
  "id": 42,
  "start_quarter": "Amir Temur MFY",
  "end_quarter": "Tosh Yop MFY",
  "start_time": "2026-07-10 12:00:00",
  "end_time": "2026-07-10 12:30:00",
  "price_per_seat": 50000,
  "available_seats": 3,
  "accepts_parcels": true,
  "parcel": {
    "id": 7,
    "max_weight": 20,
    "available_weight": 18,
    "price_per_kg": 5000,
    "max_length": 60,
    "max_width": 40,
    "max_height": 30,
    "types": [
      { "id": 1, "name": "Hujjat / konvert", "icon": "..." },
      { "id": 2, "name": "O'rta quti",        "icon": "..." }
    ]
  }
}
```

**UI qoidalari:**
- `accepts_parcels == false` yoki `parcel == null` → "Posilkani qo'shish" tugmasini
  yashiring/o'chiring.
- **Narx** = `weight × price_per_kg` (real vaqtda ko'rsating).
- **Og'irlik** ≤ `available_weight` bo'lishi kerak (aks holda 422 qaytadi).
- **O'lcham** (agar `max_length/width/height` to'ldirilgan bo'lsa) — undan oshmasligi kerak.
- Faqat `types` ro'yxatidagi turlarni tanlash mumkin.

### 3.2. Posilka yuborish (booking yaratish)

```
POST /api/v1/client/parcel-bookings
Authorization: Bearer <token>

{
  "trip_id": 42,
  "parcel_type_id": 1,
  "weight": 2,                 // kg, min 0.1
  "length": 30,               // sm, ixtiyoriy
  "width": 20,                // sm, ixtiyoriy
  "height": 15,               // sm, ixtiyoriy
  "receiver_phone": "+998901234569",
  "parcel_description": "Uncha katta bo'lmagan hujjatlar",  // ixtiyoriy, max 150

  // === Olib ketish (pickup) va topshirish (dropoff) nuqtalari — MAJBURIY ===
  "pickup_lat":  41.311081,    // jo'natuvchidan olib ketiladigan nuqta
  "pickup_long": 69.279729,
  "dropoff_lat":  41.325555,   // qabul qiluvchiga topshiriladigan nuqta
  "dropoff_long": 69.228888
}
```

| Maydon | Majburiy | Qoida |
|---|---|---|
| `trip_id` | ✅ | mavjud trip |
| `parcel_type_id` | ✅ | `parcel-types` dan |
| `weight` | ✅ | `numeric`, min `0.1`, ≤ `available_weight` |
| `length` / `width` / `height` | ❌ | butun son, min 1, `max_*` dan oshmasin |
| `receiver_phone` | ✅ | string, max 20 |
| `parcel_description` | ❌ | string, max 150 |
| `pickup_lat` | ✅ | `numeric`, `-90` … `90` |
| `pickup_long` | ✅ | `numeric`, `-180` … `180` |
| `dropoff_lat` | ✅ | `numeric`, `-90` … `90` |
| `dropoff_long` | ✅ | `numeric`, `-180` … `180` |

> 📍 **Koordinatalar majburiy.** Foydalanuvchi xaritadan (yoki qurilma GPS'idan)
> **pickup** (qayerdan olib ketish) va **dropoff** (qayerga topshirish) nuqtalarini
> tanlaydi. Yuborilmasa `422` qaytadi. Bu nuqtalar haydovchi xaritasida (Google Maps
> yo'nalishida) chiziladi — 4.3-bo'limga qarang.

Muvaffaqiyat (`201`) — `data` ichida to'liq booking obyekti qaytadi (pastdagi 3.4
formatida). Pul mijoz balansidan **darhol** yechiladi (haydovchi trip yaratishda posilka
olishga rozi bo'lgani uchun qo'shimcha tasdiq kutilmaydi — status darhol `confirmed`).

**Tez-tez uchraydigan 422 xatolar** (`message` ni UI'da ko'rsating):
- "Bu safar pochta qabul qilmaydi"
- "Safarda faqat X kg bo'sh joy qoldi"
- "Posilka o'lchami haydovchi bagajiga sig'maydi (maks: ...)"
- "Bu safar tanlangan pochta turini qabul qilmaydi"
- "Posilka uchun balansingiz yetarli emas"
- "Safar boshlangani uchun posilka qabul qilinmaydi"
- "The pickup lat field is required." (koordinata yuborilmasa — validatsiya xatosi)

### 3.3. Mening posilkalarim (ro'yxat)

```
GET /api/v1/client/parcel-bookings
Authorization: Bearer <token>
```
`data` — paginatsiya qilingan booking'lar ro'yxati (har biri 3.4 formatida).

### 3.4. Bitta posilka detali

```
GET /api/v1/client/parcel-bookings/{id}
Authorization: Bearer <token>
```

Booking obyekti formati:
```json
{
  "id": 108,
  "status": "confirmed",
  "weight": 2,
  "length": 30, "width": 20, "height": 15,
  "total_price": "10000.00",
  "receiver_phone": "+998901234569",
  "pickup_lat": 41.311081,
  "pickup_long": 69.279729,
  "dropoff_lat": 41.325555,
  "dropoff_long": 69.228888,
  "parcel_description": "Uncha katta bo'lmagan hujjatlar",
  "created_at": "2026-07-09 14:20:00",
  "type": { "id": 1, "name": "Hujjat / konvert", "icon": "..." },
  "trip": {
    "id": 42,
    "start_region": "...", "end_region": "...",
    "start_district": "...", "end_district": "...",
    "start_quarter": "...", "end_quarter": "...",
    "start_time": "2026-07-10 12:00:00",
    "end_time": "2026-07-10 12:30:00",
    "status": "active"
  },
  "sender": { "id": 5, "first_name": "Ramziddin", "last_name": "Rustamov", "phone": "+998997713909" },
  "driver": { "id": 9, "first_name": "...", "last_name": "...", "phone": "..." }
}
```

### 3.5. Posilka manzilini (pickup/dropoff) yangilash

Foydalanuvchi xaritadan tanlagan pickup/dropoff nuqtasini keyin o'zgartirmoqchi bo'lsa:

```
PATCH /api/v1/client/parcel-bookings/{id}/location
Authorization: Bearer <token>

{
  "pickup_lat":  41.311081,
  "pickup_long": 69.279729,
  "dropoff_lat":  41.325555,
  "dropoff_long": 69.228888
}
```

| Maydon | Majburiy | Qoida |
|---|---|---|
| `pickup_lat` | ✅ | `numeric`, `-90` … `90` |
| `pickup_long` | ✅ | `numeric`, `-180` … `180` |
| `dropoff_lat` | ✅ | `numeric`, `-90` … `90` |
| `dropoff_long` | ✅ | `numeric`, `-180` … `180` |

**Qoidalar:**
- Faqat `pending` / `confirmed` holatdagi posilka uchun.
- Faqat **safar boshlanishidan oldin** o'zgartirish mumkin (aks holda `422`:
  "Safar boshlangani uchun manzilni o'zgartirib bo'lmaydi").
- To'rttala koordinata ham yuborilishi shart.

Muvaffaqiyat (`200`) — `data` ichida yangilangan booking obyekti qaytadi (3.4 formati).

### 3.6. Posilkani bekor qilish (mijoz o'zi)

```
DELETE /api/v1/client/parcel-bookings/{id}/cancel
Authorization: Bearer <token>
```

**Qoidalar:**
- Faqat `pending` / `confirmed` holatdagi posilka bekor qilinadi.
- **Faqat safar boshlanishidan oldin** — safar boshlangan bo'lsa `422`:
  "Safar boshlangani uchun posilkani bekor qilib bo'lmaydi".
- Bekor bo'lgach: sig'im tiklanadi va haydovchiga `parcel.cancelled_by_client` push ketadi.

**⚠️ Pul qaytarish — bekor qilish jarimasi bilan** (mijoz o'zi bekor qilganda).
Bu **admin bekor qilishidan farq qiladi** (admin — to'liq qaytaradi, jarimasiz).
To'liq hisob 5-bo'limda; qisqasi 10 000 UZS misolida:

| Kim | Natija |
|---|---|
| **Mijoz** | `9 500` qaytadi (`10 000 − 5% jarima`) |
| **Haydovchi** | olgan netto daromadi qaytarib olinadi, `+100` kompensatsiya qoladi |
| **Kompaniya** | `400` (jarima − haydovchi kompensatsiyasi) o'zida qoladi |

UI'da bekor qilishdan oldin foydalanuvchini **jarima ushlab qolinishi** haqida
ogohlantiring (masalan "Bekor qilsangiz ~5% komissiya ushlanadi").

---

## 4. HAYDOVCHI tarafi

### 4.1. Safar yaratishda posilka sozlamalari

Safar (trip) yaratish so'rovida (`POST /api/v1/driver/trips`) posilka bloklari:

```json
{
  "...": "boshqa trip maydonlari (start/end, vaqt, narx, o'rinlar)",
  "accepts_parcels": true,
  "parcel": {
    "max_weight": 20,
    "price_per_kg": 5000,
    "max_length": 60,      // ixtiyoriy
    "max_width": 40,       // ixtiyoriy
    "max_height": 30,      // ixtiyoriy
    "type_ids": [1, 2]     // qaysi turlarni qabul qiladi (parcel-types dan)
  }
}
```

| Maydon | Qoida |
|---|---|
| `accepts_parcels` | ✅ `boolean` (majburiy) |
| `parcel` | `accepts_parcels=true` bo'lsa majburiy |
| `parcel.max_weight` | `accepts_parcels=true` bo'lsa majburiy, `numeric ≥ 0` |
| `parcel.price_per_kg` | `accepts_parcels=true` bo'lsa majburiy, `numeric ≥ 0` |
| `parcel.max_length/width/height` | ixtiyoriy, butun son ≥ 1 |
| `parcel.type_ids` | `accepts_parcels=true` bo'lsa majburiy, kamida 1 ta |

> `accepts_parcels=false` bo'lsa `parcel` blokini umuman yubormaslik mumkin.

### 4.2. Kelgan posilkalarni ko'rish

Barcha safarlariga kelgan posilkalar:
```
GET /api/v1/driver/parcel-bookings
Authorization: Bearer <token>
```

Bitta safar bo'yicha:
```
GET /api/v1/driver/parcel-bookings/trip/{tripId}
Authorization: Bearer <token>
```

`data` — booking'lar ro'yxati (3.4 formati bilan bir xil).

### 4.3. Xaritada yo'nalish — pickup/dropoff nuqtalari

Haydovchi bitta safarni ochganda (`GET /api/v1/driver/trips/{id}`) javobda quyidagilar bor:

- **`google_map_url`** — tayyor Google Maps yo'nalish havolasi. Uni to'g'ridan-to'g'ri
  tashqi Google Maps ilovasida ochsa bo'ladi (`launchUrl`). Tarkibi:
  ```
  origin      = safar boshlanish nuqtasi (start_lat, start_long)
  destination = safar tugash nuqtasi (end_lat, end_long)
  waypoints   = yo'lovchilar olinadigan nuqtalar
              + har bir TASDIQLANGAN posilkaning pickup va dropoff nuqtasi
  ```
  Ya'ni yo'nalish: `boshlanish → pickup1 → dropoff1 → pickup2 → dropoff2 → tugash`.
  > Faqat `status = confirmed` posilkalar qo'shiladi; `cancelled`/`rejected` kirmaydi.

- **`parcel_bookings`** — massiv, har bir posilkada koordinatalar ham bor:
  ```json
  {
    "id": 108,
    "status": "confirmed",
    "receiver_phone": "+998901234569",
    "pickup_lat": 41.311081, "pickup_long": 69.279729,
    "dropoff_lat": 41.325555, "dropoff_long": 69.228888,
    "weight": 2, "length": 30, "width": 20, "height": 15,
    "total_price": "10000.00",
    "type": { "id": 1, "name": "Hujjat / konvert", "icon": "..." },
    "sent_by_user": { "id": 5, "first_name": "...", "phone": "..." }
  }
  ```

Agar ilova ichida o'z xaritangizni chizmoqchi bo'lsangiz — `parcel_bookings` dagi
`pickup_lat/long` va `dropoff_lat/long` ni marker qilib qo'ying va `start_lat/long` →
`end_lat/long` orasida chizing. Aks holda tayyor `google_map_url` ni oching.

### 4.4. Safar uchun pochta qabulini yoqish/o'chirish

Haydovchi mavjud safarda pochta qabulini tez yoqib/o'chirishi uchun (toggle):

```
PATCH /api/v1/driver/trips/{id}/toggle-parcel-acceptance
Authorization: Bearer <token>
```

Har chaqiruvda holat teskarisiga o'zgaradi. Javob:
```json
{
  "status": "success",
  "message": "Endi bu safar uchun pochta qabul qilinadi",
  "data": { "trip_id": 42, "parcel_id": 7, "accepts_parcels": true }
}
```

- Safar topilmasa yoki bu haydovchiniki bo'lmasa → `404`.
- Safarda umuman posilka sozlamasi bo'lmasa (trip yaratishda `accepts_parcels=false`
  bo'lgan) → `404` "Bu safar uchun pochta sozlamasi mavjud emas".
- UI'da `accepts_parcels` qiymatiga qarab switch/toggle holatini yangilang.

---

## 5. Status (holat) qiymatlari va hayot sikli

Posilka `status` maydoni:

| Status | Ma'nosi | UI rang (taklif) |
|---|---|---|
| `pending` | Kutilmoqda (kamdan-kam; odatda darhol `confirmed`) | sariq |
| `confirmed` | Qabul qilingan, to'lov o'tgan | yashil |
| `cancelled` | Bekor qilingan (mijoz/admin), pul qaytarilgan | qizil |
| `rejected` | Rad etilgan | qizil |
| `delivered` | Yetkazib berilgan | ko'k / kulrang |

**Bekor qilish qoidasi:** faqat `pending` / `confirmed` holatdagi posilkani, **faqat
safar boshlanishidan oldin** bekor qilib bo'ladi. `cancelled` / `rejected` — o'zgarmaydi.

### Pul mantig'i — kim bekor qilganiga bog'liq

Ikki xil ssenariy bor, ular **turlicha** hisoblanadi:

#### A) Mijoz o'zi bekor qildi (`DELETE .../cancel`) — jarima bilan
Booking narxi bekor qilish paytida quyidagicha bo'linadi (foizlar backend `.env` da,
hozir: jarima `5%`, haydovchi kompensatsiyasi `1%`):

| Kim | O'zgarish (misol: `total_price = 10 000`) |
|---|---|
| **Mijoz** | `9 500` qaytadi — `total_price − 5% jarima` |
| **Haydovchi** | olgan netto daromadi qaytarib olinadi, `+100` (1%) kompensatsiya qoladi |
| **Kompaniya** | `400` (jarima `500` − kompensatsiya `100`) o'zida qoladi |

→ UI'da mijozni bekor qilishdan oldin **komissiya ushlanishi** haqida ogohlantiring.

#### B) Admin bekor qildi — to'liq, jarimasiz ("zarar yo'q")
- Mijozga **to'liq summa** (`total_price`) qaytariladi.
- Haydovchidan faqat olgan netto daromadi yechiladi — **jarima yo'q**.
- Ikki taraf ham zarar ko'rmaydi.

UI'da `parcel.cancelled_by_admin` push kelganda foydalanuvchiga
"Pul to'liq qaytarildi" deb aniq ko'rsating (push body'da ham shu yozilgan).

---

## 6. Qisqacha checklist (Flutter dev uchun)

- [ ] FCM sozlash + `POST /device-token` (login'da va `onTokenRefresh`da).
- [ ] Logout'da `DELETE /device-token`.
- [ ] Push handler: foreground / background-tap / terminated — uchalasi.
- [ ] `data['event']` bo'yicha deep-link (1.3 va 1.4 jadval).
- [ ] `GET /parcel-types` — forma uchun.
- [ ] Trip kartasi: `accepts_parcels` / `parcel` bo'lsa "Posilka yuborish" tugmasi.
- [ ] Booking forma: narx = `weight × price_per_kg`, `available_weight` va o'lcham cheklovi.
- [ ] **Xaritadan pickup va dropoff nuqta tanlash** (majburiy) — `POST` da yuborish.
- [ ] `POST /client/parcel-bookings` + 422 xatolarni `message` bilan ko'rsatish.
- [ ] "Mening posilkalarim" ro'yxati + detal.
- [ ] **Manzilni yangilash** — `PATCH .../location` (safar boshlanmasidan oldin).
- [ ] **Bekor qilish** — `DELETE .../cancel` + komissiya ogohlantirishi (safar boshlanmasidan oldin).
- [ ] Haydovchi: trip yaratishda posilka bloki; kelgan posilkalar ro'yxati.
- [ ] Haydovchi: `google_map_url` ni ochish **yoki** `parcel_bookings` pickup/dropoff'ni xaritada marker qilish (4.3).
- [ ] Status ranglari (5-bo'lim).

---

*Savol bo'lsa backend jamoasiga yozing. Barcha endpoint'lar `auth:api` (Bearer token)
himoyasida — token yuborilmasa `401` qaytadi.*
