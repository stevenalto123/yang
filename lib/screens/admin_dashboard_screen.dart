import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _codeCtrl = TextEditingController();
  String _activeAdminCode = '';
  bool _unlocked = false;
  bool _isLoading = false;
  String? _error;
  String _checkinFilter = 'ALL';

  Map<String, dynamic>? _overview;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isAdmin) {
      _unlocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOverview());
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.dangerRed : AppTheme.safeGreen,
      ),
    );
  }

  Future<void> _unlockWithCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your Admin Code.');
      return;
    }
    _activeAdminCode = code;
    await _loadOverview(fromUnlock: true);
  }

  Future<void> _loadOverview({bool fromUnlock = false}) async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final res = await auth.fetchAdminOverview(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.ok && res.data != null) {
        _overview = res.data;
        _unlocked = true;
        _error = null;
      } else {
        if (fromUnlock) _unlocked = false;
        _error = res.error ?? 'Invalid Admin Code or server unreachable.';
      }
    });
  }

  Future<void> _toggleShelterOpen(Map<String, dynamic> shelter, bool nextOpen) async {
    final auth = context.read<AuthProvider>();
    final id = (shelter['id'] ?? '').toString();
    final res = await auth.updateOfficialShelter(
      id: id,
      isOpen: nextOpen,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack(
        '${shelter['name']} marked ${nextOpen ? 'OPEN' : 'STANDBY'}.',
      );
      await _loadOverview();
    } else {
      _showSnack(res.error ?? 'Update failed.', isError: true);
    }
  }

  Future<void> _editShelterCapacity(Map<String, dynamic> shelter) async {
    final capCtrl = TextEditingController(
      text: (shelter['capacityPeople'] ?? 500).toString(),
    );
    final newCap = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Shelter Capacity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (shelter['name'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacity (number of people)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(capCtrl.text.trim());
              if (parsed != null && parsed >= 0) {
                Navigator.pop(ctx, parsed);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newCap == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final res = await auth.updateOfficialShelter(
      id: (shelter['id'] ?? '').toString(),
      capacityPeople: newCap,
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack('Updated capacity to $newCap people.');
      await _loadOverview();
    } else {
      _showSnack(res.error ?? 'Could not update capacity.', isError: true);
    }
  }

  Future<void> _showAddOfficialShelterDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Manila');
    final contactPersonCtrl = TextEditingController(text: 'City DRRMO');
    final phoneCtrl = TextEditingController(text: '911');
    final capCtrl = TextEditingController(text: '800');
    final facCtrl = TextEditingController(
      text: 'Covered Court, Relief Distribution, Medical Desk',
    );
    final latCtrl = TextEditingController(text: '14.5822');
    final lngCtrl = TextEditingController(text: '120.9882');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Official Evacuation Center'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shelter / Facility Name *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: 'Full Address *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: capCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Capacity'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: contactPersonCtrl,
                      decoration: const InputDecoration(labelText: 'Officer / Office'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Hotline'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: facCtrl,
                decoration: const InputDecoration(labelText: 'Facilities / Services'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Publish Shelter'),
          ),
        ],
      ),
    );

    if (submitted != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final res = await auth.createOfficialShelter(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
      shelter: {
        'name': nameCtrl.text.trim(),
        'address': addressCtrl.text.trim().isEmpty
            ? 'Metro Manila'
            : addressCtrl.text.trim(),
        'city': cityCtrl.text.trim().isEmpty ? 'Manila' : cityCtrl.text.trim(),
        'contactPerson': contactPersonCtrl.text.trim(),
        'contactNumber': phoneCtrl.text.trim(),
        'capacityPeople': int.tryParse(capCtrl.text.trim()) ?? 500,
        'latitude': double.tryParse(latCtrl.text.trim()) ?? 14.5822,
        'longitude': double.tryParse(lngCtrl.text.trim()) ?? 120.9882,
        'facilities': facCtrl.text.trim(),
        'isOpen': true,
      },
    );

    if (!mounted) return;
    if (res.ok) {
      _showSnack('Official shelter published to Supabase!');
      await _loadOverview();
    } else {
      _showSnack(res.error ?? 'Could not add shelter.', isError: true);
    }
  }

  Future<void> _confirmDeleteShelter(Map<String, dynamic> shelter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Shelter?'),
        content: Text(
          'Remove "${shelter['name']}" from the cloud shelter directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    final res = await auth.deleteOfficialShelter(
      id: (shelter['id'] ?? '').toString(),
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok) {
      _showSnack('Shelter removed.');
      await _loadOverview();
    } else {
      _showSnack(res.error ?? 'Could not remove shelter.', isError: true);
    }
  }

  Future<void> _copyCsv() async {
    final auth = context.read<AuthProvider>();
    final res = await auth.exportEvaluationsCsv(
      adminCode: _activeAdminCode.isNotEmpty ? _activeAdminCode : null,
    );
    if (!mounted) return;
    if (res.ok && res.csv != null) {
      await Clipboard.setData(ClipboardData(text: res.csv!));
      _showSnack('ISO/IEC 25010 CSV dataset copied to clipboard!');
    } else {
      _showSnack(res.error ?? 'Unable to export CSV.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = settings.isDarkMode;
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final activeTabColor =
        isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin & DRRM Portal')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryNavy,
                                  AppTheme.primaryAccent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Portal Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                Text(
                                  'DRRM Staff & EAC Capstone Researchers',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: subtleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enter your authorized Admin Code to manage Metro Manila evacuation centers, monitor emergency check-ins, and export ISO/IEC 25010 research surveys.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: subtleText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeCtrl,
                        obscureText: true,
                        onSubmitted: (_) => _unlockWithCode(),
                        decoration: const InputDecoration(
                          labelText: 'Admin Access Code',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.dangerRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_open_rounded, size: 18),
                          label: Text(
                            _isLoading ? 'Verifying...' : 'Unlock Admin Portal',
                          ),
                          onPressed: _isLoading ? null : _unlockWithCode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin & DRRM Portal'),
          actions: [
            IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: activeTabColor,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Live Data',
              onPressed: _isLoading ? null : () => _loadOverview(),
            ),
            if (auth.isAdmin)
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sign Out of Admin Account',
                onPressed: () async {
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded),
                tooltip: 'Lock Admin Portal',
                onPressed: () {
                  setState(() {
                    _unlocked = false;
                    _activeAdminCode = '';
                    _codeCtrl.clear();
                    _overview = null;
                  });
                },
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: activeTabColor,
            indicatorWeight: 3,
            labelColor: activeTabColor,
            unselectedLabelColor: subtleText,
            dividerColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            tabs: const [
              Tab(
                height: 46,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Overview'),
                  ],
                ),
              ),
              Tab(
                height: 46,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.roofing_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Shelters'),
                  ],
                ),
              ),
              Tab(
                height: 46,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.health_and_safety_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Check-Ins'),
                  ],
                ),
              ),
              Tab(
                height: 46,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Survey'),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _isLoading && _overview == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOverviewTab(isDark, headingColor, subtleText),
                  _buildSheltersTab(isDark, headingColor, subtleText),
                  _buildCheckinsTab(isDark, headingColor, subtleText),
                  _buildSurveyTab(isDark, headingColor, subtleText),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark, Color headingColor, Color subtleText) {
    final counts =
        Map<String, dynamic>.from(_overview?['counts'] as Map? ?? {});
    final households = (_overview?['households'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final evalSummary =
        Map<String, dynamic>.from(_overview?['evaluationSummary'] as Map? ?? {});
    final means = Map<String, dynamic>.from(evalSummary['means'] as Map? ?? {});
    final needHelp = (counts['checkinsNeedingHelp'] ?? 0) as int;

    final kpiCards = [
      _kpiCard(
        isDark: isDark,
        icon: Icons.groups_rounded,
        color: AppTheme.primaryAccent,
        label: 'Households',
        value: '${counts['households'] ?? 0}',
        sub: '${counts['users'] ?? 0} registered user(s)',
        headingColor: headingColor,
        subtleText: subtleText,
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.roofing_rounded,
        color: Colors.teal.shade700,
        label: 'Open Shelters',
        value: '${counts['openShelters'] ?? 0}/${counts['totalShelters'] ?? 0}',
        sub: 'Metro Manila centers',
        headingColor: headingColor,
        subtleText: subtleText,
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.sos_rounded,
        color: needHelp > 0 ? AppTheme.dangerRed : AppTheme.safeGreen,
        label: 'Need Help',
        value: '$needHelp',
        sub: '${counts['checkinsTotal'] ?? 0} total check-ins',
        headingColor: headingColor,
        subtleText: subtleText,
      ),
      _kpiCard(
        isDark: isDark,
        icon: Icons.star_rate_rounded,
        color: AppTheme.warningAmber,
        label: 'Survey Rating',
        value: '${means['overallMean'] ?? 0} / 5',
        sub: '${counts['evaluationsTotal'] ?? 0} respondent(s)',
        headingColor: headingColor,
        subtleText: subtleText,
      ),
    ];

    return ResponsiveContainer(
      maxWidth: 1000,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return Row(
                  children: [
                    Expanded(child: kpiCards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: kpiCards[1]),
                    const SizedBox(width: 12),
                    Expanded(child: kpiCards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: kpiCards[3]),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: kpiCards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: kpiCards[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: kpiCards[2]),
                      const SizedBox(width: 10),
                      Expanded(child: kpiCards[3]),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            'Synced Households (${households.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 10),
          if (households.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No households have signed in for cloud sync yet. As Metro Manila families create accounts and sync their Go-Bag, their readiness progress will appear here.',
                  style: TextStyle(fontSize: 13.5, color: subtleText),
                ),
              ),
            )
          else
            ...households.map((h) {
              final readiness = ((h['readinessPct'] ?? 0) as num).toDouble();
              final barColor = readiness >= 80
                  ? AppTheme.safeGreen
                  : (readiness >= 50
                      ? AppTheme.warningAmber
                      : AppTheme.dangerRed);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (h['name'] ?? 'Household').toString(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: barColor.withAlpha(isDark ? 45 : 22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${readiness.toStringAsFixed(0)}% Ready',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: barColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${h['inviteCode'] ?? '-'} • Household size: ${h['memberCount'] ?? 2} • ${h['accountCount'] ?? 1} ${(h['accountCount'] ?? 1) == 1 ? 'account' : 'accounts'} • ${h['packedCount'] ?? 0}/${h['itemCount'] ?? 0} packed',
                        style: TextStyle(fontSize: 13, color: subtleText),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: (readiness / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: isDark
                              ? AppTheme.darkElevated
                              : AppTheme.lightBorder,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSheltersTab(bool isDark, Color headingColor, Color subtleText) {
    final shelters = (_overview?['shelters'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evacuation Centers (${shelters.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: headingColor,
                      ),
                    ),
                    Text(
                      'Toggle live Open / Standby status or adjust shelter capacity.',
                      style: TextStyle(fontSize: 13, color: subtleText),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add Shelter'),
                onPressed: _showAddOfficialShelterDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...shelters.map((s) {
            final isOpen = s['isOpen'] == true;
            final isOfficial = s['isOfficial'] == true;
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isOfficial
                                              ? AppTheme.primaryAccent
                                              : AppTheme.warningAmber)
                                          .withAlpha(isDark ? 45 : 22),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isOfficial ? 'Official' : 'Community',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isOfficial
                                            ? (isDark
                                                ? Colors.lightBlue.shade200
                                                : AppTheme.primaryAccent)
                                            : AppTheme.warningAmber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (s['city'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: subtleText,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (s['name'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: headingColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (s['address'] ?? '').toString(),
                                style: TextStyle(fontSize: 13, color: subtleText),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Switch(
                              value: isOpen,
                              activeTrackColor: AppTheme.safeGreen,
                              onChanged: (v) => _toggleShelterOpen(s, v),
                            ),
                            Text(
                              isOpen ? 'OPEN' : 'STANDBY',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isOpen
                                    ? AppTheme.safeGreen
                                    : AppTheme.dangerRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Capacity: ${s['capacityPeople'] ?? 0} • Hotline: ${s['contactNumber'] ?? '-'}',
                          style: TextStyle(fontSize: 13, color: subtleText),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Capacity', style: TextStyle(fontSize: 12.5)),
                          onPressed: () => _editShelterCapacity(s),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            foregroundColor: AppTheme.dangerRed,
                            side: BorderSide(
                              color: AppTheme.dangerRed.withAlpha(130),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Remove', style: TextStyle(fontSize: 12.5)),
                          onPressed: () => _confirmDeleteShelter(s),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCheckinsTab(bool isDark, Color headingColor, Color subtleText) {
    final allCheckins = (_overview?['recentCheckins'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final filtered = allCheckins.where((c) {
      final st = (c['status'] ?? '').toString().toUpperCase();
      if (_checkinFilter == 'HELP') {
        return st.contains('ASSIST') || st.contains('HELP');
      }
      if (_checkinFilter == 'EVAC') return st.contains('EVAC');
      if (_checkinFilter == 'SAFE') return st == 'SAFE';
      return true;
    }).toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${allCheckins.length})'),
                selected: _checkinFilter == 'ALL',
                selectedColor: AppTheme.primaryNavy,
                labelStyle: TextStyle(
                  color: _checkinFilter == 'ALL' ? Colors.white : headingColor,
                ),
                onSelected: (_) => setState(() => _checkinFilter = 'ALL'),
              ),
              ChoiceChip(
                label: const Text('Need Help'),
                selected: _checkinFilter == 'HELP',
                selectedColor: AppTheme.dangerRed,
                labelStyle: TextStyle(
                  color: _checkinFilter == 'HELP' ? Colors.white : headingColor,
                ),
                onSelected: (_) => setState(() => _checkinFilter = 'HELP'),
              ),
              ChoiceChip(
                label: const Text('Evacuating'),
                selected: _checkinFilter == 'EVAC',
                selectedColor: AppTheme.warningAmber,
                labelStyle: TextStyle(
                  color: _checkinFilter == 'EVAC' ? Colors.white : headingColor,
                ),
                onSelected: (_) => setState(() => _checkinFilter = 'EVAC'),
              ),
              ChoiceChip(
                label: const Text('Safe'),
                selected: _checkinFilter == 'SAFE',
                selectedColor: AppTheme.safeGreen,
                labelStyle: TextStyle(
                  color: _checkinFilter == 'SAFE' ? Colors.white : headingColor,
                ),
                onSelected: (_) => setState(() => _checkinFilter = 'SAFE'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No household check-ins in this category yet.',
                  style: TextStyle(fontSize: 14, color: subtleText),
                ),
              ),
            )
          else
            ...filtered.map((c) {
              final st = (c['status'] ?? 'SAFE').toString().toUpperCase();
              final isSafe = st == 'SAFE';
              final isHelp = st.contains('ASSIST') || st.contains('HELP');
              final badgeColor = isSafe
                  ? AppTheme.safeGreen
                  : (isHelp ? AppTheme.dangerRed : AppTheme.warningAmber);
              final ts = DateTime.tryParse((c['timestamp'] ?? '').toString());
              final hasGps = c['latitude'] != null && c['longitude'] != null;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isHelp
                        ? AppTheme.dangerRed.withAlpha(170)
                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    width: isHelp ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(isDark ? 45 : 22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isSafe
                              ? Icons.check_circle_rounded
                              : (isHelp
                                  ? Icons.sos_rounded
                                  : Icons.directions_run_rounded),
                          color: badgeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${c['authorName'] ?? 'Member'} • ${c['householdName'] ?? 'Household'}',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: headingColor,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withAlpha(isDark ? 45 : 22),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    st,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((c['note'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                (c['note'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: headingColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${ts != null ? DateFormat('MMM d, yyyy • h:mm a').format(ts.toLocal()) : ''}${hasGps ? ' • GPS: ${(c['latitude'] as num).toStringAsFixed(4)}, ${(c['longitude'] as num).toStringAsFixed(4)}' : ''}',
                              style: TextStyle(fontSize: 12, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSurveyTab(bool isDark, Color headingColor, Color subtleText) {
    final evalSummary =
        Map<String, dynamic>.from(_overview?['evaluationSummary'] as Map? ?? {});
    final means = Map<String, dynamic>.from(evalSummary['means'] as Map? ?? {});
    final recent = (evalSummary['recent'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return ResponsiveContainer(
      maxWidth: 1000,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISO/IEC 25010 Evaluation Results',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            Text(
                              'Total Respondents: ${evalSummary['totalRespondents'] ?? 0} • Avg Kit Readiness: ${means['averageReadinessPct'] ?? 0}%',
                              style: TextStyle(fontSize: 13, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Copy CSV'),
                        onPressed: _copyCsv,
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  _scoreBar('1. Functionality', means['functionality'], isDark, headingColor),
                  _scoreBar('2. Usability', means['usability'], isDark, headingColor),
                  _scoreBar('3. Offline Reliability', means['offlineReliability'], isDark, headingColor),
                  _scoreBar('4. Preparedness Effectiveness', means['effectiveness'], isDark, headingColor),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withAlpha(isDark ? 70 : 14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Weighted Mean',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                        Text(
                          '${means['overallMean'] ?? 0} / 5.00',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.lightBlue.shade200
                                : AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Respondent Submissions (${recent.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No survey responses submitted yet.',
                  style: TextStyle(fontSize: 14, color: subtleText),
                ),
              ),
            )
          else
            ...recent.map((r) {
              final mean = ((((r['functionalityScore'] ?? 0) as num) +
                          ((r['usabilityScore'] ?? 0) as num) +
                          ((r['reliabilityScore'] ?? 0) as num) +
                          ((r['effectivenessScore'] ?? 0) as num)) /
                      4.0)
                  .toStringAsFixed(2);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${r['respondentLabel'] ?? 'Anonymous'} (${r['platform'] ?? 'web'})',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'F:${r['functionalityScore']} • U:${r['usabilityScore']} • R:${r['reliabilityScore']} • E:${r['effectivenessScore']} • Kit: ${r['readinessPercentage']}%',
                        style: TextStyle(fontSize: 12.5, color: subtleText),
                      ),
                      if ((r['comments'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '"${r['comments']}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: headingColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.safeGreen.withAlpha(isDark ? 45 : 20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$mean/5',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.safeGreen,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, dynamic val, bool isDark, Color headingColor) {
    final score = ((val ?? 0) as num).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: headingColor,
                ),
              ),
              Text(
                '${score.toStringAsFixed(2)} / 5.00',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (score / 5.0).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor:
                  isDark ? AppTheme.darkElevated : AppTheme.lightBorder,
              color: AppTheme.primaryAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String sub,
    required Color headingColor,
    required Color subtleText,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(isDark ? 45 : 20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: headingColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: subtleText),
            ),
          ],
        ),
      ),
    );
  }
}
