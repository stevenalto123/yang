import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kit_provider.dart';
import '../providers/emergency_provider.dart';
import '../utils/app_theme.dart';
import 'kit_management_screen.dart';
import 'disaster_guide_screen.dart';
import 'emergency_contacts_screen.dart';
import 'evacuation_map_screen.dart';
import 'self_assessment_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final emergency = context.read<EmergencyProvider>();

    final readiness = kit.readinessPercentage;
    final expiredCount = kit.expiredItemsCount;
    final expiringSoonCount = kit.expiringSoonItemsCount;
    final missingCount = kit.missingItemsCount;

    Color scoreColor;
    if (readiness >= 85) {
      scoreColor = AppTheme.safeGreen;
    } else if (readiness >= 50) {
      scoreColor = AppTheme.warningAmber;
    } else {
      scoreColor = AppTheme.accentAlert;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LifeCheckpoint',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Disaster Preparedness & Kit Monitor',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.white, size: 28),
            tooltip: 'Emergency SOS Call (911)',
            onPressed: () => _showEmergencyDialog(context, emergency),
          ),
        ],
      ),
      body: kit.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => kit.loadItems(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Institutional EAC Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCrimson.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryCrimson.withAlpha(51)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.school, size: 16, color: AppTheme.primaryCrimson),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Emilio Aguinaldo College • Capstone Research Project',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Readiness Score Card
                    _buildReadinessCard(context, kit, readiness, scoreColor),
                    const SizedBox(height: 14),

                    // Critical Expiration & Missing Alerts
                    if (expiredCount > 0 || expiringSoonCount > 0)
                      _buildAlertBanner(context, kit, expiredCount, expiringSoonCount),

                    const SizedBox(height: 18),
                    const Text(
                      'Core System Modules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Navigation Action Grid
                    _buildQuickActionGrid(context, kit, missingCount, expiredCount),

                    const SizedBox(height: 20),

                    // Immediate Emergency Dispatch Tile
                    _buildSosTile(context, emergency),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadinessCard(
      BuildContext context, KitProvider kit, double readiness, Color scoreColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Circular progress indicator
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: readiness / 100,
                    strokeWidth: 9,
                    backgroundColor: Colors.grey.shade200,
                    color: scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${readiness.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          'READY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            // Readiness Status Breakdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kit.readinessStatus,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${kit.packedItemsCount} of ${kit.totalItemsCount} items ready for a 72-hour emergency.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SelfAssessmentScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Readiness Assessment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCrimson,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryCrimson),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, KitProvider kit, int expired, int expiringSoon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: expired > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expired > 0 ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            expired > 0 ? Icons.error_outline : Icons.schedule,
            color: expired > 0 ? AppTheme.accentAlert : AppTheme.warningAmber,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired > 0
                      ? '$expired expired supply item(s) detected!'
                      : '$expiringSoon item(s) expiring within 30 days!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: expired > 0 ? AppTheme.accentAlert : Colors.brown.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Supplies must be rotated to ensure safety during emergencies.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              kit.setFilterStatus(expired > 0 ? ItemFilterStatus.expired : ItemFilterStatus.expiringSoon);
              onNavigateTab(1); // Go to kit screen
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              foregroundColor: expired > 0 ? AppTheme.accentAlert : AppTheme.warningAmber,
            ),
            child: const Text('Inspect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(
      BuildContext context, KitProvider kit, int missingCount, int expiredCount) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _buildActionTile(
          icon: Icons.checklist_rtl_rounded,
          iconColor: Colors.blue.shade700,
          title: 'Emergency Kit',
          subtitle: '$missingCount missing items',
          badgeText: missingCount > 0 ? '$missingCount to pack' : 'Ready',
          badgeColor: missingCount > 0 ? Colors.orange.shade700 : AppTheme.safeGreen,
          onTap: () => onNavigateTab(1),
        ),
        _buildActionTile(
          icon: Icons.menu_book_rounded,
          iconColor: Colors.purple.shade700,
          title: 'Disaster Guides',
          subtitle: 'Typhoon, Quake, Fire',
          badgeText: '5 Guides',
          badgeColor: Colors.purple.shade700,
          onTap: () => onNavigateTab(2),
        ),
        _buildActionTile(
          icon: Icons.phone_in_talk_rounded,
          iconColor: AppTheme.accentAlert,
          title: 'Hotlines & Contacts',
          subtitle: '911, BFP, PRC, PNP',
          badgeText: 'Offline',
          badgeColor: AppTheme.primaryCrimson,
          onTap: () => onNavigateTab(3),
        ),
        _buildActionTile(
          icon: Icons.map_outlined,
          iconColor: Colors.teal.shade700,
          title: 'Evacuation Shelters',
          subtitle: 'Local safe zones & GPS',
          badgeText: 'Shelters',
          badgeColor: Colors.teal.shade700,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EvacuationMapScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkSlate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSosTile(BuildContext context, EmergencyProvider emergency) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(64),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showEmergencyDialog(context, emergency),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 22,
                  child: Icon(Icons.emergency_share, color: Color(0xFFB71C1C), size: 26),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY SOS DISPATCH',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '1-Tap Direct Call to 911 / Red Cross & SMS Beacon',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context, EmergencyProvider emergency) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAlert, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    'Instant Emergency Dispatch',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Direct cellular connection - works without active internet or data.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.phone, color: AppTheme.accentAlert),
                ),
                title: const Text('Call National Emergency 911', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Nationwide police, fire, rescue dispatch'),
                trailing: const Icon(Icons.call, color: AppTheme.accentAlert),
                onTap: () {
                  Navigator.pop(ctx);
                  emergency.makePhoneCall('911');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEBEE),
                  child: Icon(Icons.medical_services, color: AppTheme.accentAlert),
                ),
                title: const Text('Call Red Cross Hotline 143', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Ambulance and humanitarian rescue'),
                trailing: const Icon(Icons.call, color: AppTheme.accentAlert),
                onTap: () {
                  Navigator.pop(ctx);
                  emergency.makePhoneCall('143');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.sms, color: AppTheme.safeGreen),
                ),
                title: const Text('Send Emergency Distress SMS', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Broadcasts emergency alert message to family contact'),
                trailing: const Icon(Icons.send, color: AppTheme.safeGreen),
                onTap: () {
                  Navigator.pop(ctx);
                  final firstContact = emergency.personalContacts.isNotEmpty
                      ? emergency.personalContacts.first.phoneNumber
                      : '911';
                  emergency.sendEmergencySms(
                    phoneNumber: firstContact,
                    message: 'EMERGENCY: I need urgent assistance due to disaster situation. Please check on me!',
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
