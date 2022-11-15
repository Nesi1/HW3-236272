import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum Status {
  unAuthenticated,
  Authenticating,
  authenticated,
}

class AuthNotifier extends ChangeNotifier {

  final _auth = FirebaseAuth.instance;
  Status _status = Status.unAuthenticated;
  User? _user;

  Status get status => _status;

  AuthNotifier(){
    _auth.authStateChanges().listen( (User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _status = Status.unAuthenticated;
      }
      else {
        _user = firebaseUser;
        _status = Status.authenticated;
      }
      notifyListeners();
    } );
  }

  String? getUid() => _user?.uid.characters.string;

  String getEmail() => _user?.email??'';

  bool isAuthenticated() => (_status == Status.authenticated);

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
    }
    catch (e) {
      _status = Status.unAuthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return true;
    }
    catch (e) {
      _status = Status.unAuthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signOut() async {
    try {
      _status = Status.unAuthenticated;
      notifyListeners();
      await _auth.signOut();
      return true;
    }
    catch (e) {
      _status = Status.unAuthenticated;
      return false;
    }
}

}