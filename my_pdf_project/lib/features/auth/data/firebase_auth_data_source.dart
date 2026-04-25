import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/user_model.dart';

class FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthDataSource(this._auth, this._firestore);

  Future<UserModel> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _fetchUser(cred.user!.uid);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = UserModel(uid: cred.user!.uid, name: name, email: email);
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
    return user;
  }

  Future<void> logout() => _auth.signOut();

  Stream<UserModel?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _fetchUser(user.uid);
    });
  }

  UserModel? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserModel(uid: user.uid, name: user.displayName ?? '', email: user.email ?? '');
  }

  Future<UserModel> _fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data()!;
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
    );
  }
}
