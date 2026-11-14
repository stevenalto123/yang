import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/emergency_provider.dart';

class ActionFeedback {
  static Future<void> callWithFeedback(
    BuildContext context,
    EmergencyProvider emergency,
    String phoneNumber,
    String label,
  ) async {
    final launched = await emergency.makePhoneCall(phoneNumber);
    if (!launched && context.mounted) {
      _showFallbackDialog(
        context: context,
        title: 'Dial $label',
        detailLabel: 'Hotline Number',
        valueToCopy: phoneNumber,
        explanation:
            'Your current device or browser cannot launch a direct cellular call. Copy the number below to dial manually:',
      );
    }
  }

  static Future<void> smsWithFeedback(
    BuildContext context,
    EmergencyProvider emergency,
    String phoneNumber,
    String message,
  ) async {
    final launched = await emergency.sendEmergencySms(
      phoneNumber: phoneNumber,
      message: message,
    );
    if (!launched && context.mounted) {
      _showFallbackDialog(
        context: context,
        title: 'Emergency SMS Text',
        detailLabel: 'Recipient: $phoneNumber',
        valueToCopy: message,
        explanation:
            'Your browser cannot open an SMS app directly. Copy the emergency message below to send via Messenger or SMS:',
      );
    }
  }

  static Future<void> openMapWithFeedback(
    BuildContext context,
    EmergencyProvider emergency,
    double lat,
    double lng,
    String label,
  ) async {
    final launched = await emergency.openMapLocation(lat, lng, label);
    if (!launched && context.mounted) {
      final coords = '$lat, $lng';
      _showFallbackDialog(
        context: context,
        title: label,
        detailLabel: 'Offline GPS Coordinates',
        valueToCopy: coords,
        explanation:
            'External maps could not be opened (you may be offline). Use the Offline Shelter Radar above or copy the GPS coordinates:',
      );
    }
  }

  static void _showFallbackDialog({
    required BuildContext context,
    required String title,
    required String detailLabel,
    required String valueToCopy,
    required String explanation,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(explanation, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Text(detailLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                valueToCopy,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: valueToCopy));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }
}
