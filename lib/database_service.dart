import 'package:libsql_dart/libsql_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  // Define the client here
  // Use 'late' so it doesn't initialize until the first time you call it
  // late final client = LibsqlClient(dotenv.env['TURSO_DATABASE_URL'] ?? '')
  //   ..authToken = dotenv.env['TURSO_AUTH_TOKEN'];
  late final LibsqlClient client = (() {
    final url = dotenv.env['TURSO_DATABASE_URL'] ?? '';
    final token = dotenv.env['TURSO_AUTH_TOKEN'] ?? '';

    return LibsqlClient(url)..authToken = token;
  })();

  // Example method to fetch data from your online DB
  Future<void> testConnection() async {
    try {
      print("Attempting to connect to: ${dotenv.env['TURSO_DATABASE_URL']}");

      await client.connect();

      // final result = await client.execute("SELECT * FROM user_identity");
      final result = await client.query("SELECT * FROM user_identity");
      print("Remote connection result: $result");
    } catch (e) {
      print("Connection failed: $e");
    }
  }
}