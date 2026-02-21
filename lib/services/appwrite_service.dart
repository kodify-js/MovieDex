import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:moviedex/api/secrets.dart' as secrets;
class AppwriteService {
  static final AppwriteService instance = AppwriteService._internal();
  late final Client client;
  late final Account account;
  late final TablesDB tablesDB;
  
  // Replace with your Appwrite endpoint and project ID
  static const String _endpoint = 'https://cloud.appwrite.io/v1';
  static const String _projectId = secrets.projectId;
  static const String _databaseId = secrets.databaseId;

  // Collection IDs
  static const String watchHistoryCollection = secrets.watchHistoryCollection;
  static const String userListCollection = secrets.userListCollection;

  AppwriteService._internal() {
    client = Client()
      .setEndpoint(_endpoint)
      .setProject(_projectId)
      .setSelfSigned();
    
    account = Account(client);
    tablesDB = TablesDB(client);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      await account.get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get current user
  Future<User> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      rethrow;
    }
  }

  // Create user session
  Future<Session> createEmailSession(String email, String password) async {
    try {
      final user =  await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Create new user
  Future<User> createUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      return await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Delete current session
  Future<void> deleteCurrentSession() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await account.createRecovery(
        email: email,
        url: 'https://yourdomain.com/reset-password',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Database operations
  Future<Row> createDocument({
    required String collectionId,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    return await tablesDB.createRow(
      databaseId: _databaseId,
      tableId: collectionId,
      rowId: documentId ?? ID.unique(),
      data: data,
    );
  }

  Future<Row> getDocument({
    required String collectionId,
    required String documentId,
  }) async {
    return await tablesDB.getRow(
      databaseId: _databaseId,
      tableId: collectionId,
      rowId: documentId,
    );
  }

  Future<void> deleteDocument({
    required String collectionId,
    required String documentId,
  }) async {
    await tablesDB.deleteRow(
      databaseId: _databaseId,
      tableId: collectionId,
      rowId: documentId,
    );
  }

  Future<RowList> listDocuments({
    required String collectionId,
    List<String>? queries,
  }) async {
    return await tablesDB.listRows(
      databaseId: _databaseId,
      tableId: collectionId,
      queries: queries,
    );
  }
}
