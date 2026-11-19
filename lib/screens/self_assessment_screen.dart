import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kit_item.dart';
import '../providers/auth_provider.dart';
import '../providers/kit_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/privacy_notice_dialog.dart';
import '../widgets/responsive_container.dart';

class SelfAssessmentScreen extends StatefulWidget {
  const SelfAssessmentScreen({super.key});

  @override
  State<SelfAssessmentScreen> createState() => _SelfAssessmentScreenState();
}

class _SelfAssessmentScreenState extends State<SelfAssessmentScreen> {
  static const String _surveyKey = 'lifecheckpoint_iso_survey_v1';

  int _functionalityScore = 5;
  int _usabilityScore = 5;
  int _offlineReliabilityScore = 5;
  int _preparednessImpactScore = 5;
  bool _surveySubmitted = false;
  bool _isSubmitting = false;
  bool _privacyConsented = false;

  final _respondentCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSurvey();
  }

  @override
  void dispose() {
    _respondentCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSurvey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_surveyKey);
      if (str != null && str.isNotEmpty) {
        final map = json.decode(str);
        setState(() {
          _functionalityScore = map['functionality'] ?? 5;
          _usabilityScore = map['usability'] ?? 5;
          _offlineReliabilityScore = map['reliability'] ?? 5;
          _preparednessImpactScore = map['effectiveness'] ?? 5;
          _surveySubmitted = map['submitted'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSurvey(bool isFil, KitProvider kit) async {
    if (!_privacyConsented) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.warningAmber,
          content: Text(
            isFil
                ? 'Paki-check muna ang pahintulot sa RA 10173 Data Privacy bago mag-submit.'
                : 'Please check the RA 10173 Data Privacy consent box before submitting.',
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _surveyKey,
        json.encode({
          'functionality': _functionalityScore,
          'usability': _usabilityScore,
          'reliability': _offlineReliabilityScore,
          'effectiveness': _preparednessImpactScore,
          'submitted': true,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}

    final auth = context.read<AuthProvider>();
    final res = await auth.submitEvaluation(
      respondentLabel: _respondentCtrl.text,
      functionalityScore: _functionalityScore,
      usabilityScore: _usabilityScore,
      reliabilityScore: _offlineReliabilityScore,
      effectivenessScore: _preparednessImpactScore,
      readinessPercentage: kit.readinessPercentage,
      rawCompletionPercentage: kit.rawCompletionPercentage,
      comments: _commentsCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _surveySubmitted = true;
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res.ok ? AppTheme.safeGreen : AppTheme.warningAmber,
        content: Text(
          res.ok
              ? (res.queuedOffline
                  ? (isFil
                      ? 'Nai-save offline — magsi-sync kapag may internet!'
                      : 'Saved on device — will sync automatically when online!')
                  : (isFil
                      ? 'Salamat! Naipadala na ang iyong feedback.'
                      : 'Thank you! Your feedback has been submitted.'))
              : (res.error ?? 'Saved on device.'),
        ),
      ),
    );
  }

  void _copyFullReport(KitProvider kit, bool isFil) {
    final meanScore = (_functionalityScore +
            _usabilityScore +
            _offlineReliabilityScore +
            _preparednessImpactScore) /
        4.0;
    final buf = StringBuffer();
    buf.writeln('LIFECHECKPOINT READINESS & FEEDBACK SUMMARY');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('--------------------------------------------------');
    buf.writeln(
      'Go-Bag Readiness: ${kit.readinessPercentage.toStringAsFixed(1)}% (${kit.readinessStatus})',
    );
    buf.writeln(
      'Packed Supplies: ${kit.packedItemsCount} / ${kit.totalItemsCount} (${kit.rawCompletionPercentage.toStringAsFixed(1)}%)',
    );
    buf.writeln('Missing: ${kit.missingItemsCount}');
    buf.writeln('Expired: ${kit.expiredItemsCount}');
    buf.writeln('Expiring Soon: ${kit.expiringSoonItemsCount}');
    buf.writeln('');
    buf.writeln('APP FEEDBACK (ISO/IEC 25010 • 1-5 SCALE)');
    buf.writeln('1. Functionality: $_functionalityScore / 5');
    buf.writeln('2. Usability: $_usabilityScore / 5');
    buf.writeln('3. Offline Reliability: $_offlineReliabilityScore / 5');
    buf.writeln('4. Preparedness Impact: $_preparednessImpactScore / 5');
    buf.writeln('Average Score: ${meanScore.toStringAsFixed(2)} / 5.00');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFil
              ? 'Nakopya na ang summary!'
              : 'Readiness summary copied to clipboard!',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final s = AppStrings(isFil);

    final total = kit.totalItemsCount;
    final packed = kit.packedItemsCount;
    final expired = kit.expiredItemsCount;
    final expiringSoon = kit.expiringSoonItemsCount;
    final readiness = kit.readinessPercentage;

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.readinessAudit),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: isFil ? 'Kopyahin ang Summary' : 'Copy Summary',
            onPressed: () => _copyFullReport(kit, isFil),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 820,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // Clean Readiness Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, AppTheme.primaryNavyDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.weightedScoreLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${readiness.toStringAsFixed(0)}% • ${s.readinessStatus(readiness)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isFil
                              ? '$packed sa $total gamit ang handa na. Mas pinahahalagahan ang Tubig, Pagkain, at Gamot.'
                              : '$packed of $total items packed. Water, food, and medicine weigh the most for 72-hour survival.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Category Breakdown
            Text(
              isFil ? 'Kahandaan Bawat Kategorya' : 'Progress by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 10),

            ...KitCategory.values.map((category) {
              final categoryItems = kit.allItems
                  .where((item) => item.category == category)
                  .toList();
              if (categoryItems.isEmpty) return const SizedBox.shrink();

              final catPacked = categoryItems
                  .where((item) => item.isComplete && !item.isExpired)
                  .length;
              final catProgress = catPacked / categoryItems.length;
              final isEssential = category.priorityWeight >= 3;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    s.categoryName(category),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: headingColor,
                                    ),
                                  ),
                                ),
                                if (isEssential) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryAccent
                                          .withAlpha(isDark ? 55 : 20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isFil ? 'Unahin' : 'Priority',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.lightBlue.shade200
                                            : AppTheme.primaryAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '$catPacked / ${categoryItems.length}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: catProgress >= 0.8
                                  ? AppTheme.safeGreen
                                  : subtleText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: catProgress,
                          backgroundColor: isDark
                              ? AppTheme.darkElevated
                              : AppTheme.lightBorder,
                          color: catProgress >= 0.8
                              ? AppTheme.safeGreen
                              : (catProgress >= 0.4
                                  ? AppTheme.warningAmber
                                  : AppTheme.dangerRed),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Quick Shelf-Life Findings
            _buildAuditFinding(
              isDark: isDark,
              icon: expired == 0
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              color: expired == 0 ? AppTheme.safeGreen : AppTheme.dangerRed,
              title: expired == 0
                  ? (isFil ? 'Walang Pasong Gamit' : 'No Expired Supplies')
                  : (isFil
                      ? '$expired Pasong Gamit ang Kailangang Palitan'
                      : '$expired Expired Item(s) Need Replacement'),
              subtitle: expired == 0
                  ? (isFil
                      ? 'Ligtas pang gamitin ang lahat ng pagkain at gamot sa Go-Bag.'
                      : 'All food, water, and medicines are within their shelf life.')
                  : (isFil
                      ? 'Palitan agad ang mga pasong gamit bago magkaroon ng sakuna.'
                      : 'Replace expired food or medicine right away.'),
            ),
            _buildAuditFinding(
              isDark: isDark,
              icon: expiringSoon == 0
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              color: expiringSoon == 0
                  ? AppTheme.safeGreen
                  : AppTheme.warningAmber,
              title: expiringSoon == 0
                  ? (isFil
                      ? 'Walang Malapit Ma-expire'
                      : 'Nothing Expiring Soon')
                  : (isFil
                      ? '$expiringSoon Gamit ang Mapapaso sa ${kit.expiryAlertDays} Araw'
                      : '$expiringSoon Item(s) Expiring Within ${kit.expiryAlertDays} Days'),
              subtitle: expiringSoon == 0
                  ? (isFil
                      ? 'Walang kailangang palitan sa mga susunod na linggo.'
                      : 'No supplies need replacing in the coming weeks.')
                  : (isFil
                      ? 'Isama sa susunod na pamimili ang mga mapapasong gamit.'
                      : 'Add these items to your next grocery trip.'),
            ),

            const SizedBox(height: 20),

            // Clean, Friendly App Feedback Survey (ISO/IEC 25010)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          color: accentNavy,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isFil
                                ? 'Magbigay ng Feedback sa App'
                                : 'Share Your Feedback',
                            style: TextStyle(
                              fontSize: 16.5,
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
                          ? 'Tulungan kaming pagandahin ang LifeCheckpoint para sa mga pamilyang Pilipino (1 = Hindi Sumasang-ayon hanggang 5 = Lubos na Sumasang-ayon).'
                          : 'Help improve LifeCheckpoint for Filipino households. Rate from 1 (Strongly Disagree) to 5 (Strongly Agree).',
                      style: TextStyle(fontSize: 13.5, color: subtleText),
                    ),
                    const Divider(height: 22),
                    _buildLikertSlider(
                      isDark,
                      accentNavy,
                      isFil
                          ? '1. Gumagana nang maayos ang Go-Bag checklist, alerts, at gabay.'
                          : '1. Features work well (Go-Bag checklist, expiry alerts, and guides).',
                      _functionalityScore,
                      (v) => setState(() => _functionalityScore = v),
                    ),
                    _buildLikertSlider(
                      isDark,
                      accentNavy,
                      isFil
                          ? '2. Malinis, malinaw, at madaling gamitin ang app.'
                          : '2. Easy to use and understand.',
                      _usabilityScore,
                      (v) => setState(() => _usabilityScore = v),
                    ),
                    _buildLikertSlider(
                      isDark,
                      accentNavy,
                      isFil
                          ? '3. Maaasahan pa rin ang app kahit walang internet.'
                          : '3. Reliable even without internet connection.',
                      _offlineReliabilityScore,
                      (v) => setState(() => _offlineReliabilityScore = v),
                    ),
                    _buildLikertSlider(
                      isDark,
                      accentNavy,
                      isFil
                          ? '4. Nakakatulong ito na mas maging handa ang aming pamilya.'
                          : '4. Helps my household become better prepared for disasters.',
                      _preparednessImpactScore,
                      (v) => setState(() => _preparednessImpactScore = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _respondentCtrl,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Pangalan o Barangay (opsyonal)'
                            : 'Your Name or Barangay (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _commentsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isFil
                            ? 'Suhestiyon o Komento (opsyonal)'
                            : 'Suggestions or Comments (optional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _privacyConsented,
                          activeColor: AppTheme.primaryNavy,
                          onChanged: (v) =>
                              setState(() => _privacyConsented = v ?? false),
                        ),
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                isFil
                                    ? 'Pumapayag akong isumite ito alinsunod sa RA 10173.'
                                    : 'I agree to submit this anonymized feedback under RA 10173.',
                                style:
                                    TextStyle(fontSize: 13, color: subtleText),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () => PrivacyNoticeDialog.show(
                                  context,
                                  isFil: isFil,
                                ),
                                child: Text(
                                  isFil ? 'Privacy Notice' : 'Privacy Notice',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: Icon(
                          _surveySubmitted
                              ? Icons.check_rounded
                              : Icons.send_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _isSubmitting
                              ? (isFil ? 'Ipinapadala...' : 'Submitting...')
                              : (_surveySubmitted
                                  ? (isFil
                                      ? 'Naipadala (I-update)'
                                      : 'Feedback Saved (Update)')
                                  : (isFil
                                      ? 'Ipadala ang Feedback'
                                      : 'Submit Feedback')),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => _saveSurvey(isFil, kit),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikertSlider(
    bool isDark,
    Color accentNavy,
    String label,
    int score,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.darkSlate,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentNavy.withAlpha(isDark ? 45 : 18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$score / 5',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: accentNavy,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: score.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$score',
            activeColor: accentNavy,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditFinding({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.darkSlate,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
