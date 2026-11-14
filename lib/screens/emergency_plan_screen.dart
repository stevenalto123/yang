import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_plan.dart';
import '../providers/emergency_provider.dart';
import '../utils/app_theme.dart';

class EmergencyPlanScreen extends StatefulWidget {
  const EmergencyPlanScreen({super.key});

  @override
  State<EmergencyPlanScreen> createState() => _EmergencyPlanScreenState();
}

class _EmergencyPlanScreenState extends State<EmergencyPlanScreen> {
  late TextEditingController _householdCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _primaryMeetCtrl;
  late TextEditingController _secondarySiteCtrl;
  late TextEditingController _goBagLocCtrl;
  late TextEditingController _breakerCtrl;
  late TextEditingController _lpgCtrl;
  late TextEditingController _waterCtrl;
  late List<FamilyMemberProfile> _members;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final plan = context.read<EmergencyProvider>().emergencyPlan;
      _householdCtrl = TextEditingController(text: plan.householdName);
      _addressCtrl = TextEditingController(text: plan.homeAddress);
      _primaryMeetCtrl = TextEditingController(text: plan.primaryMeetingPoint);
      _secondarySiteCtrl =
          TextEditingController(text: plan.secondaryEvacuationSite);
      _goBagLocCtrl = TextEditingController(text: plan.goBagLocation);
      _breakerCtrl = TextEditingController(text: plan.mainBreakerLocation);
      _lpgCtrl = TextEditingController(text: plan.lpgValveLocation);
      _waterCtrl = TextEditingController(text: plan.waterValveLocation);
      _members = List<FamilyMemberProfile>.from(plan.members);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _householdCtrl.dispose();
    _addressCtrl.dispose();
    _primaryMeetCtrl.dispose();
    _secondarySiteCtrl.dispose();
    _goBagLocCtrl.dispose();
    _breakerCtrl.dispose();
    _lpgCtrl.dispose();
    _waterCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    final emergency = context.read<EmergencyProvider>();
    final updated = HouseholdEmergencyPlan(
      householdName: _householdCtrl.text.trim().isEmpty
          ? 'My Household'
          : _householdCtrl.text.trim(),
      homeAddress: _addressCtrl.text.trim(),
      primaryMeetingPoint: _primaryMeetCtrl.text.trim(),
      secondaryEvacuationSite: _secondarySiteCtrl.text.trim(),
      goBagLocation: _goBagLocCtrl.text.trim(),
      mainBreakerLocation: _breakerCtrl.text.trim(),
      lpgValveLocation: _lpgCtrl.text.trim(),
      waterValveLocation: _waterCtrl.text.trim(),
      members: _members,
    );
    await emergency.saveEmergencyPlan(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Household Emergency Plan saved offline!'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    }
  }

  void _copyPlanToClipboard() {
    final buf = StringBuffer();
    buf.writeln('HOUSEHOLD EMERGENCY PLAN: ${_householdCtrl.text}');
    if (_addressCtrl.text.isNotEmpty) buf.writeln('Address: ${_addressCtrl.text}');
    buf.writeln('Go-Bag Location: ${_goBagLocCtrl.text}');
    buf.writeln('Primary Meeting Point: ${_primaryMeetCtrl.text}');
    buf.writeln('Secondary Evacuation Site: ${_secondarySiteCtrl.text}');
    buf.writeln('Utility Shutoffs:');
    buf.writeln('- Main Breaker: ${_breakerCtrl.text}');
    buf.writeln('- LPG Gas Valve: ${_lpgCtrl.text}');
    buf.writeln('- Main Water Valve: ${_waterCtrl.text}');
    if (_members.isNotEmpty) {
      buf.writeln('Family Medical Profiles:');
      for (final m in _members) {
        buf.writeln(
            '- ${m.name} (${m.roleOrAge}) | Blood: ${m.bloodType} | Notes: ${m.medicalConditions}');
      }
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency Plan copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Emergency Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Plan Summary',
            onPressed: _copyPlanToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Plan',
            onPressed: _savePlan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.family_restroom, color: Colors.blue.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pre-plan your family meeting points, utility shutoffs, and medical profiles. Stored 100% offline.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('1. Household & Evacuation Assembly Points'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _householdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Household / Family Name',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Home Address / Barangay',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _primaryMeetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primary Meeting Point (Outside Home)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _secondarySiteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Secondary Evacuation Center',
                      prefixIcon: Icon(Icons.roofing),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _goBagLocCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Where Go-Bag is Stored',
                      prefixIcon: Icon(Icons.backpack_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader('2. Utility Shutoff Locations'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _breakerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Main Electrical Breaker Location',
                      prefixIcon: Icon(Icons.electric_bolt),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lpgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'LPG Tank / Gas Shutoff Valve',
                      prefixIcon: Icon(Icons.propane_tank_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _waterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Main Water Valve Location',
                      prefixIcon: Icon(Icons.water_damage_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('3. Family Medical & Blood Profiles'),
              TextButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Member'),
                onPressed: _showAddMemberDialog,
              ),
            ],
          ),
          if (_members.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No household members added yet. Add blood types and allergies for emergency responders.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._members.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryCrimson.withAlpha(26),
                      child: Text(
                        m.bloodType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryCrimson,
                        ),
                      ),
                    ),
                    title: Text('${m.name} (${m.roleOrAge})',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text('Medical/Allergies: ${m.medicalConditions}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _members.removeWhere((item) => item.id == m.id);
                        });
                        _savePlan();
                      },
                    ),
                  ),
                )),

          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Emergency Plan Offline'),
            onPressed: _savePlan,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkSlate,
        ),
      ),
    );
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final medCtrl = TextEditingController();
    String bloodType = 'O+';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Household Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Role / Age (e.g. Mother, 45)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: bloodType,
                  decoration: const InputDecoration(labelText: 'Blood Type'),
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown']
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => bloodType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: medCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Allergies / Maintenance Meds',
                    hintText: 'e.g. Asthma inhaler, Penicillin allergy',
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
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _members.add(FamilyMemberProfile(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    roleOrAge: roleCtrl.text.trim().isEmpty
                        ? 'Member'
                        : roleCtrl.text.trim(),
                    bloodType: bloodType,
                    medicalConditions: medCtrl.text.trim().isEmpty
                        ? 'None'
                        : medCtrl.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
                _savePlan();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
