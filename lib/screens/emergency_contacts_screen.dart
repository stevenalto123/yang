import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact.dart';
import '../providers/emergency_provider.dart';
import '../utils/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  ContactCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();

    final filtered = _selectedCategory == null
        ? emergency.allContacts
        : emergency.allContacts.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add Family Contact',
            onPressed: () => _showAddPersonalContactDialog(context, emergency),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline notice banner
          Container(
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, size: 16, color: AppTheme.safeGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Offline Cellular Dialing • No Internet Required',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
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
                  selectedColor: AppTheme.primaryCrimson,
                  labelStyle: TextStyle(
                    color: _selectedCategory == null ? Colors.white : Colors.black87,
                    fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11.5,
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
                      selectedColor: AppTheme.primaryCrimson,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11.5,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final contact = filtered[index];
                return _buildContactCard(context, contact, emergency);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryCrimson,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Family'),
        onPressed: () => _showAddPersonalContactDialog(context, emergency),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    EmergencyContact contact,
    EmergencyProvider emergency,
  ) {
    Color badgeColor;
    IconData agencyIcon;

    switch (contact.category) {
      case ContactCategory.nationalHotline:
        badgeColor = AppTheme.accentAlert;
        agencyIcon = Icons.notifications_active;
        break;
      case ContactCategory.police:
        badgeColor = Colors.indigo;
        agencyIcon = Icons.local_police;
        break;
      case ContactCategory.fire:
        badgeColor = Colors.deepOrange;
        agencyIcon = Icons.local_fire_department;
        break;
      case ContactCategory.medicalAndRedCross:
        badgeColor = Colors.red.shade700;
        agencyIcon = Icons.medical_services;
        break;
      case ContactCategory.disasterManagement:
        badgeColor = Colors.teal.shade800;
        agencyIcon = Icons.shield;
        break;
      case ContactCategory.familyAndPersonal:
        badgeColor = Colors.purple.shade700;
        agencyIcon = Icons.family_restroom;
        break;
    }

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
                CircleAvatar(
                  backgroundColor: badgeColor.withAlpha(26),
                  radius: 20,
                  child: Icon(agencyIcon, color: badgeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.agencyOrRelationship,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      if (contact.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          contact.description,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!contact.isDefault)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: 'Remove Contact',
                    onPressed: () => emergency.removePersonalContact(contact.id),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Call and SMS Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: badgeColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.call, size: 16),
                    label: Text(
                      'Call: ${contact.phoneNumber}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    onPressed: () => emergency.makePhoneCall(contact.phoneNumber),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: badgeColor,
                    side: BorderSide(color: badgeColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sms, size: 16),
                  label: const Text('SMS', style: TextStyle(fontSize: 12.5)),
                  onPressed: () {
                    emergency.sendEmergencySms(
                      phoneNumber: contact.phoneNumber,
                      message:
                          'EMERGENCY: Urgent assistance needed from LifeCheckpoint user at current household location.',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPersonalContactDialog(BuildContext context, EmergencyProvider emergency) {
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
                  agencyOrRelationship: relationCtrl.text.trim().isEmpty ? 'Family' : relationCtrl.text.trim(),
                  phoneNumber: phone,
                  category: ContactCategory.familyAndPersonal,
                  isDefault: false,
                  description: 'Emergency ICE (In Case of Emergency) Family Contact',
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
