import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_plan.dart';
import '../models/evacuation_center.dart';
import '../providers/emergency_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';

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
  bool _hasUnsavedChanges = false;
  bool _isPopulating = false;
  DateTime? _syncedPlanTimestamp;

  void _markDirty() {
    if (_isPopulating) return;
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  void _populateControllersFromPlan(HouseholdEmergencyPlan plan) {
    _isPopulating = true;
    _householdCtrl.text = plan.householdName;
    _addressCtrl.text = plan.homeAddress;
    _primaryMeetCtrl.text = plan.primaryMeetingPoint;
    _secondarySiteCtrl.text = plan.secondaryEvacuationSite;
    _goBagLocCtrl.text = plan.goBagLocation;
    _breakerCtrl.text = plan.mainBreakerLocation;
    _lpgCtrl.text = plan.lpgValveLocation;
    _waterCtrl.text = plan.waterValveLocation;
    _members = List<FamilyMemberProfile>.from(plan.members);
    _syncedPlanTimestamp = plan.lastUpdated;
    _isPopulating = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final plan = context.read<EmergencyProvider>().emergencyPlan;
      _householdCtrl = TextEditingController(text: plan.householdName)
        ..addListener(_markDirty);
      _addressCtrl = TextEditingController(text: plan.homeAddress)
        ..addListener(_markDirty);
      _primaryMeetCtrl = TextEditingController(text: plan.primaryMeetingPoint)
        ..addListener(_markDirty);
      _secondarySiteCtrl =
          TextEditingController(text: plan.secondaryEvacuationSite)
            ..addListener(_markDirty);
      _goBagLocCtrl = TextEditingController(text: plan.goBagLocation)
        ..addListener(_markDirty);
      _breakerCtrl = TextEditingController(text: plan.mainBreakerLocation)
        ..addListener(_markDirty);
      _lpgCtrl = TextEditingController(text: plan.lpgValveLocation)
        ..addListener(_markDirty);
      _waterCtrl = TextEditingController(text: plan.waterValveLocation)
        ..addListener(_markDirty);
      _members = List<FamilyMemberProfile>.from(plan.members);
      _syncedPlanTimestamp = plan.lastUpdated;
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
      setState(() {
        _syncedPlanTimestamp = updated.lastUpdated;
        _hasUnsavedChanges = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Household Emergency Plan saved offline!'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    }
  }

  String _formatPlanSummary() {
    final buf = StringBuffer();
    buf.writeln('HOUSEHOLD EMERGENCY PLAN: ${_householdCtrl.text}');
    if (_addressCtrl.text.isNotEmpty) {
      buf.writeln('Address: ${_addressCtrl.text}');
    }
    buf.writeln('Go-Bag Location: ${_goBagLocCtrl.text}');
    buf.writeln('Primary Meeting Point: ${_primaryMeetCtrl.text}');
    buf.writeln('Secondary Evacuation Site: ${_secondarySiteCtrl.text}');
    buf.writeln('Utility Shutoffs:');
    buf.writeln('- Main Breaker: ${_breakerCtrl.text}');
    buf.writeln('- LPG Gas Valve: ${_lpgCtrl.text}');
    buf.writeln('- Main Water Valve: ${_waterCtrl.text}');
    if (_members.isNotEmpty) {
      buf.writeln('Family Medical Profiles (ICE):');
      for (final m in _members) {
        buf.writeln(
          '- ${m.name} (${m.roleOrAge}) | Blood: ${m.bloodType} | Notes: ${m.medicalConditions}',
        );
      }
    }
    return buf.toString();
  }

  void _copyPlanToClipboard() {
    Clipboard.setData(ClipboardData(text: _formatPlanSummary()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency Plan copied to clipboard')),
    );
  }

  void _showShelterPicker(TextEditingController targetCtrl, bool isFil) {
    final emergency = context.read<EmergencyProvider>();
    final shelters = emergency.allEvacuationCenters
        .where((c) => c.facilityType == FacilityType.evacuationShelter)
        .toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              isFil
                  ? 'Pumili ng Opisyal na Evacuation Shelter sa Maynila'
                  : 'Pick a Verified City of Manila Shelter',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...shelters.map(
              (s) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withAlpha(28),
                  child: Icon(
                    Icons.roofing_rounded,
                    color: Colors.teal.shade700,
                    size: 20,
                  ),
                ),
                title: Text(
                  s.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${s.address} (${s.city})',
                  style: const TextStyle(fontSize: 12.5),
                ),
                trailing: const Icon(Icons.add_circle_outline_rounded),
                onTap: () {
                  targetCtrl.text = '${s.name} — ${s.address}';
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showIceCardModal(bool isDark, bool isFil) {
    final emergency = context.read<EmergencyProvider>();
    final contacts = emergency.personalContacts;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: AppTheme.dangerRed,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medical_information_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFil
                                  ? 'EMERGENCY ID (ICE CARD)'
                                  : 'IN CASE OF EMERGENCY (ICE)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              _householdCtrl.text.trim().isEmpty
                                  ? 'My Household'
                                  : _householdCtrl.text.trim(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _iceRow(
                        Icons.home_outlined,
                        isFil ? 'Tirahan' : 'Home Address',
                        _addressCtrl.text.trim().isEmpty
                            ? 'Not set'
                            : _addressCtrl.text.trim(),
                      ),
                      _iceRow(
                        Icons.flag_outlined,
                        isFil ? 'Tagpuan' : 'Primary Meeting Point',
                        _primaryMeetCtrl.text.trim().isEmpty
                            ? 'Not set'
                            : _primaryMeetCtrl.text.trim(),
                      ),
                      _iceRow(
                        Icons.roofing_rounded,
                        isFil ? 'Evacuation Center' : 'Backup Shelter',
                        _secondarySiteCtrl.text.trim().isEmpty
                            ? 'Not set'
                            : _secondarySiteCtrl.text.trim(),
                      ),
                      _iceRow(
                        Icons.backpack_outlined,
                        'Go-Bag Location',
                        _goBagLocCtrl.text.trim().isEmpty
                            ? 'Not set'
                            : _goBagLocCtrl.text.trim(),
                      ),
                      const Divider(height: 22),
                      Text(
                        isFil
                            ? 'Medikal at Blood Type ng Pamilya'
                            : 'Family Medical & Blood Profiles',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_members.isEmpty)
                        Text(
                          isFil
                              ? 'Wala pang naitalang miyembro.'
                              : 'No family medical profiles added yet.',
                          style: const TextStyle(fontSize: 13),
                        )
                      else
                        ..._members.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withAlpha(26),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.dangerRed.withAlpha(110),
                                    ),
                                  ),
                                  child: Text(
                                    m.bloodType,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.dangerRed,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.name} (${m.roleOrAge})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        m.medicalConditions,
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (contacts.isNotEmpty) ...[
                        const Divider(height: 20),
                        Text(
                          isFil
                              ? 'Emergency Contacts ng Pamilya'
                              : 'Personal Emergency Contacts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...contacts.take(3).map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${c.name}${c.agencyOrRelationship.isNotEmpty ? ' (${c.agencyOrRelationship})' : ''}: ${c.phoneNumber}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                      ],
                      const Divider(height: 20),
                      Text(
                        isFil
                            ? 'Opisyal na Hotline ng Lungsod ng Maynila'
                            : 'Official City of Manila Hotlines',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '• Emergency: 911  • Red Cross: 143\n• Manila DRRMO: (02) 8568-6909 / 0932-662-2322',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 17),
                              label: Text(isFil ? 'Kopyahin' : 'Copy ICE'),
                              onPressed: () {
                                _copyPlanToClipboard();
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(isFil ? 'Isara' : 'Done'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iceRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.mutedSlate,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final remotePlan = context.watch<EmergencyProvider>().emergencyPlan;
    if (_initialized &&
        !_hasUnsavedChanges &&
        _syncedPlanTimestamp != remotePlan.lastUpdated) {
      _syncedPlanTimestamp = remotePlan.lastUpdated;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasUnsavedChanges) {
          setState(() {
            _populateControllersFromPlan(remotePlan);
          });
        }
      });
    }
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final s = AppStrings(isFil);

    final subColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    final bodyContent = ResponsiveContainer(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          if (_hasUnsavedChanges) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.warningAmber.withAlpha(42)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningAmber.withAlpha(170)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_notifications_outlined,
                    color: AppTheme.warningAmber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFil
                          ? 'May mga pagbabagong hindi pa naka-save.'
                          : 'You have unsaved changes to your family plan.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningAmber,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.warningAmber,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _savePlan,
                    child: Text(isFil ? 'I-save' : 'Save Now'),
                  ),
                ],
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.blue.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      color: isDark
                          ? Colors.lightBlueAccent
                          : Colors.blue.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFil
                            ? 'Iplano ang tagpuan ng pamilya, shutoff ng kuryente at tubig, at medikal na profile. Naka-save 100% offline.'
                            : 'Pre-plan your family meeting points, utility shutoffs, and medical profiles. Stored 100% offline.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.grey.shade200
                              : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(
                        Icons.medical_information_outlined,
                        size: 17,
                      ),
                      label: Text(
                        isFil ? 'Tingnan ang ICE Card' : 'View Emergency ID (ICE)',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: () => _showIceCardModal(isDark, isFil),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: Text(
                        isFil ? 'Kopyahin ang Plano' : 'Copy Plan',
                        style: const TextStyle(fontSize: 13),
                      ),
                      onPressed: _copyPlanToClipboard,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(
            isFil
                ? '1. Pamilya at Tagpuan sa Evacuation'
                : '1. Household & Evacuation Assembly Points',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _householdCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangalan ng Pamilya / Household'
                          : 'Household / Family Name',
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Tirahan / Barangay'
                          : 'Home Address / Barangay',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primaryMeetCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangunahing Tagpuan (Labas ng Bahay)'
                          : 'Primary Meeting Point (Outside Home)',
                      prefixIcon: const Icon(Icons.flag_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.roofing_rounded, size: 20),
                        tooltip: isFil
                            ? 'Pumili mula sa Manila Shelters'
                            : 'Pick from City of Manila Shelters',
                        onPressed: () =>
                            _showShelterPicker(_primaryMeetCtrl, isFil),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _secondarySiteCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangalawang Evacuation Center'
                          : 'Secondary Evacuation Center',
                      prefixIcon: const Icon(Icons.roofing),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.location_searching_rounded, size: 20),
                        tooltip: isFil
                            ? 'Pumili mula sa Manila Shelters'
                            : 'Pick from City of Manila Shelters',
                        onPressed: () =>
                            _showShelterPicker(_secondarySiteCtrl, isFil),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _goBagLocCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Saan Nakatabi ang Go-Bag'
                          : 'Where Go-Bag is Stored',
                      prefixIcon: const Icon(Icons.backpack_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(
            isFil
                ? '2. Lokasyon ng mga Valve at Breaker'
                : '2. Utility Shutoff Locations',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _breakerCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangunahing Breaker ng Kuryente'
                          : 'Main Electrical Breaker Location',
                      prefixIcon: const Icon(Icons.electric_bolt),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lpgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'LPG Tank / Gas Shutoff Valve',
                      prefixIcon: Icon(Icons.propane_tank_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _waterCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangunahing Valve ng Tubig'
                          : 'Main Water Valve Location',
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
              Expanded(
                child: _buildSectionHeader(
                  isFil
                      ? '3. Medikal at Blood Profile ng Pamilya'
                      : '3. Family Medical & Blood Profiles',
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(isFil ? 'Magdagdag' : 'Add Member'),
                onPressed: () => _showMemberDialog(isFil),
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
            ..._members.map(
              (m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _showMemberDialog(isFil, existing: m),
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
                  title: Text(
                    '${m.name} (${m.roleOrAge})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${isFil ? 'Medikal/Allergy' : 'Medical/Allergies'}: ${m.medicalConditions}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: subColor,
                        ),
                        tooltip: isFil ? 'I-edit' : 'Edit Member',
                        onPressed: () => _showMemberDialog(isFil, existing: m),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.dangerRed,
                        ),
                        tooltip: isFil ? 'Burahin' : 'Remove Member',
                        onPressed: () {
                          setState(() {
                            _members.removeWhere((item) => item.id == m.id);
                          });
                          _savePlan();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

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
      ),
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.householdPlan),
        actions: [
          IconButton(
            icon: const Icon(Icons.medical_information_outlined),
            tooltip: isFil ? 'Emergency ID (ICE)' : 'View Emergency ID (ICE)',
            onPressed: () => _showIceCardModal(isDark, isFil),
          ),
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

  void _showMemberDialog(bool isFil, {FamilyMemberProfile? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final roleCtrl = TextEditingController(text: existing?.roleOrAge ?? '');
    final medCtrl = TextEditingController(
      text: existing != null &&
              existing.medicalConditions != 'None' &&
              existing.medicalConditions != 'Wala'
          ? existing.medicalConditions
          : '',
    );
    const validBloodTypes = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
      'Unknown',
    ];
    String bloodType = existing != null &&
            validBloodTypes.contains(existing.bloodType)
        ? existing.bloodType
        : 'O+';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEdit
                ? (isFil ? 'I-edit ang Miyembro' : 'Edit Household Member')
                : (isFil
                    ? 'Magdagdag ng Miyembro ng Pamilya'
                    : 'Add Household Member'),
          ),
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
                    labelText: isFil
                        ? 'Tungkulin / Edad (hal. Nanay, 45)'
                        : 'Role / Age (e.g. Mother, 45)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: bloodType,
                  decoration: InputDecoration(
                    labelText:
                        isFil ? 'Uri ng Dugo (Blood Type)' : 'Blood Type',
                  ),
                  items: validBloodTypes
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
                    labelText: isFil
                        ? 'Allergy / Maintenance na Gamot'
                        : 'Allergies / Maintenance Meds',
                    hintText: isFil
                        ? 'hal. Asthma inhaler, Penicillin allergy'
                        : 'e.g. Asthma inhaler, Penicillin allergy',
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
                final updatedProfile = FamilyMemberProfile(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  roleOrAge: roleCtrl.text.trim().isEmpty
                      ? (isFil ? 'Miyembro' : 'Member')
                      : roleCtrl.text.trim(),
                  bloodType: bloodType,
                  medicalConditions: medCtrl.text.trim().isEmpty
                      ? (isFil ? 'Wala' : 'None')
                      : medCtrl.text.trim(),
                );
                setState(() {
                  if (isEdit) {
                    final idx =
                        _members.indexWhere((m) => m.id == existing.id);
                    if (idx != -1) {
                      _members[idx] = updatedProfile;
                    }
                  } else {
                    _members.add(updatedProfile);
                  }
                });
                Navigator.pop(ctx);
                _savePlan();
              },
              child: Text(
                isEdit
                    ? (isFil ? 'I-save' : 'Save')
                    : (isFil ? 'Idagdag' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        nameCtrl.dispose();
        roleCtrl.dispose();
        medCtrl.dispose();
      });
    });
  }
}
