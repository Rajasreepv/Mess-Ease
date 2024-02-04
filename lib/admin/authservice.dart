import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Function to save user credentials
  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('email', email);
    prefs.setString('password', password);
  }

  // Function to retrieve user credentials

  static getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? '';
    final password = prefs.getString('password') ?? '';
    return {'email': email, 'password': password};
  }
}
