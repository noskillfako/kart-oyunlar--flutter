import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthLinkResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;
  final User? user;

  AuthLinkResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.errorMessage,
    this.user,
  });

  factory AuthLinkResult.success(User? user) =>
      AuthLinkResult._(isSuccess: true, isCancelled: false, user: user);

  factory AuthLinkResult.cancelled() =>
      AuthLinkResult._(isSuccess: false, isCancelled: true);

  factory AuthLinkResult.error(String message) =>
      AuthLinkResult._(isSuccess: false, isCancelled: false, errorMessage: message);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isLinkedWithGoogle {
    final user = currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  String? get googleEmail {
    final user = currentUser;
    if (user == null) return null;
    final googleProvider = user.providerData.where((p) => p.providerId == 'google.com');
    if (googleProvider.isEmpty) return null;
    return googleProvider.first.email;
  }

  Future<User?> signInAnonymously() async {
    if (currentUser != null) return currentUser;
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      // ignore: avoid_print
      print('Anonim giriş hatası: $e');
      return null;
    }
  }

  /// Mevcut anonim hesabı Google hesabına bağlar.
  /// Başarılı olursa UID DEĞİŞMEZ — tüm oda/skor geçmişi korunur.
  Future<AuthLinkResult> linkWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthLinkResult.cancelled();
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = currentUser;

      if (user != null && user.isAnonymous) {
        final result = await user.linkWithCredential(credential);
        return AuthLinkResult.success(result.user);
      } else {
        final result = await _auth.signInWithCredential(credential);
        return AuthLinkResult.success(result.user);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        return AuthLinkResult.error(
          'Bu Google hesabı zaten başka bir oyuncuya bağlı.',
        );
      }
      return AuthLinkResult.error(e.message ?? 'Beklenmeyen bir hata oluştu.');
    } catch (e) {
      return AuthLinkResult.error('Bağlantı sırasında bir hata oluştu.');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}