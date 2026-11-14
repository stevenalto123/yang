import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import 'action_feedback.dart';
import 'app_strings.dart';
import 'app_theme.dart';

class SosSheet {
  static void show(BuildContext context) {
    final emergency = context.read<EmergencyProvider>();
    final isFil = context.read<SettingsProvider>().isFilipino;
    final s = AppStrings(isFil);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.dangerRed, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.sosDispatchTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isFil
                    ? 'Direktang tawag o SMS kahit walang mobile data o internet.'
                    : 'Direct cellular call/SMS — works without active internet or data.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      fontSize: 13.5,
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),
              ),
              const Divider(height: 24),
              ListTile(
                minVerticalPadding: 10,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.phone, color: AppTheme.dangerRed),
                ),
                title: const Text('Call National Emergency 911',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Police, Fire, Medical nationwide dispatch'),
                trailing: const Icon(Icons.call, color: AppTheme.dangerRed),
                onTap: () {
                  Navigator.pop(ctx);
                  ActionFeedback.callWithFeedback(
                      context, emergency, '911', 'National Emergency 911');
                },
              ),
              ListTile(
                minVerticalPadding: 10,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.medical_services,
                      color: AppTheme.dangerRed),
                ),
                title: const Text('Call Philippine Red Cross 143',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Ambulance and humanitarian rescue'),
                trailing: const Icon(Icons.call, color: AppTheme.dangerRed),
                onTap: () {
                  Navigator.pop(ctx);
                  ActionFeedback.callWithFeedback(
                      context, emergency, '143', 'Philippine Red Cross');
                },
              ),
              ListTile(
                minVerticalPadding: 10,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.sms, color: AppTheme.safeGreen),
                ),
                title: Text(
                  isFil
                      ? 'Magpadala ng Emergency SMS'
                      : 'Send Emergency Distress SMS',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                    'Includes GPS coordinates & household name'),
                trailing: const Icon(Icons.send, color: AppTheme.safeGreen),
                onTap: () {
                  Navigator.pop(ctx);
                  final firstContact = emergency.personalContacts.isNotEmpty
                      ? emergency.personalContacts.first.phoneNumber
                      : '911';
                  ActionFeedback.smsWithFeedback(
                    context,
                    emergency,
                    firstContact,
                    'EMERGENCY (${emergency.emergencyPlan.householdName}): Need urgent assistance! GPS: ${emergency.userLat.toStringAsFixed(4)}, ${emergency.userLng.toStringAsFixed(4)}',
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
