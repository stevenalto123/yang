import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'emergency_plan_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final bool isEmbedded;

  const EmergencyContactsScreen({super.key, this.isEmbedded = false});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  ContactCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subColor = isDark ? Colors.white70 : AppTheme.mutedSlate;

    final filtered = _selectedCategory == null
        ? emergency.allContacts
        : emergency.allContacts
            .where((c) => c.category == _selectedCategory)
            .toList();

    final content = ResponsiveContainer(
      maxWidth: 960,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // 1. Panic-Proof 1-Tap Emergency Call Hero Cards (911 & 143)
          Row(
            children: [
              Expanded(
                child: _buildEmergencyHeroTile(
                  context: context,
                  number: '911',
                  title: isFil ? 'Pambansang Emergency' : 'National Emergency',
                  subtitle: isFil ? 'Pulis, Bumbero, Medikal' : 'Police, Fire & Medical',
                  color: AppTheme.dangerRed,
                  icon: Icons.call_rounded,
                  onTap: () => ActionFeedback.callWithFeedback(
                    context,
                    emergency,
                    '911',
                    'National Emergency Hotline',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmergencyHeroTile(
                  context: context,
                  number: '143',
                  title: 'PH Red Cross',
                  subtitle: isFil ? 'Ambulansya at Rescue' : 'Ambulance & Rescue',
                  color: AppTheme.eacCrimson,
                  icon: Icons.medical_services_rounded,
                  onTap: () => ActionFeedback.callWithFeedback(
                    context,
                    emergency,
                    '143',
                    'Philippine Red Cross',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Quick GPS SMS Strip + Add Family Contact
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.offline_bolt_outlined,
                        size: 19,
                        color: AppTheme.safeGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFil
                            ? 'Gumagana ang tawag at SMS kahit walang internet'
                            : 'Calls & SMS work without internet',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: headingColor,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.share_location_rounded, size: 17),
                        label: Text(
                          isFil ? 'I-text ang GPS Ko' : 'Text My GPS',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () {
                          final target = emergency.personalContacts.isNotEmpty
                              ? emergency.personalContacts.first.phoneNumber
                              : '911';
                          ActionFeedback.smsWithFeedback(
                            context,
                            emergency,
                            target,
                            'EMERGENCY (${emergency.emergencyPlan.householdName}): Need help. My GPS location: https://maps.google.com/?q=${emergency.userLat.toStringAsFixed(5)},${emergency.userLng.toStringAsFixed(5)}',
                          );
                        },
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                        label: Text(
                          isFil ? 'Dagdag Contact' : 'Add Family',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () => _showAddPersonalContactDialog(
                          context,
                          emergency,
                          isFil,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (!widget.isEmbedded) ...[
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryNavy.withAlpha(22),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                title: Text(
                  isFil ? 'Plano ng Pamilya' : 'My Household Emergency Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
                subtitle: Text(
                  '${isFil ? 'Tagpuan' : 'Meeting point'}: ${emergency.emergencyPlan.primaryMeetingPoint}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subColor),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyPlanScreen(),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 3. Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(isFil ? 'Lahat' : 'All'),
                  selected: _selectedCategory == null,
                  selectedColor: AppTheme.primaryNavy,
                  backgroundColor:
                      isDark ? AppTheme.darkElevated : Colors.white,
                  labelStyle: TextStyle(
                    color: _selectedCategory == null
                        ? Colors.white
                        : headingColor,
                    fontWeight: _selectedCategory == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...ContactCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.displayName),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryNavy,
                      backgroundColor:
                          isDark ? AppTheme.darkElevated : Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : headingColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Contacts List
          ...filtered.map(
            (contact) => _buildContactCard(
              context,
              contact,
              emergency,
              isDark,
              headingColor,
              subColor,
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil ? 'Mga Emergency Hotline' : 'Emergency Hotlines',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: isFil ? 'Dagdag Family Contact' : 'Add Family Contact',
            onPressed: () =>
                _showAddPersonalContactDialog(context, emergency, isFil),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildEmergencyHeroTile({
    required BuildContext context,
    required String number,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(34),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    EmergencyContact contact,
    EmergencyProvider emergency,
    bool isDark,
    Color headingColor,
    Color subColor,
  ) {
    Color badgeColor;
    IconData agencyIcon;

    switch (contact.category) {
      case ContactCategory.nationalHotline:
        badgeColor = AppTheme.dangerRed;
        agencyIcon = Icons.notifications_active_rounded;
        break;
      case ContactCategory.police:
        badgeColor = isDark ? Colors.lightBlueAccent : Colors.indigo.shade600;
        agencyIcon = Icons.local_police_rounded;
        break;
      case ContactCategory.fire:
        badgeColor = Colors.deepOrange;
        agencyIcon = Icons.local_fire_department_rounded;
        break;
      case ContactCategory.medicalAndRedCross:
        badgeColor = AppTheme.dangerRed;
        agencyIcon = Icons.medical_services_rounded;
        break;
      case ContactCategory.disasterManagement:
        badgeColor = isDark ? Colors.tealAccent : Colors.teal.shade700;
        agencyIcon = Icons.shield_rounded;
        break;
      case ContactCategory.familyAndPersonal:
        badgeColor = isDark ? Colors.purpleAccent : Colors.purple.shade700;
        agencyIcon = Icons.family_restroom_rounded;
        break;
    }

    final isCritical = contact.category == ContactCategory.nationalHotline ||
        contact.category == ContactCategory.medicalAndRedCross;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(isDark ? 45 : 22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(agencyIcon, color: badgeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.agencyOrRelationship,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: subColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (contact.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          contact.description,
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!contact.isDefault)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppTheme.dangerRed,
                    ),
                    tooltip: 'Remove Contact',
                    onPressed: () =>
                        emergency.removePersonalContact(contact.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isCritical
                          ? AppTheme.dangerRed
                          : AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text('Call ${contact.phoneNumber}'),
                    onPressed: () => ActionFeedback.callWithFeedback(
                      context,
                      emergency,
                      contact.phoneNumber,
                      contact.name,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.sms_outlined, size: 18),
                  label: const Text('SMS'),
                  onPressed: () => ActionFeedback.smsWithFeedback(
                    context,
                    emergency,
                    contact.phoneNumber,
                    'EMERGENCY: Urgent assistance needed (${emergency.emergencyPlan.householdName}). Location: ${emergency.userLat.toStringAsFixed(4)}, ${emergency.userLng.toStringAsFixed(4)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPersonalContactDialog(
    BuildContext context,
    EmergencyProvider emergency,
    bool isFil,
  ) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil ? 'Magdagdag ng Family Contact' : 'Add Family / Emergency Contact',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isFil ? 'Pangalan *' : 'Contact Name *',
                  hintText: isFil
                      ? 'hal. Tatay, Nanay, Kuya'
                      : 'e.g. Mama, Papa, Kuya, Barangay',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationCtrl,
                decoration: InputDecoration(
                  labelText: isFil ? 'Relasyon' : 'Relationship',
                  hintText: isFil
                      ? 'hal. Magulang, Kapatid, Kapitbahay'
                      : 'e.g. Parent, Sibling, Neighbor',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isFil ? 'Numero ng Telepono *' : 'Mobile Number *',
                  hintText: 'e.g. 09171234567',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              emergency.addPersonalContact(
                EmergencyContact(
                  id: const Uuid().v4(),
                  name: name,
                  agencyOrRelationship: relationCtrl.text.trim().isEmpty
                      ? (isFil ? 'Pamilya' : 'Family')
                      : relationCtrl.text.trim(),
                  phoneNumber: phone,
                  category: ContactCategory.familyAndPersonal,
                  isDefault: false,
                  description: isFil
                      ? 'Personal na Emergency Contact ng Pamilya'
                      : 'Personal Family Emergency Contact',
                ),
              );
              Navigator.pop(ctx);
            },
            child: Text(isFil ? 'I-save' : 'Save Contact'),
          ),
        ],
      ),
    );
  }
}
