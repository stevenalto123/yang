import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/kit_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/privacy_notice_dialog.dart';
import '../widgets/responsive_container.dart';

class AccountSyncScreen extends StatefulWidget {
  const AccountSyncScreen({super.key});

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _acceptedPrivacy = false;

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
      _showSnack('Please enter your email and password.', isError: true);
      return;
    }
    if (_isRegisterMode && !_acceptedPrivacy) {
      _showSnack(
        'Please review and accept the RA 10173 Data Privacy Notice first.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = _isRegisterMode
        ? await auth.register(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim().isEmpty
                ? 'Family Member'
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
            ? 'Account created and synced with your family!'
            : 'Signed in and synced!',
      );
      if (auth.isAdmin) _loadEvaluationSummary();
    } else {
      _showSnack(res.error ?? 'Sign in failed. Please try again.', isError: true);
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
      _showSnack(
        res.error ?? 'Unable to load evaluation summary.',
        isError: true,
      );
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
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil ? 'Family Backup at Sync' : 'Family Backup & Sync',
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 740,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // 1. Clean Sync Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (auth.isAuthenticated
                                    ? AppTheme.safeGreen
                                    : AppTheme.primaryAccent)
                                .withAlpha(isDark ? 45 : 20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            auth.isAuthenticated
                                ? Icons.cloud_done_rounded
                                : Icons.smartphone_rounded,
                            color: auth.isAuthenticated
                                ? AppTheme.safeGreen
                                : accentNavy,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.isAuthenticated
                                    ? (isFil
                                        ? 'Naka-sync sa Iyong Pamilya'
                                        : 'Synced with Your Family')
                                    : (isFil
                                        ? 'Naka-save sa Device na Ito'
                                        : 'Saved on This Device'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: headingColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                auth.lastSyncedAt != null
                                    ? (isFil
                                        ? 'Huling sync: ${DateFormat('MMM d, h:mm a').format(auth.lastSyncedAt!)}'
                                        : 'Last synced: ${DateFormat('MMM d, h:mm a').format(auth.lastSyncedAt!)}')
                                    : (auth.pendingSyncCount > 0
                                        ? (isFil
                                            ? '${auth.pendingSyncCount} pagbabago ang naghihintay i-sync'
                                            : '${auth.pendingSyncCount} change(s) ready to sync')
                                        : (isFil
                                            ? 'Gumagana offline — opsyonal ang pag-sign in'
                                            : 'Works offline — sign in anytime to back up')),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: subtleText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (auth.lastSyncError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        auth.lastSyncError!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.warningAmber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (auth.isAuthenticated) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: auth.isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            auth.isSyncing
                                ? (isFil ? 'Nagsi-sync...' : 'Syncing...')
                                : (isFil ? 'I-sync Ngayon' : 'Sync Now'),
                          ),
                          onPressed: auth.isSyncing
                              ? null
                              : () async {
                                  final res = await auth.syncNow();
                                  _showSnack(
                                    res.ok
                                        ? 'Everything is up to date!'
                                        : (res.error ??
                                            'Saved offline. Will sync when online.'),
                                    isError: !res.ok,
                                  );
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Signed-In Household Card OR Clean Sign In / Create Account Card
            if (auth.isAuthenticated)
              _buildSignedInCard(
                auth,
                isDark,
                isFil,
                headingColor,
                subtleText,
                accentNavy,
              )
            else
              _buildAuthFormCard(
                auth,
                isDark,
                isFil,
                headingColor,
                subtleText,
                accentNavy,
              ),

            const SizedBox(height: 16),

            // 3. Data Privacy & User Rights (RA 10173)
            _buildPrivacyComplianceCard(
              auth,
              isFil,
              headingColor,
              subtleText,
              accentNavy,
            ),
            const SizedBox(height: 16),

            // 4. Collapsed Researcher & Advanced Tools (hidden from regular household clutter)
            _buildResearcherAndAdvancedTile(
              auth,
              isDark,
              isFil,
              headingColor,
              subtleText,
              accentNavy,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedInCard(
    AuthProvider auth,
    bool isDark,
    bool isFil,
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
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.fullName ?? 'Family Member',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      Text(
                        auth.email ?? '',
                        style: TextStyle(fontSize: 13.5, color: subtleText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              '${isFil ? 'Pamilya' : 'Household'}: ${auth.householdName ?? 'My Family'}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFil
                              ? 'FAMILY INVITE CODE (IBAHAGI SA PAMILYA)'
                              : 'FAMILY INVITE CODE (SHARE WITH RELATIVES)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: subtleText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          auth.inviteCode ?? '------',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                            color: accentNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded),
                    tooltip: isFil ? 'Kopyahin ang Code' : 'Copy Code',
                    onPressed: () {
                      final code = auth.inviteCode ?? '';
                      if (code.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: code));
                        _showSnack('Family code $code copied!');
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
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Sumali sa ibang Family Code'
                          : 'Join another family code',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (_joinCodeCtrl.text.trim().isEmpty) return;
                    final res = await auth.joinHousehold(_joinCodeCtrl.text);
                    _showSnack(
                      res.ok
                          ? 'Joined household and synced supplies!'
                          : (res.error ?? 'Invalid family code.'),
                      isError: !res.ok,
                    );
                  },
                  child: Text(isFil ? 'Sumali' : 'Join'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.dangerRed,
                ),
                label: Text(
                  isFil
                      ? 'Mag-sign Out (Mananatili ang Offline Data)'
                      : 'Sign Out (Keep Offline Data on Device)',
                  style: const TextStyle(color: AppTheme.dangerRed),
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
    bool isFil,
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
                  ? (isFil
                      ? 'Gumawa ng Family Account'
                      : 'Create a Family Account')
                  : (isFil
                      ? 'Mag-sign In para sa Backup'
                      : 'Sign In to Back Up & Share'),
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFil
                  ? 'Opsyonal: Gamitin ang app nang offline kahit walang account, o mag-sign in para maibahagi ang Go-Bag checklist at safety check-ins sa buong pamilya.'
                  : 'Optional: Use LifeCheckpoint offline without an account, or sign in to share your Go-Bag list and safety check-ins across family phones.',
              style: TextStyle(fontSize: 13.5, color: subtleText, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(isFil ? 'Mag-sign In' : 'Sign In'),
                    ),
                    selected: !_isRegisterMode,
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      color: !_isRegisterMode ? Colors.white : headingColor,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _isRegisterMode = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(
                      child: Text(isFil ? 'Gumawa ng Account' : 'Create Account'),
                    ),
                    selected: _isRegisterMode,
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      color: _isRegisterMode ? Colors.white : headingColor,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() => _isRegisterMode = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isRegisterMode) ...[
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: isFil ? 'Buong Pangalan *' : 'Your Name *',
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: isFil ? 'Email Address *' : 'Email Address *',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: isFil
                    ? 'Password (hindi bababa sa 6 na karakter) *'
                    : 'Password (at least 6 characters) *',
              ),
            ),
            if (_isRegisterMode) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _householdCtrl,
                decoration: InputDecoration(
                  labelText: isFil
                      ? 'Pangalan ng Pamilya (hal. Pamilya Dela Cruz)'
                      : 'Family Name (optional, e.g. Dela Cruz Family)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _inviteCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: isFil
                      ? 'Family Invite Code (opsyonal — kung sasali sa pamilya)'
                      : 'Family Invite Code (optional — to join an existing kit)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _acceptedPrivacy,
                    activeColor: AppTheme.primaryNavy,
                    onChanged: (v) =>
                        setState(() => _acceptedPrivacy = v ?? false),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isFil
                              ? 'Sumasang-ayon ako sa RA 10173 Data Privacy Notice.'
                              : 'I agree to the RA 10173 Data Privacy Notice.',
                          style: TextStyle(fontSize: 13, color: subtleText),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () =>
                              PrivacyNoticeDialog.show(context, isFil: isFil),
                          child: Text(
                            isFil ? 'Basahin' : 'Read Notice',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : () => _submitAuth(auth),
                child: Text(
                  _isSubmitting
                      ? (isFil ? 'Sandali lang...' : 'Please wait...')
                      : (_isRegisterMode
                          ? (isFil
                              ? 'Gumawa ng Account at I-sync'
                              : 'Create Account & Back Up')
                          : (isFil ? 'Mag-sign In' : 'Sign In')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyComplianceCard(
    AuthProvider auth,
    bool isFil,
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
                Icon(Icons.verified_user_outlined, color: accentNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFil
                        ? 'Privacy at Seguridad ng Datos (RA 10173)'
                        : 'Privacy & Your Data Rights (RA 10173)',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isFil
                  ? 'Ligtas na naka-encrypt ang iyong impormasyon. Maaari mong basahin ang privacy notice o burahin ang naka-save na datos sa device anumang oras.'
                  : 'Your household details are encrypted and private. You can read our Data Privacy Notice or clear local device storage anytime.',
              style: TextStyle(fontSize: 13.5, color: subtleText, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.policy_outlined, size: 18),
                    label: Text(isFil ? 'Privacy Notice' : 'Privacy Notice'),
                    onPressed: () =>
                        PrivacyNoticeDialog.show(context, isFil: isFil),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      side: BorderSide(
                        color: AppTheme.dangerRed.withAlpha(150),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(
                      isFil ? 'Burahin Datos' : 'Erase Local Data',
                    ),
                    onPressed: () => _confirmEraseLocalData(auth, isFil),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResearcherAndAdvancedTile(
    AuthProvider auth,
    bool isDark,
    bool isFil,
    Color headingColor,
    Color subtleText,
    Color accentNavy,
  ) {
    final means = _evalSummary?['means'] as Map<String, dynamic>?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: auth.isAdmin,
          leading: Icon(Icons.tune_rounded, color: subtleText),
          title: Text(
            isFil
                ? 'Para sa Researcher at Advanced Settings'
                : 'Researcher & Advanced Tools',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: headingColor,
            ),
          ),
          subtitle: Text(
            isFil
                ? 'EAC Survey Export (CSV) at Server Settings'
                : 'EAC Chapter 4 Survey Analytics (CSV) & Server URL',
            style: TextStyle(fontSize: 12.5, color: subtleText),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ISO/IEC 25010 Survey Analytics (EAC Researchers)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!auth.isAdmin) ...[
              TextField(
                controller: _adminCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Researcher Admin Code',
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
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
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Copy CSV'),
                    onPressed: () => _copyCsv(adminCode: _adminCodeCtrl.text),
                  ),
                ),
              ],
            ),
            if (means != null) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Respondents: ${_evalSummary?['totalRespondents'] ?? 0}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: accentNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Functionality: ${means['functionality']} / 5.00\n'
                      '• Usability: ${means['usability']} / 5.00\n'
                      '• Offline Reliability: ${means['offlineReliability']} / 5.00\n'
                      '• Effectiveness: ${means['effectiveness']} / 5.00\n'
                      '• Overall Mean: ${means['overallMean']} / 5.00\n'
                      '• Avg Kit Readiness: ${means['averageReadinessPct']}%',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: headingColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Custom Cloud Server URL (Optional for Android APK)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _serverUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Server URL (leave blank on Web)',
                hintText: 'https://yangjd.netlify.app',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await auth.setCustomServerUrl(_serverUrlCtrl.text);
                  final health = await auth.checkHealth();
                  _showSnack(
                    health.ok
                        ? 'Connected to cloud server!'
                        : (health.error ?? 'Could not reach server.'),
                    isError: !health.ok,
                  );
                },
                child: const Text('Save & Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEraseLocalData(AuthProvider auth, bool isFil) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil ? 'Burahin ang Lokal na Datos?' : 'Erase Local Device Data?',
        ),
        content: Text(
          isFil
              ? 'Aalisin nito ang iyong session at naka-save na plano sa device na ito alinsunod sa RA 10173.'
              : 'This signs you out and clears locally stored plans, contacts, and offline data from this device under RA 10173.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isFil ? 'Burahin' : 'Erase Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final kit = context.read<KitProvider>();
      await auth.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await kit.loadItems();
      _showSnack(
        isFil
            ? 'Nabura na ang lokal na datos.'
            : 'All local device data has been erased.',
      );
    }
  }
}
