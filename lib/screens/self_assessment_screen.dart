import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../utils/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSurvey();
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

  Future<void> _saveSurvey() async {
    setState(() => _surveySubmitted = true);
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.safeGreen,
          content: Text('ISO/IEC 25010 Usability Evaluation recorded!'),
        ),
      );
    }
  }

  void _copyFullReport(KitProvider kit) {
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
        'Readiness Score: ${kit.readinessPercentage.toStringAsFixed(1)}% (${kit.readinessStatus})');
    buf.writeln(
        'Packed Supplies: ${kit.packedItemsCount} / ${kit.totalItemsCount}');
    buf.writeln('Missing / Incomplete: ${kit.missingItemsCount}');
    buf.writeln('Expired Items: ${kit.expiredItemsCount}');
    buf.writeln('Expiring Soon: ${kit.expiringSoonItemsCount}');
    buf.writeln('');
    buf.writeln('2. PARTICIPANT EVALUATION SURVEY (1-5 LIKERT SCALE)');
    buf.writeln('Q1. Functional Suitability (RQ3): $_functionalityScore / 5');
    buf.writeln('Q2. Usability & Ease of Use (RQ3): $_usabilityScore / 5');
    buf.writeln('Q3. Offline Reliability (Non, 2026): $_offlineReliabilityScore / 5');
    buf.writeln(
        'Q4. Household Preparedness Effectiveness (RQ4): $_preparednessImpactScore / 5');
    buf.writeln('Overall Weighted Mean: ${meanScore.toStringAsFixed(2)} / 5.00');

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Full Readiness & Survey Report copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();

    final total = kit.totalItemsCount;
    final packed = kit.packedItemsCount;
    final expired = kit.expiredItemsCount;
    final expiringSoon = kit.expiringSoonItemsCount;
    final score = kit.readinessPercentage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness Self-Assessment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_returned_outlined),
            tooltip: 'Copy Assessment Report',
            onPressed: () => _copyFullReport(kit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in,
                        color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Household Preparedness Audit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on Philippine DRRM 72-Hour Survival Go-Bag standards. Measures emergency kit completeness and system effectiveness (Slide 6 Instrumentation).',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade300, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${score.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          kit.readinessStatus.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amberAccent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$packed / $total Supplies Ready',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category Breakdown Progress Bars
          const Text(
            'Completeness by Category',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkSlate),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category.displayName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$catPacked / ${categoryItems.length} (${(catProgress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catProgress >= 0.8
                                ? AppTheme.safeGreen
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: catProgress,
                        backgroundColor: Colors.grey.shade200,
                        color: catProgress >= 0.8
                            ? AppTheme.safeGreen
                            : (catProgress >= 0.4
                                ? AppTheme.warningAmber
                                : AppTheme.accentAlert),
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
          const Text(
            'Kit Readiness Findings',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkSlate),
          ),
          const SizedBox(height: 10),

          _buildAuditFinding(
            icon: expired == 0 ? Icons.check_circle : Icons.cancel,
            color: expired == 0 ? AppTheme.safeGreen : AppTheme.accentAlert,
            title: expired == 0
                ? 'Zero Expired Supplies'
                : '$expired Expired Supply Item(s) Detected',
            subtitle: expired == 0
                ? 'All emergency medicines and food rations are within valid safety shelf-life.'
                : 'Replace expired medications and consumables immediately before disaster strikes.',
          ),
          _buildAuditFinding(
            icon: expiringSoon == 0
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: expiringSoon == 0 ? AppTheme.safeGreen : AppTheme.warningAmber,
            title: expiringSoon == 0
                ? 'No Immediate Expiring Items'
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
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.poll_outlined,
                          color: Colors.blue.shade800, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Structured Evaluation Survey (ISO/IEC 25010)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Slide 6 Instrument: Rate the application from 1 (Strongly Disagree) to 5 (Strongly Agree).',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                  const Divider(height: 18),
                  _buildLikertSlider(
                    '1. Functionality: Kit checklist, expiry tracking & emergency guides work accurately.',
                    _functionalityScore,
                    (v) => setState(() => _functionalityScore = v),
                  ),
                  _buildLikertSlider(
                    '2. Usability: Interface is clear, responsive, and easy to navigate.',
                    _usabilityScore,
                    (v) => setState(() => _usabilityScore = v),
                  ),
                  _buildLikertSlider(
                    '3. Offline Reliability: Essential data remains accessible with no internet.',
                    _offlineReliabilityScore,
                    (v) => setState(() => _offlineReliabilityScore = v),
                  ),
                  _buildLikertSlider(
                    '4. Effectiveness: Improves household disaster preparedness and readiness.',
                    _preparednessImpactScore,
                    (v) => setState(() => _preparednessImpactScore = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800),
                          icon: Icon(
                              _surveySubmitted ? Icons.check : Icons.save),
                          label: Text(_surveySubmitted
                              ? 'Evaluation Saved (Update)'
                              : 'Submit Evaluation'),
                          onPressed: _saveSurvey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Export'),
                        onPressed: () => _copyFullReport(kit),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLikertSlider(
      String label, int score, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$score / 5',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blue.shade900),
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
            activeColor: Colors.blue.shade800,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditFinding({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        height: 1.3),
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
