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
import 'admin_dashboard_screen.dart';

class AccountSyncScreen extends StatefulWidget {
  const AccountSyncScreen({super.key});

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  bool _acceptedPrivacy = false;
  bool _obscurePassword = true;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _householdCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _joinCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _householdCtrl.dispose();
    _inviteCtrl.dispose();
    _joinCodeCtrl.dispose();
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
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter your email and password.', isError: true);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showSnack('Please enter a valid email address.', isError: true);
      return;
    }
    if (_isRegisterMode && password.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
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
          )
        : await auth.login(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.ok) {
      if (auth.isAdmin) {
        _showSnack('Signed in as Admin! Opening Admin Portal...');
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        _showSnack(
          _isRegisterMode
              ? 'Account created and synced with your family!'
              : 'Signed in and synced!',
        );
      }
    } else {
      _showSnack(
        res.error ?? 'Sign in failed. Please check your email and password.',
        isError: true,
      );
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
          auth.isAdmin
              ? 'Admin Account'
              : (isFil ? 'Family Backup at Sync' : 'Family Backup & Sync'),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: 740,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // 1. Clean Sync Status Card (Households only — Admins don't need Family Sync)
            if (!auth.isAdmin) ...[
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
            ],

            // 2. Signed-In Household/Admin Card OR Unified Sign In / Create Account Card
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
                  backgroundColor: auth.isAdmin
                      ? AppTheme.primaryAccent
                      : AppTheme.primaryNavy,
                  child: Icon(
                    auth.isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.family_restroom_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              auth.fullName ?? 'Family Member',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                          ),
                          if (auth.isAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent
                                    .withAlpha(isDark ? 60 : 22),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.lightBlue.shade200
                                      : AppTheme.primaryAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
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

            // Admin Portal Shortcut (ONLY visible when signed in as Admin)
            if (auth.isAdmin) ...[
              const SizedBox(height: 12),
              Text(
                'Signed in as an authorized DRRM Administrator. Manage official City of Manila shelters, monitor family check-ins, and export ISO/IEC 25010 surveys.',
                style: TextStyle(fontSize: 13.5, color: subtleText, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.admin_panel_settings_rounded, size: 19),
                  label: Text(
                    isFil
                        ? 'Buksan ang Admin & DRRM Portal'
                        : 'Open Admin & DRRM Portal',
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.dangerRed,
                  ),
                  label: const Text(
                    'Sign Out of Admin Account',
                    style: TextStyle(color: AppTheme.dangerRed),
                  ),
                  onPressed: () => auth.logout(),
                ),
              ),
            ] else ...[
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
                  icon: const Icon(Icons.key_outlined, size: 19),
                  label: Text(
                    isFil ? 'Palitan ang Password' : 'Change Password',
                  ),
                  onPressed: () => _showChangePasswordDialog(auth, isFil),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.dangerRed,
                  ),
                  label: Text(
                    isFil
                        ? 'Mag-sign Out (Ligtas ang Data sa Cloud)'
                        : 'Sign Out (Cloud Backup Stays Safe)',
                    style: const TextStyle(color: AppTheme.dangerRed),
                  ),
                  onPressed: () => auth.logout(),
                ),
              ),
            ],
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
                  : 'Optional: Use LifeCheckpoint offline without an account, or sign in with your family or admin account to sync across devices.',
              style: TextStyle(fontSize: 13.5, color: subtleText, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
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
                    showCheckmark: false,
                    label: Center(
                      child:
                          Text(isFil ? 'Gumawa ng Account' : 'Create Account'),
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
              decoration: const InputDecoration(
                labelText: 'Email Address *',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              onSubmitted: (_) {
                if (!_isRegisterMode && !_isSubmitting) _submitAuth(auth);
              },
              decoration: InputDecoration(
                labelText: isFil
                    ? 'Password (hindi bababa sa 6 na karakter) *'
                    : 'Password (at least 6 characters) *',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscurePassword
                      ? (isFil ? 'Ipakita ang password' : 'Show password')
                      : (isFil ? 'Itago ang password' : 'Hide password'),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            if (!_isRegisterMode) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.lock_reset_rounded, size: 17),
                  label: Text(
                    isFil ? 'Nakalimutan ang Password?' : 'Forgot Password?',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _showForgotPasswordDialog(auth, isFil),
                ),
              ),
            ],
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
                      isFil ? 'Burahin Lokal' : 'Erase Local Data',
                    ),
                    onPressed: () => _confirmEraseLocalData(auth, isFil),
                  ),
                ),
              ],
            ),
            if (auth.isAuthenticated && !auth.isAdmin) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: BorderSide(
                      color: AppTheme.dangerRed.withAlpha(160),
                    ),
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: Text(
                    isFil
                        ? 'Burahin ang Cloud Account (RA 10173)'
                        : 'Delete Cloud Account & Data (RA 10173)',
                  ),
                  onPressed: () => _confirmDeleteCloudAccount(auth, isFil),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCloudAccount(
    AuthProvider auth,
    bool isFil,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil
              ? 'Burahin ang Cloud Account?'
              : 'Delete Cloud Account Permanently?',
        ),
        content: Text(
          isFil
              ? 'Permanenteng buburahin ang iyong account sa cloud alinsunod sa RA 10173 (Right to Erasure). Kung ikaw lang ang miyembro ng sambahayan, mabubura rin ang naka-save na Go-Bag, plano, at check-ins sa cloud.'
              : 'This permanently deletes your account from Supabase under RA 10173 (Right to Erasure). If you are the only member of your household, all cloud Go-Bag items, plans, and check-ins will also be permanently erased.',
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
            child: Text(isFil ? 'Burahin Account' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final res = await auth.deleteCloudAccount();
      if (!mounted) return;
      if (res.ok) {
        _showSnack(
          isFil
              ? 'Permanenteng nabura na ang iyong cloud account.'
              : 'Your cloud account has been permanently deleted.',
        );
      } else {
        _showSnack(
          res.error ?? 'Failed to delete cloud account.',
          isError: true,
        );
      }
    }
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

  Future<void> _showForgotPasswordDialog(AuthProvider auth, bool isFil) async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureNew = true;
    bool isSendingCode = false;
    bool codeSent = false;
    bool isSubmitting = false;
    String? infoMsg;
    String? errorMsg;

    final didReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> sendCode() async {
            final email = emailCtrl.text.trim();
            if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
              setDialogState(
                () => errorMsg = isFil
                    ? 'Maglagay ng wastong email address.'
                    : 'Please enter a valid email address.',
              );
              return;
            }
            setDialogState(() {
              isSendingCode = true;
              errorMsg = null;
              infoMsg = null;
            });
            final res = await auth.requestPasswordResetCode(email: email);
            if (!ctx.mounted) return;
            setDialogState(() {
              isSendingCode = false;
              if (res.ok) {
                codeSent = true;
                infoMsg = isFil
                    ? 'Naipadala ang 6-digit code sa iyong email (tingnan din ang Spam). May bisa ito sa loob ng 15 minuto.'
                    : '6-digit reset code sent! Check your Gmail inbox (and Spam folder). Valid for 15 minutes.';
              } else {
                errorMsg = res.error ?? 'Could not send reset email.';
              }
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppTheme.primaryNavy,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFil ? 'I-reset ang Password' : 'Reset Forgotten Password',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFil
                          ? 'Ilagay ang iyong email address para makatanggap ng 6-digit na reset code sa iyong Gmail.'
                          : 'Enter your registered email address and we will send a 6-digit verification code to your inbox.',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isSendingCode && !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email_outlined, size: 19),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        icon: isSendingCode
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 17),
                        label: Text(
                          isSendingCode
                              ? (isFil ? 'Ipinapadala...' : 'Sending Code...')
                              : (codeSent
                                  ? (isFil
                                      ? 'Ipadala Ulit ang 6-Digit Code'
                                      : 'Resend 6-Digit Code')
                                  : (isFil
                                      ? 'Ipadala ang 6-Digit Code sa Email'
                                      : 'Send 6-Digit Code to Email')),
                        ),
                        onPressed:
                            isSendingCode || isSubmitting ? null : sendCode,
                      ),
                    ),
                    if (infoMsg != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.safeGreen.withAlpha(24),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.safeGreen.withAlpha(100),
                          ),
                        ),
                        child: Text(
                          infoMsg!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.safeGreen,
                          ),
                        ),
                      ),
                    ],
                    if (codeSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: isFil
                              ? '6-Digit Code mula sa Email *'
                              : '6-Digit Email Code *',
                          hintText: 'e.g. 482915',
                          prefixIcon: const Icon(Icons.pin_outlined, size: 19),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: isFil
                              ? 'Bagong Password (min. 6 karakter) *'
                              : 'New Password (min. 6 characters) *',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmPassCtrl,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: isFil
                              ? 'Ulitin ang Bagong Password *'
                              : 'Confirm New Password *',
                        ),
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: Text(isFil ? 'Kanselahin' : 'Cancel'),
              ),
              if (codeSent)
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          final code = codeCtrl.text.trim();
                          final np = newPassCtrl.text;
                          final cp = confirmPassCtrl.text;

                          if (code.length != 6) {
                            setDialogState(
                              () => errorMsg = isFil
                                  ? 'Ilagay ang 6-digit na code mula sa iyong email.'
                                  : 'Please enter the 6-digit code sent to your email.',
                            );
                            return;
                          }
                          if (np.length < 6) {
                            setDialogState(
                              () => errorMsg = isFil
                                  ? 'Dapat hindi bababa sa 6 na karakter ang bagong password.'
                                  : 'New password must be at least 6 characters.',
                            );
                            return;
                          }
                          if (np != cp) {
                            setDialogState(
                              () => errorMsg = isFil
                                  ? 'Hindi magkatugma ang bagong password.'
                                  : 'Passwords do not match.',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMsg = null;
                          });
                          final res = await auth.resetPassword(
                            email: email,
                            code: code,
                            newPassword: np,
                          );
                          if (!ctx.mounted) return;
                          if (res.ok) {
                            _emailCtrl.text = email;
                            _passwordCtrl.clear();
                            Navigator.pop(ctx, true);
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMsg = res.error ?? 'Reset failed.';
                            });
                          }
                        },
                  child: Text(
                    isSubmitting
                        ? (isFil ? 'Pinapalitan...' : 'Resetting...')
                        : (isFil ? 'I-reset ang Password' : 'Reset Password'),
                  ),
                ),
            ],
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      emailCtrl.dispose();
      codeCtrl.dispose();
      newPassCtrl.dispose();
      confirmPassCtrl.dispose();
    });

    if (didReset == true && mounted) {
      _showSnack(
        isFil
            ? 'Napalitan na ang iyong password! Maaari ka nang mag-sign in.'
            : 'Password updated! You can now sign in with your new password.',
      );
    }
  }

  Future<void> _showChangePasswordDialog(AuthProvider auth, bool isFil) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool isSubmitting = false;
    String? errorMsg;

    final didChange = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.key_rounded, color: AppTheme.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFil ? 'Palitan ang Password' : 'Change Password',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Kasalukuyang Password *'
                            : 'Current Password *',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Bagong Password (min. 6 karakter) *'
                            : 'New Password (min. 6 characters) *',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Ulitin ang Bagong Password *'
                            : 'Confirm New Password *',
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: Text(isFil ? 'Kanselahin' : 'Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final cur = currentCtrl.text;
                        final np = newCtrl.text;
                        final cp = confirmCtrl.text;
                        if (cur.isEmpty) {
                          setDialogState(
                            () => errorMsg = isFil
                                ? 'Ilagay ang kasalukuyang password.'
                                : 'Enter your current password.',
                          );
                          return;
                        }
                        if (np.length < 6) {
                          setDialogState(
                            () => errorMsg = isFil
                                ? 'Dapat hindi bababa sa 6 na karakter ang bagong password.'
                                : 'New password must be at least 6 characters.',
                          );
                          return;
                        }
                        if (np != cp) {
                          setDialogState(
                            () => errorMsg = isFil
                                ? 'Hindi magkatugma ang bagong password.'
                                : 'New passwords do not match.',
                          );
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          errorMsg = null;
                        });
                        final res = await auth.changePassword(
                          currentPassword: cur,
                          newPassword: np,
                        );
                        if (!ctx.mounted) return;
                        if (res.ok) {
                          Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMsg = res.error ?? 'Update failed.';
                          });
                        }
                      },
                child: Text(
                  isSubmitting
                      ? (isFil ? 'Sine-save...' : 'Saving...')
                      : (isFil ? 'I-save ang Password' : 'Update Password'),
                ),
              ),
            ],
          );
        },
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    });

    if (didChange == true && mounted) {
      _showSnack(
        isFil
            ? 'Matagumpay na napalitan ang iyong password!'
            : 'Password updated successfully!',
      );
    }
  }
}
