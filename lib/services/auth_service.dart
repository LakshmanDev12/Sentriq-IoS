import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref(AppConstants.users);
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: "589823919242-0b66u7dv2m35aei69577vrcg97ma2hs9.apps.googleusercontent.com",
  );

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signUpWithEmail(String email, String password, String name) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (credential.user != null) {
      UserModel userModel = UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
      );
      await _usersRef.child(credential.user!.uid).set(userModel.toJson());
    }
    return credential;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Force account selection
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      print("GOOGLE USER = $googleUser");

      if (googleUser == null) {
        print("USER CANCELLED LOGIN");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      print("ACCESS TOKEN = ${googleAuth.accessToken}");
      print("ID TOKEN = ${googleAuth.idToken}");

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final snap = await _usersRef.child(uid).get();
        
        // If user doesn't exist in database, create entry
        if (!snap.exists) {
          UserModel userModel = UserModel(
            uid: uid,
            name: userCredential.user!.displayName ?? "User",
            email: userCredential.user!.email ?? "",
          );
          await _usersRef.child(uid).set(userModel.toJson());
        }
      }
      
      return userCredential;
    } catch (e, s) {
      print("GOOGLE SIGN IN ERROR");
      print(e);
      print(s);
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
