import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

    // If user cancels the sign-in
    if (gUser == null) return Future.error("Sign-in aborted by user");

    // Obtain auth details from the request
    final GoogleSignInAuthentication gAuth = await gUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // Finally, sign in and return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }
}
