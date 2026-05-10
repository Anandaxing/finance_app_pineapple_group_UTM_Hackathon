import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static String generateOTP() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString();
  }

  static Future<bool> sendVerificationEmail(String toEmail, String otp) async {
    final gmailAddress = dotenv.env['GMAIL_ADDRESS'] ?? '';
    final gmailPassword = dotenv.env['GMAIL_APP_PASSWORD'] ?? '';

    final smtpServer = gmail(gmailAddress, gmailPassword);

    final message = Message()
      ..from = Address(gmailAddress, 'Finova App')
      ..recipients.add(toEmail)
      ..subject = 'Your Verification Code'
      ..html = '''
        <div style="font-family: sans-serif; padding: 24px;">
          <h2>Verify your Finova account</h2>
          <p>Your verification code is:</p>
          <h1 style="letter-spacing: 8px; color: #D4AF37;">$otp</h1>
          <p>This code expires in 10 minutes.</p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      print("Email sent to $toEmail");
      return true;
    } catch (e) {
      print("Email send error: $e");
      return false;
    }
  }
}