import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:moviedex/services/appwrite_service.dart';

class AuthService {
  final AppwriteService _appwrite = AppwriteService.instance;

  Future<User> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final user = await _appwrite.createUser(
        email: email,
        password: password,
        name: username,
      );
      
      // Create session after signup
      await _appwrite.createEmailSession(email, password);
      return user;
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _appwrite.createEmailSession(email, password);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _appwrite.deleteCurrentSession();
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _appwrite.account.createRecovery(
        email: email,
        url: 'https://your-domain.com/reset-password',
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(dynamic e) {
    if (e is AppwriteException) {
      switch (e.type) {
        case 'user_already_exists':
          return 'An account already exists with that email.';
        case 'user_invalid_credentials':
          return 'Invalid email or password.';
        case 'user_not_found':
          return 'No user found with that email.';
        default:
          return e.message ?? 'An error occurred. Please try again.';
      }
    }
    return 'An error occurred. Please try again.';
  }
}
