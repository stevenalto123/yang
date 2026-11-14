import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../providers/emergency_provider.dart';
import '../utils/action_feedback.dart';
import '../utils/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    final filtered = _selectedCategory == null
        ? emergency.allContacts
        : emergency.allContacts
            .where((c) => c.category == _selectedCategory)
            .toList();

    final content = Column(
      children: [
        // Offline notice banner
        Container(
          color: isDark
              ? const Color(0xFF0F291E)
              : const Color(0xFFE8F5E9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.wifi_off,
                  size: 18,
                  color: isDark
                      ? const Color(0xFF4ADE80)
                      : AppTheme.safeGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direct Offline Cellular Dialing • No Internet Required',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFBBF7D0)
                        : Colors.green.shade900,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 40)),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add ICE', style: TextStyle(fontSize: 13)),
                onPressed: () =>
                    _showAddPersonalContactDialog(context, emergency),
              ),
            ],
          ),
        ),

        if (!widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EmergencyPlanScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryNavy,
                      radius: 20,
                      child: const Icon(Icons.home_work,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Household Emergency Plan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Meeting point: ${emergency.emergencyPlan.primaryMeetingPoint}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Contacts'),
                selected: _selectedCategory == null,
                selectedColor: AppTheme.primaryNavy,
                labelStyle: TextStyle(
                  color: _selectedCategory == null
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: _selectedCategory == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 13,
                ),
                onSelected: (_) => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 6),
              ...ContactCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(cat.displayName),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),

        // Contacts List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final contact = filtered[index];
              return _buildContactCard(context, contact, emergency, isDark, subColor);
            },
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_ind_outlined),
            tooltip: 'Household Emergency Plan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmergencyPlanScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Family Contact',
            onPressed: () => _showAddPersonalContactDialog(context, emergency),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    EmergencyContact contact,
    EmergencyProvider emergency,
    bool isDark,
    Color subColor,
  ) {
    Color badgeColor;
    IconData agencyIcon;

    switch (contact.category) {
      case ContactCategory.nationalHotline:
        badgeColor = AppTheme.dangerRed;
        agencyIcon = Icons.notifications_active;
        break;
      case ContactCategory.police:
        badgeColor = isDark ? Colors.lightBlueAccent : Colors.indigo;
        agencyIcon = Icons.local_police;
        break;
      case ContactCategory.fire:
        badgeColor = Colors.deepOrange;
        agencyIcon = Icons.local_fire_department;
        break;
      case ContactCategory.medicalAndRedCross:
        badgeColor = AppTheme.dangerRed;
        agencyIcon = Icons.medical_services;
        break;
      case ContactCategory.disasterManagement:
        badgeColor = isDark ? Colors.tealAccent : Colors.teal.shade800;
        agencyIcon = Icons.shield;
        break;
      case ContactCategory.familyAndPersonal:
        badgeColor = isDark ? Colors.purpleAccent : Colors.purple.shade700;
        agencyIcon = Icons.family_restroom;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: badgeColor.withAlpha(30),
                  radius: 22,
                  child: Icon(agencyIcon, color: badgeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.agencyOrRelationship,
                        style: TextStyle(
                            fontSize: 14,
                            color: subColor,
                            fontWeight: FontWeight.w500),
                      ),
                      if (contact.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          contact.description,
                          style: TextStyle(fontSize: 13.5, color: subColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!contact.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 22, color: AppTheme.dangerRed),
                    tooltip: 'Remove Contact',
                    onPressed: () =>
                        emergency.removePersonalContact(contact.id),
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: contact.category ==
                                  ContactCategory.nationalHotline ||
                              contact.category ==
                                  ContactCategory.medicalAndRedCross
                          ? AppTheme.dangerRed
                          : AppTheme.primaryNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(
                      'Call: ${contact.phoneNumber}',
                      style: const TextStyle(fontSize: 14),
                    ),
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
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.sms, size: 18),
                  label: const Text('SMS', style: TextStyle(fontSize: 14)),
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
      BuildContext context, EmergencyProvider emergency) {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Family / ICE Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contact Name *',
                  hintText: 'e.g. Papa, Mama, Kuya, Barangay Kagawad',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Relationship / Role',
                  hintText: 'e.g. Parent, Sibling, Neighbor',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: 'e.g. 09171234567',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) return;

              emergency.addPersonalContact(
                EmergencyContact(
                  id: const Uuid().v4(),
                  name: name,
                  agencyOrRelationship: relationCtrl.text.trim().isEmpty
                      ? 'Family'
                      : relationCtrl.text.trim(),
                  phoneNumber: phone,
                  category: ContactCategory.familyAndPersonal,
                  isDefault: false,
                  description:
                      'Emergency ICE (In Case of Emergency) Family Contact',
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save Contact'),
          ),
        ],
      ),
    );
  }
}
