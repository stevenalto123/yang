import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';

class AccountSyncScreen extends StatefulWidget {
  const AccountSyncScreen({super.key});

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _showAdvancedServer = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _householdCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _adminCodeCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController();

  Map<String, dynamic>? _evalSummary;
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _serverUrlCtrl.text = auth.customServerUrl;
    if (auth.isAdmin && auth.hasCloudEndpoint) {
      _loadEvaluationSummary();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _householdCtrl.dispose();
    _inviteCtrl.dispose();
    _adminCodeCtrl.dispose();
    _joinCodeCtrl.dispose();
    _serverUrlCtrl.dispose();
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

  Future<void> _submitAuth(AuthProvider auth) async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnack('Please enter email and password.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final res = _isRegisterMode
        ? await auth.register(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim().isEmpty
                ? 'Household Member'
                : _nameCtrl.text,
            householdName: _householdCtrl.text,
            inviteCode: _inviteCtrl.text,
            adminCode: _adminCodeCtrl.text,
          )
        : await auth.login(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      _showSnack(
        _isRegisterMode
            ? 'Account created & household synced!'
            : 'Signed in & household synced!',
      );
      if (auth.isAdmin) _loadEvaluationSummary();
    } else {
      _showSnack(res.error ?? 'Authentication failed.', isError: true);
    }
  }

  Future<void> _loadEvaluationSummary({String? adminCode}) async {
    final auth = context.read<AuthProvider>();
    setState(() => _loadingSummary = true);
    final res = await auth.fetchEvaluationSummary(adminCode: adminCode);
    if (!mounted) return;
    setState(() {
      _loadingSummary = false;
      if (res.ok) _evalSummary = res.summary;
    });
    if (!res.ok) {
      _showSnack(res.error ?? 'Unable to load evaluation summary.', isError: true);
    }
  }

  Future<void> _copyCsv({String? adminCode}) async {
    final auth = context.read<AuthProvider>();
    final res = await auth.exportEvaluationsCsv(adminCode: adminCode);
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
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil ? 'Account at Cloud Sync' : 'Account & Cloud Sync',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // 1. Sync Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        auth.isAuthenticated
                            ? Icons.cloud_done
                            : Icons.cloud_off_outlined,
                        color: auth.isAuthenticated
                            ? AppTheme.safeGreen
                            : AppTheme.warningAmber,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isAuthenticated
                                  ? (isFil
                                      ? 'Aktibo ang Cloud Sync'
                                      : 'Household Cloud Sync Active')
                                  : (isFil
                                      ? 'Offline Guest Mode (Lokal na Imbakan)'
                                      : 'Offline Guest Mode (Device Local)'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: headingColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.lastSyncedAt != null
                                  ? 'Last synced: ${DateFormat('MMM d, h:mm a').format(auth.lastSyncedAt!)}'
                                  : 'Pending offline updates: ${auth.pendingSyncCount}',
                              style: TextStyle(fontSize: 13.5, color: subtleText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (auth.lastSyncError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      auth.lastSyncError!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: auth.isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(
                            auth.isSyncing
                                ? 'Syncing...'
                                : (isFil ? 'I-sync Ngayon' : 'Sync Now'),
                          ),
                          onPressed: auth.isSyncing
                              ? null
                              : () async {
                                  final res = await auth.syncNow();
                                  _showSnack(
                                    res.ok
                                        ? 'Synced cleanly with Netlify + Supabase!'
                                        : (res.error ?? 'Sync queued offline.'),
                                    isError: !res.ok,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings_ethernet, size: 18),
                        label: const Text('Server'),
                        onPressed: () {
                          setState(() => _showAdvancedServer = !_showAdvancedServer);
                        },
                      ),
                    ],
                  ),
                  if (_showAdvancedServer) ...[
                    const Divider(height: 24),
                    Text(
                      'Backend API URL (${auth.resolvedApiBaseUrl ?? 'Not set on mobile'})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: subtleText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Netlify Site URL (e.g. https://lifecheckpoint.netlify.app)',
                        hintText: 'Leave blank on Web PWA for same-origin /api',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await auth.setCustomServerUrl(_serverUrlCtrl.text);
                              final health = await auth.checkHealth();
                              _showSnack(
                                health.ok
                                    ? 'Connected to Netlify + Supabase API!'
                                    : (health.error ?? 'Could not reach server.'),
                                isError: !health.ok,
                              );
                            },
                            child: const Text('Save & Test Connection'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Signed-In Household Card OR Login/Register Form
          if (auth.isAuthenticated)
            _buildSignedInCard(auth, isDark, headingColor, subtleText, accentNavy)
          else
            _buildAuthFormCard(auth, isDark, headingColor, subtleText, accentNavy),

          const SizedBox(height: 16),

          // 3. Researcher Chapter 4 Analytics Card (for Admin or Researcher Code)
          _buildResearcherPortalCard(
            auth,
            isDark,
            headingColor,
            subtleText,
            accentNavy,
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInCard(
    AuthProvider auth,
    bool isDark,
    Color headingColor,
    Color subtleText,
    Color accentNavy,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryNavy,
                  child: const Icon(Icons.family_restroom, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.fullName ?? 'Household Member',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: headingColor,
                        ),
                      ),
                      Text(
                        '${auth.email ?? ''} • ${auth.role.toUpperCase()}',
                        style: TextStyle(fontSize: 13, color: subtleText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Household: ${auth.householdName ?? 'My Household'}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBg : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAMILY INVITE CODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subtleText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          auth.inviteCode ?? '------',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: accentNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Invite Code',
                    onPressed: () {
                      final code = auth.inviteCode ?? '';
                      if (code.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: code));
                        _showSnack('Invite code $code copied!');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Join another family invite code',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (_joinCodeCtrl.text.trim().isEmpty) return;
                    final res = await auth.joinHousehold(_joinCodeCtrl.text);
                    _showSnack(
                      res.ok
                          ? 'Joined household & synced supplies!'
                          : (res.error ?? 'Invalid invite code.'),
                      isError: !res.ok,
                    );
                  },
                  child: const Text('Join'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
                label: const Text(
                  'Sign Out (Keep Local Offline Data)',
                  style: TextStyle(color: AppTheme.dangerRed),
                ),
                onPressed: () => auth.logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthFormCard(
    AuthProvider auth,
    bool isDark,
    Color headingColor,
    Color subtleText,
    Color accentNavy,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRegisterMode
                  ? 'Create Household Cloud Account'
                  : 'Sign In to Sync Across Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Optional: Continue using LifeCheckpoint offline anytime, or sign in to share your Go-Bag, expiry alerts, and family check-ins across Web & Android.',
              style: TextStyle(fontSize: 13.5, color: subtleText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Sign In')),
                    selected: !_isRegisterMode,
                    onSelected: (_) => setState(() => _isRegisterMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Register')),
                    selected: _isRegisterMode,
                    onSelected: (_) => setState(() => _isRegisterMode = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isRegisterMode) ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (min 6 characters) *',
              ),
            ),
            if (_isRegisterMode) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _householdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Household Name (optional, e.g. Dela Cruz Family)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _inviteCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Family Invite Code (optional — to join existing kit)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _adminCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'EAC Researcher / Admin Code (optional)',
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitAuth(auth),
                child: Text(
                  _isSubmitting
                      ? 'Please wait...'
                      : (_isRegisterMode
                          ? 'Create Account & Sync'
                          : 'Sign In & Sync'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearcherPortalCard(
    AuthProvider auth,
    bool isDark,
    Color headingColor,
    Color subtleText,
    Color accentNavy,
  ) {
    final means = _evalSummary?['means'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: accentNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chapter 4 Research Survey Analytics (ISO/IEC 25010)',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: headingColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              auth.isAdmin
                  ? 'Admin access verified. View aggregated Metro Manila respondent scores or export CSV.'
                  : 'For EAC researchers: Sign in as Admin (or enter Admin Code above) to pull aggregated survey data.',
              style: TextStyle(fontSize: 13.5, color: subtleText),
            ),
            const SizedBox(height: 10),
            if (!auth.isAdmin) ...[
              TextField(
                controller: _adminCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Researcher Admin Code (for Chapter 4 Export)',
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(_loadingSummary ? 'Loading...' : 'Load Summary'),
                    onPressed: _loadingSummary
                        ? null
                        : () => _loadEvaluationSummary(
                              adminCode: _adminCodeCtrl.text,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Copy CSV'),
                    onPressed: () => _copyCsv(adminCode: _adminCodeCtrl.text),
                  ),
                ),
              ],
            ),
            if (means != null) ...[
              const Divider(height: 20),
              Text(
                'Total Respondents: ${_evalSummary?['totalRespondents'] ?? 0}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: accentNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• Functionality Mean: ${means['functionality']} / 5.00\n'
                '• Usability Mean: ${means['usability']} / 5.00\n'
                '• Offline Reliability Mean: ${means['offlineReliability']} / 5.00\n'
                '• Preparedness Effectiveness Mean: ${means['effectiveness']} / 5.00\n'
                '• Overall Weighted Mean: ${means['overallMean']} / 5.00\n'
                '• Avg Kit Readiness: ${means['averageReadinessPct']}%',
                style: TextStyle(fontSize: 14, height: 1.45, color: headingColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
