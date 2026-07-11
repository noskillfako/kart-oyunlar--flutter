# Kart Oyunları — Online Multiplayer Pişti

Flutter ve Firebase ile geliştirilmiş, gerçek zamanlı çok oyunculu bir kart oyunu uygulaması. İlk oyun olarak **Pişti** eklendi; mimari, yeni kart oyunlarının kolayca eklenebileceği modüler bir yapı üzerine kurulu.

## Özellikler

- 🔐 Anonim kimlik doğrulama (Firebase Auth)
- 🎮 Gerçek zamanlı çok oyunculu lobi sistemi (oda oluşturma, açık odaları listeleme, katılma)
- 🃏 Sunucu tarafı doğrulanmış oyun mantığı (Cloud Functions) — hile önleme
- 🧠 Modüler oyun motoru mimarisi (`GameEngine<State, Move>`) — yeni oyunlar kolayca eklenebilir
- ✅ Unit test kapsamlı oyun kuralları (Pişti: eşleşme ile toplama, Vale/Bacak, Pişti bonusu, skor hesaplama)
- 👤 Kalıcı oyuncu adı (SharedPreferences)

## Mimari
lib/
engine/          # Oyun bağımsız GameEngine arayüzü + oyuna özel motorlar (pisti/)
models/          # PlayingCard, GameRoom gibi veri modelleri
screens/         # UI ekranları
services/        # Firebase ile konuşan servis katmanı
functions/
index.js         # Cloud Functions: oyun başlatma, hamle doğrulama/uygulama

**Güvenlik yaklaşımı:** Lobi/oda yönetimi client tarafında (Firestore Security Rules ile korunarak) çalışırken, gerçek oyun mantığı (kart dağıtma, hamle doğrulama, hile önleme) tamamen **Cloud Functions** üzerinde, sunucu tarafında çalışır. Oyuncuların elindeki kartlar ve deste, Firestore Security Rules ile diğer oyunculardan tamamen gizlenir.

## Kullanılan Teknolojiler

- **Flutter** (Android)
- **Firebase**: Firestore, Authentication (Anonymous), Cloud Functions (Node.js)
- **State management**: StreamBuilder ile gerçek zamanlı Firestore senkronizasyonu

## Kurulum

1. `flutter pub get`
2. Firebase projenizi bağlamak için `flutterfire configure`
3. `functions/` klasöründe `npm install`
4. `firebase deploy --only functions`
5. `flutter run`

## Yol Haritası

- [ ] Google Sign-In ile hesap bağlama (anonim → kalıcı hesap)
- [ ] İkinci kart oyunu (Batak/King)
- [ ] Arkadaş davet sistemi (oda kodu ile katılma)
- [ ] Liderlik tablosu

## Geliştirici Notu

Bu proje, mobil geliştirme becerilerimi (Flutter, gerçek zamanlı backend entegrasyonu, oyun mantığı tasarımı, test yazımı) göstermek amacıyla sıfırdan geliştirilmiştir.