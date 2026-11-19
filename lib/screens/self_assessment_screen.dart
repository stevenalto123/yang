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
import '../widgets/responsive_container.dart';
import 'account_sync_screen.dart';

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
                      ? 'Nai-save offline — awtomatikong magsi-sync sa cloud kapag may internet!'
                      : 'Saved locally & queued for cloud sync when online!')
                  : (isFil
                      ? 'Nai-save at naipadala na sa cloud database!'
                      : 'ISO/IEC 25010 Evaluation submitted to cloud database!'))
              : (res.error ?? 'Saved locally; cloud sync error.'),
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
    buf.writeln('LIFECHECKPOINT CAPSTONE EVALUATION REPORT (SLIDE 6)');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('--------------------------------------------------');
    buf.writeln('1. KIT COMPLETENESS SELF-CHECKLIST');
    buf.writeln(
      'Weighted Survival Score: ${kit.readinessPercentage.toStringAsFixed(1)}% (${kit.readinessStatus})',
    );
    buf.writeln(
      'Raw Item Completion: ${kit.rawCompletionPercentage.toStringAsFixed(1)}% (${kit.packedItemsCount} / ${kit.totalItemsCount})',
    );
    buf.writeln('Missing / Incomplete: ${kit.missingItemsCount}');
    buf.writeln('Expired Items: ${kit.expiredItemsCount}');
    buf.writeln('Expiring Soon: ${kit.expiringSoonItemsCount}');
    buf.writeln('');
    buf.writeln('2. PARTICIPANT EVALUATION SURVEY (1-5 LIKERT SCALE)');
    buf.writeln('Q1. Functional Suitability (RQ3): $_functionalityScore / 5');
    buf.writeln('Q2. Usability & Ease of Use (RQ3): $_usabilityScore / 5');
    buf.writeln('Q3. Offline Reliability (Non, 2026): $_offlineReliabilityScore / 5');
    buf.writeln(
      'Q4. Household Preparedness Effectiveness (RQ4): $_preparednessImpactScore / 5',
    );
    buf.writeln('Overall Weighted Mean: ${meanScore.toStringAsFixed(2)} / 5.00');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFil
              ? 'Nakopya na ang ulat ng kahandaan!'
              : 'Full Readiness & Survey Report copied to clipboard!',
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
    final weightedScore = kit.readinessPercentage;
    final rawScore = kit.rawCompletionPercentage;

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;
    final accentNavy = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.readinessAudit),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_returned_outlined),
            tooltip: isFil ? 'Kopyahin ang Ulat' : 'Copy Assessment Report',
            onPressed: () => _copyFullReport(kit, isFil),
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 860,
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // Header Card showing BOTH Weighted Survival Score and Raw Completion %
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryNavy, AppTheme.primaryNavyDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assignment_turned_in,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFil
                            ? 'Pagsusuri ng Kahandaan ng Sambahayan'
                            : 'Household Preparedness Audit',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isFil
                      ? 'Batay sa Philippine DRRM 72-Hour Go-Bag standards. Mas mataas ang bigat ng Tubig, Pagkain, at Medikal (3×).'
                      : 'Based on Philippine DRRM 72-Hour Survival Go-Bag standards. Essential survival items (Water, Food, Medical) carry 3× weight.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade200,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.weightedScoreLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${weightedScore.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            s.readinessStatus(weightedScore).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.amberAccent,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isFil ? 'Raw' : 'Raw Items'}: ${rawScore.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '$packed / $total ${isFil ? 'Kumpleto' : 'Packed'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Breakdown Progress Bars
          Text(
            isFil ? 'Kumpleto bawat Kategorya' : 'Completeness by Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
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

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${s.categoryName(category)} (${category.priorityWeight}×)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: headingColor,
                            ),
                          ),
                        ),
                        Text(
                          '$catPacked / ${categoryItems.length} (${(catProgress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: catProgress >= 0.8
                                ? (isDark
                                    ? Colors.green.shade300
                                    : AppTheme.safeGreen)
                                : subtleText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: catProgress,
                        backgroundColor:
                            isDark ? AppTheme.darkBg : Colors.grey.shade200,
                        color: catProgress >= 0.8
                            ? AppTheme.safeGreen
                            : (catProgress >= 0.4
                                ? AppTheme.warningAmber
                                : AppTheme.dangerRed),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Audit Checklist Observations
          Text(
            isFil ? 'Mga Natuklasan sa Kit' : 'Kit Readiness Findings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 10),

          _buildAuditFinding(
            isDark: isDark,
            icon: expired == 0 ? Icons.check_circle : Icons.cancel,
            color: expired == 0
                ? (isDark ? Colors.green.shade300 : AppTheme.safeGreen)
                : (isDark ? Colors.red.shade300 : AppTheme.dangerRed),
            title: expired == 0
                ? (isFil ? 'Walang Pasong Gamit' : 'Zero Expired Supplies')
                : '$expired Expired Supply Item(s) Detected',
            subtitle: expired == 0
                ? 'All emergency medicines and food rations are within valid safety shelf-life.'
                : 'Replace expired medications and consumables immediately before disaster strikes.',
          ),
          _buildAuditFinding(
            isDark: isDark,
            icon: expiringSoon == 0
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: expiringSoon == 0
                ? (isDark ? Colors.green.shade300 : AppTheme.safeGreen)
                : (isDark ? Colors.amber.shade300 : AppTheme.warningAmber),
            title: expiringSoon == 0
                ? (isFil
                    ? 'Walang Malapit Ma-expire'
                    : 'No Immediate Expiring Items')
                : '$expiringSoon Item(s) Expiring within ${kit.expiryAlertDays} Days',
            subtitle: expiringSoon == 0
                ? 'No items require near-term replenishment.'
                : 'Plan grocery rotation for items approaching expiration dates.',
          ),

          const SizedBox(height: 18),

          // Interactive ISO 25010 Usability & Effectiveness Survey (Slide 6)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.blue.shade200,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.poll_outlined, color: accentNavy, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Structured Evaluation Survey (ISO/IEC 25010)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: accentNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rate the application from 1 (Strongly Disagree) to 5 (Strongly Agree).',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                  const Divider(height: 20),
                  _buildLikertSlider(
                    isDark,
                    accentNavy,
                    '1. Functionality: Kit checklist, expiry tracking & emergency guides work accurately.',
                    _functionalityScore,
                    (v) => setState(() => _functionalityScore = v),
                  ),
                  _buildLikertSlider(
                    isDark,
                    accentNavy,
                    '2. Usability: Interface is clear, responsive, and easy to navigate.',
                    _usabilityScore,
                    (v) => setState(() => _usabilityScore = v),
                  ),
                  _buildLikertSlider(
                    isDark,
                    accentNavy,
                    '3. Offline Reliability: Essential data remains accessible with no internet.',
                    _offlineReliabilityScore,
                    (v) => setState(() => _offlineReliabilityScore = v),
                  ),
                  _buildLikertSlider(
                    isDark,
                    accentNavy,
                    '4. Effectiveness: Improves household disaster preparedness and readiness.',
                    _preparednessImpactScore,
                    (v) => setState(() => _preparednessImpactScore = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _respondentCtrl,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Pangalan ng Respondent / Barangay (opsyonal)'
                          : 'Respondent Label / Barangay (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: isFil
                          ? 'Komento o Suhestiyon (opsyonal)'
                          : 'Feedback / Comments (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: Icon(_surveySubmitted ? Icons.check : Icons.save),
                          label: Text(
                            _isSubmitting
                                ? 'Submitting...'
                                : (_surveySubmitted
                                    ? (isFil
                                        ? 'Nai-save (I-update)'
                                        : 'Evaluation Saved (Update)')
                                    : (isFil ? 'I-submit' : 'Submit Evaluation')),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => _saveSurvey(isFil, kit),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(isFil ? 'Kopya' : 'Export'),
                        onPressed: () => _copyFullReport(kit, isFil),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: Text(
                        isFil
                            ? 'Buksan ang Researcher Analytics & CSV Export'
                            : 'Researcher Chapter 4 Analytics & CSV Export',
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSyncScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
      padding: const EdgeInsets.only(bottom: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primaryNavy.withAlpha(110)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$score / 5',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
            activeColor: AppTheme.primaryNavy,
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
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
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
