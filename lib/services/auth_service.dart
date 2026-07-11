import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Şu anki giriş yapmış kullanıcı (varsa)
  User? get currentUser => _auth.currentUser;

  /// Kullanıcının giriş durumunu dinlemek için stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Anonim giriş yapar, eğer zaten giriş yapılmışsa mevcut kullanıcıyı döner
  Future<User?> signInAnonymously() async {
    if (currentUser != null) {
      return currentUser;
    }

    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      // ignore: avoid_print
      print('Anonim giriş hatası: $e');
      return null;
    }
  }
}