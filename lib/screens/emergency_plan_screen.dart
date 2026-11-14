import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_plan.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';

class EmergencyPlanScreen extends StatefulWidget {
  final bool isEmbedded;

  const EmergencyPlanScreen({super.key, this.isEmbedded = false});

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
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final s = AppStrings(isFil);

    final subColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    final bodyContent = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.family_restroom,
                  color: isDark ? Colors.lightBlueAccent : Colors.blue.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFil
                      ? 'Iplano ang tagpuan ng pamilya, mga shutoff ng kuryente at tubig, at medikal na profile. Naka-save 100% offline.'
                      : 'Pre-plan your family meeting points, utility shutoffs, and medical profiles. Stored 100% offline.',
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade200 : Colors.blue.shade900),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: isFil ? 'Kopyahin ang Plano' : 'Copy Plan Summary',
                onPressed: _copyPlanToClipboard,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionHeader(isFil
            ? '1. Pamilya at Tagpuan sa Evacuation'
            : '1. Household & Evacuation Assembly Points'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _householdCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Pangalan ng Pamilya / Household' : 'Household / Family Name',
                    prefixIcon: const Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Tirahan / Barangay' : 'Home Address / Barangay',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _primaryMeetCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Pangunahing Tagpuan (Labas ng Bahay)' : 'Primary Meeting Point (Outside Home)',
                    prefixIcon: const Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secondarySiteCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Pangalawang Evacuation Center' : 'Secondary Evacuation Center',
                    prefixIcon: const Icon(Icons.roofing),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _goBagLocCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Saan Nakatabi ang Go-Bag' : 'Where Go-Bag is Stored',
                    prefixIcon: const Icon(Icons.backpack_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildSectionHeader(isFil
            ? '2. Lokasyon ng mga Valve at Breaker'
            : '2. Utility Shutoff Locations'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: _breakerCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Pangunahing Breaker ng Kuryente' : 'Main Electrical Breaker Location',
                    prefixIcon: const Icon(Icons.electric_bolt),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lpgCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'LPG Tank / Gas Shutoff Valve' : 'LPG Tank / Gas Shutoff Valve',
                    prefixIcon: const Icon(Icons.propane_tank_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _waterCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Pangunahing Valve ng Tubig' : 'Main Water Valve Location',
                    prefixIcon: const Icon(Icons.water_damage_outlined),
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
            _buildSectionHeader(isFil
                ? '3. Medikal at Blood Profile ng Pamilya'
                : '3. Family Medical & Blood Profiles'),
            TextButton.icon(
              icon: const Icon(Icons.person_add, size: 18),
              label: Text(isFil ? 'Magdagdag' : 'Add Member'),
              onPressed: () => _showAddMemberDialog(isFil),
            ),
          ],
        ),
        if (_members.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                isFil
                    ? 'Wala pang miyembro na naidagdag. Magtala ng blood type at allergy para sa emergency responders.'
                    : 'No household members added yet. Add blood types and allergies for emergency responders.',
                style: TextStyle(fontSize: 14, color: subColor),
              ),
            ),
          )
        else
          ..._members.map((m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryNavy.withAlpha(30),
                    child: Text(
                      m.bloodType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.lightBlueAccent
                            : AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                  title: Text('${m.name} (${m.roleOrAge})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text(
                    '${isFil ? 'Medikal/Allergy' : 'Medical/Allergies'}: ${m.medicalConditions}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.dangerRed),
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
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.save),
          label: Text(
            isFil
                ? 'I-save ang Plano Offline'
                : 'Save Emergency Plan Offline',
          ),
          onPressed: _savePlan,
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.householdPlan),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: isFil ? 'Kopyahin ang Plano' : 'Copy Plan Summary',
            onPressed: _copyPlanToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: isFil ? 'I-save ang Plano' : 'Save Plan',
            onPressed: _savePlan,
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddMemberDialog(bool isFil) {
    final nameCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final medCtrl = TextEditingController();
    String bloodType = 'O+';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isFil ? 'Magdagdag ng Miyembro ng Pamilya' : 'Add Household Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Buong Pangalan *' : 'Full Name *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roleCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Tungkulin / Edad (hal. Nanay, 45)' : 'Role / Age (e.g. Mother, 45)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: bloodType,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Uri ng Dugo (Blood Type)' : 'Blood Type',
                  ),
                  items: [
                    'A+',
                    'A-',
                    'B+',
                    'B-',
                    'AB+',
                    'AB-',
                    'O+',
                    'O-',
                    'Unknown'
                  ]
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => bloodType = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: medCtrl,
                  decoration: InputDecoration(
                    labelText: isFil ? 'Allergy / Maintenance na Gamot' : 'Allergies / Maintenance Meds',
                    hintText: isFil ? 'hal. Asthma inhaler, Penicillin allergy' : 'e.g. Asthma inhaler, Penicillin allergy',
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
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _members.add(FamilyMemberProfile(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    roleOrAge: roleCtrl.text.trim().isEmpty
                        ? (isFil ? 'Miyembro' : 'Member')
                        : roleCtrl.text.trim(),
                    bloodType: bloodType,
                    medicalConditions: medCtrl.text.trim().isEmpty
                        ? (isFil ? 'Wala' : 'None')
                        : medCtrl.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
                _savePlan();
              },
              child: Text(isFil ? 'Idagdag' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
