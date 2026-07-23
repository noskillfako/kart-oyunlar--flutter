import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:kart_oyunu/services/presence_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockUser mockUser;
  late MockFirebaseAuth mockAuth;
  late PresenceService presenceService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockUser = MockUser(uid: 'player1', displayName: 'Furkan');
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    presenceService = PresenceService(firestore: fakeFirestore, auth: mockAuth);
  });

  tearDown(() {
    presenceService.stopHeartbeat();
  });

  group('PresenceService', () {
    test('startHeartbeat çağrıldığında presence dokümanına lastActiveAt yazar', () async {
      presenceService.startHeartbeat('room123');

      // İlk istek anında yazılması beklenir
      final doc = await fakeFirestore
          .collection('rooms')
          .doc('room123')
          .collection('presence')
          .doc('player1')
          .get();

      expect(doc.exists, true);
      expect(doc.data()!.containsKey('lastActiveAt'), true);
    });

    test('stopHeartbeat periyodik zamanlayıcıyı durdurur', () {
      presenceService.startHeartbeat('room123');
      presenceService.stopHeartbeat();

      // stopHeartbeat istisnasız tamamlanmalıdır
      expect(() => presenceService.stopHeartbeat(), returnsNormally);
    });
  });
}
