import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../utils/app_theme.dart';

class SelfAssessmentScreen extends StatelessWidget {
  const SelfAssessmentScreen({super.key});

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
                    Icon(Icons.assignment_turned_in, color: Colors.white, size: 24),
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
                  'Based on Philippine DRRM 72-Hour Survival Go-Bag standards. This instrument measures the completeness and readiness level of your household emergency kit.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.35),
                ),
                const SizedBox(height: 14),
                // Score Display
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkSlate),
          ),
          const SizedBox(height: 10),

          ...KitCategory.values.map((category) {
            final categoryItems = kit.allItems.where((item) => item.category == category).toList();
            if (categoryItems.isEmpty) return const SizedBox.shrink();

            final catPacked = categoryItems.where((item) => item.isPacked && !item.isExpired).length;
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$catPacked / ${categoryItems.length} (${(catProgress * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: catProgress >= 0.8 ? AppTheme.safeGreen : Colors.grey.shade700,
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
                            : (catProgress >= 0.4 ? AppTheme.warningAmber : AppTheme.accentAlert),
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
            'Quality & Usability Audit Findings',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkSlate),
          ),
          const SizedBox(height: 10),

          _buildAuditFinding(
            icon: expired == 0 ? Icons.check_circle : Icons.cancel,
            color: expired == 0 ? AppTheme.safeGreen : AppTheme.accentAlert,
            title: expired == 0 ? 'Zero Expired Supplies' : '$expired Expired Supplies Detected',
            subtitle: expired == 0
                ? 'All emergency medicines and food rations are within valid safety shelf-life.'
                : 'Replace expired medications and consumables immediately before disaster strikes.',
          ),
          _buildAuditFinding(
            icon: expiringSoon == 0 ? Icons.check_circle : Icons.warning_amber_rounded,
            color: expiringSoon == 0 ? AppTheme.safeGreen : AppTheme.warningAmber,
            title: expiringSoon == 0 ? 'No Immediate Expiring Items' : '$expiringSoon Items Expiring within 30 Days',
            subtitle: expiringSoon == 0
                ? 'No items require near-term replenishment.'
                : 'Plan grocery rotation for items approaching expiration dates.',
          ),
          _buildAuditFinding(
            icon: score >= 80 ? Icons.verified : Icons.info_outline,
            color: score >= 80 ? AppTheme.safeGreen : Colors.blue.shade700,
            title: score >= 80 ? '72-Hour Autonomous Kit Achieved' : 'Kit Incomplete',
            subtitle: score >= 80
                ? 'Household has sufficient supplies to survive independently for the first 3 days after a calamity.'
                : 'Prioritize water purification, first-aid, and lighting tools to reach target readiness.',
          ),

          const SizedBox(height: 20),

          // Capstone ISO 25010 Usability Survey Information Tile
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science, color: Colors.blue.shade800, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ISO/IEC 25010 Usability Evaluation',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'In accordance with Slide 6 of the EAC research proposal, this system records and benchmarks:\n'
                  '• Functional Suitability (Completeness tracking accuracy)\n'
                  '• Usability & Learnability (Ease of updating supplies)\n'
                  '• Reliability & Offline Fault Tolerance (Functions with zero data)',
                  style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.3),
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
