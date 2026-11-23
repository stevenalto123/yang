import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/monitoring_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/survival_tools_screen.dart';
import 'action_feedback.dart';
import 'app_strings.dart';
import 'app_theme.dart';

class SosSheet {
  static void show(BuildContext context) {
    final emergency = context.read<EmergencyProvider>();
    final monitoring = context.read<MonitoringProvider>();
    final auth = context.read<AuthProvider>();
    final isFil = context.read<SettingsProvider>().isFilipino;
    final s = AppStrings(isFil);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.dangerRed,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.sosDispatchTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      ? 'Mabilisang paghingi ng tulong, tawag, GPS link, at survival tools kahit walang internet.'
                      : 'Instant emergency alerts, direct calls, GPS sharing, and offline rescue tools.',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                ),
                const SizedBox(height: 14),

                // 1-Tap Alert Family & DRRM Now
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.dangerRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                    ),
                    icon: const Icon(Icons.emergency_rounded, size: 22),
                    label: Text(
                      isFil
                          ? 'Magpadala ng SOS Alert sa Pamilya at DRRM'
                          : 'Alert Family & DRRM Now (With GPS)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await monitoring.addSafetyCheckIn(
                        'NEED ASSISTANCE',
                        isFil
                            ? 'SOS: Nangangailangan ng agarang tulong sa lokasyong ito.'
                            : 'SOS: Urgent assistance requested from Emergency SOS button.',
                        latitude: emergency.userLat,
                        longitude: emergency.userLng,
                        authorName: auth.fullName ?? 'Household Member',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.dangerRed,
                            content: Text(
                              isFil
                                  ? 'Naipadala ang SOS alert sa pamilya at DRRM (naka-queue kung offline).'
                                  : 'SOS alert logged for your family & DRRM (auto-syncs when online).',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 24),

                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.phone, color: AppTheme.dangerRed),
                  ),
                  title: const Text(
                    'Call National Emergency 911',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle:
                      const Text('Police, Fire, Medical nationwide dispatch'),
                  trailing: const Icon(Icons.call, color: AppTheme.dangerRed),
                  onTap: () {
                    Navigator.pop(ctx);
                    ActionFeedback.callWithFeedback(
                      context,
                      emergency,
                      '911',
                      'National Emergency 911',
                    );
                  },
                ),
                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(
                      Icons.medical_services,
                      color: AppTheme.dangerRed,
                    ),
                  ),
                  title: const Text(
                    'Call Philippine Red Cross 143',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text('Ambulance and humanitarian rescue'),
                  trailing: const Icon(Icons.call, color: AppTheme.dangerRed),
                  onTap: () {
                    Navigator.pop(ctx);
                    ActionFeedback.callWithFeedback(
                      context,
                      emergency,
                      '143',
                      'Philippine Red Cross',
                    );
                  },
                ),
                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8E1),
                    child: Icon(
                      Icons.shield_rounded,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  title: const Text(
                    'Call Manila DRRMO (02) 8568-6909',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'City of Manila 24/7 Rescue • 0932-662-2322 / 0950-700-3710',
                  ),
                  trailing:
                      const Icon(Icons.call, color: Color(0xFFB45309)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ActionFeedback.callWithFeedback(
                      context,
                      emergency,
                      '(02) 8568-6909',
                      'Manila DRRMO',
                    );
                  },
                ),
                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(
                      Icons.share_location_rounded,
                      color: AppTheme.primaryAccent,
                    ),
                  ),
                  title: Text(
                    isFil
                        ? 'Kopyahin ang GPS Link (Messenger / Viber)'
                        : 'Copy Live GPS Map Link (Messenger / Viber)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${emergency.userLat.toStringAsFixed(4)}, ${emergency.userLng.toStringAsFixed(4)}',
                  ),
                  trailing: const Icon(
                    Icons.copy_rounded,
                    color: AppTheme.primaryAccent,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final lat = emergency.userLat.toStringAsFixed(5);
                    final lng = emergency.userLng.toStringAsFixed(5);
                    final hh = emergency.emergencyPlan.householdName;
                    final msg =
                        'EMERGENCY ($hh): Need urgent help! My location: https://maps.google.com/?q=$lat,$lng (GPS: $lat, $lng)';
                    await Clipboard.setData(ClipboardData(text: msg));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.safeGreen,
                          content: Text(
                            isFil
                                ? 'Nakopya ang GPS link — i-paste sa Messenger, Viber, o SMS!'
                                : 'GPS rescue link copied — paste into Messenger, Viber, or SMS!',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.sms, color: AppTheme.safeGreen),
                  ),
                  title: Text(
                    isFil
                        ? 'Magpadala ng Emergency SMS'
                        : 'Send Emergency Distress SMS',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Includes GPS coordinates & household name',
                  ),
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
                ListTile(
                  minVerticalPadding: 8,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF8E1),
                    child: Icon(
                      Icons.flashlight_on_rounded,
                      color: AppTheme.warningAmber,
                    ),
                  ),
                  title: Text(
                    isFil
                        ? 'Offline Rescue Whistle at SOS Light'
                        : 'Offline Rescue Whistle & SOS Light',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    isFil
                        ? 'Malakas na whistle at flashing SOS screen para sa brownout/lindol'
                        : '3.1 kHz rescue whistle & Morse SOS screen strobe',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.warningAmber,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SurvivalToolsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}
