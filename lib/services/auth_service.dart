import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
class AuthService{
    signInWithGoogle() async {
        final GoogleSignInAccound? gUser = await GoogleSignIn().signIn();

        //obtain auth details from request
        final GoogleSignInAuthentication gAuth = awaut gUser!.authenticatication;

        //create a new credential for user
        final credential = GoogleauthProveider.credential(
            accessToken: gAuth.accessToken,
            idToken: gAuth.idToken,
        );

        // finally, lets sign in
        return await FirebaseAuth.instance.signInWithCredential(credential);
    }
}