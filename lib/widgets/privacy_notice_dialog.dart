import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PrivacyNoticeDialog {
  static void show(BuildContext context, {bool isFil = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined,
                color: AppTheme.primaryNavy, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isFil
                    ? 'Abiso sa Privacy (RA 10173)'
                    : 'Data Privacy Notice (RA 10173)',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFil
                    ? 'Sumusunod ang LifeCheckpoint (Emilio Aguinaldo College) sa Republic Act No. 10173 (Data Privacy Act of 2012).'
                    : 'LifeCheckpoint (Emilio Aguinaldo College) complies with Republic Act No. 10173 (Philippine Data Privacy Act of 2012).',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _section(
                isFil ? '1. Datos na Kinokolekta' : '1. Data We Collect',
                isFil
                    ? '• Opsyonal na Account: Pangalan at email (kung pipiliin mag-Cloud Sync).\n'
                      '• Datos ng Sambahayan: Go-Bag checklist, petsa ng expiration, plano ng pamilya, at check-in logs.\n'
                      '• GPS Coordinates: Ginagamit lamang kapag pinindot ang Locate Me o Emergency SMS.\n'
                      '• ISO/IEC 25010 Survey: Mga iskor ng usability at kahandaan para sa pananaliksik.'
                    : '• Optional Account: Full name and email (only if you enable Cloud Sync).\n'
                      '• Household Data: Go-Bag supplies, expiry dates, emergency plan, and safety check-ins.\n'
                      '• GPS Coordinates: Accessed only on demand for nearest shelters, local weather, or Emergency SMS.\n'
                      '• ISO/IEC 25010 Evaluation: Anonymized ratings used solely for EAC capstone evaluation.',
              ),
              const SizedBox(height: 10),
              _section(
                isFil ? '2. Seguridad at Imbakan' : '2. Security & Storage',
                isFil
                    ? '• Ang lahat ng komunikasyon sa cloud ay protektado ng HTTPS/TLS.\n'
                      '• Ang password ay naka-hash (scrypt) at ang database ay protektado ng Row-Level Security (RLS) at Role-Based Access Control (RBAC).\n'
                      '• Walang third-party ads o pagbebenta ng personal na impormasyon.'
                    : '• All cloud sync traffic is encrypted in transit via HTTPS/TLS.\n'
                      '• Passwords are salted & hashed (scrypt), and cloud tables enforce PostgreSQL Row-Level Security (RLS) and Role-Based Access Control (RBAC).\n'
                      '• Zero third-party trackers or commercial sharing.',
              ),
              const SizedBox(height: 10),
              _section(
                isFil ? '3. Iyong mga Karapatan (RA 10173)' : '3. Your Rights Under RA 10173',
                isFil
                    ? 'May karapatan kang malaman, tingnan, itama, o burahin ang iyong lokal na datos anumang oras gamit ang "Erase Local Data" sa Account & Cloud Sync.'
                    : 'You retain the right to be informed, access, rectify, or erase your local personal data anytime via "Erase Local Device Data" in Account & Cloud Sync, or use Guest Offline Mode without creating an account.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFil ? 'Naiintindihan Ko' : 'Understood'),
          ),
        ],
      ),
    );
  }

  static Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
  }
}
