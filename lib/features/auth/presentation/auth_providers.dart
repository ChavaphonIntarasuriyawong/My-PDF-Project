import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository_impl.dart';
import '../data/firebase_auth_data_source.dart';
import '../domain/auth_repository.dart';
import '../domain/user_model.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(FirebaseAuthRef ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(FirestoreRef ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
FirebaseAuthDataSource authDataSource(AuthDataSourceRef ref) {
  return FirebaseAuthDataSource(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref.watch(authDataSourceProvider));
}

@Riverpod(keepAlive: true)
Stream<UserModel?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

@Riverpod(keepAlive: true)
Stream<UserModel?> userProfile(UserProfileRef ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        final data = doc.data()!;
        return UserModel(
          uid: uid,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
        );
      });
}
