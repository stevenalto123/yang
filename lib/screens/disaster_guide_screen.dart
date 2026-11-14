import 'package:flutter/material.dart';
import '../models/disaster_protocol.dart';
import '../data/disaster_data.dart';
import '../utils/app_theme.dart';

class DisasterGuideScreen extends StatefulWidget {
  const DisasterGuideScreen({super.key});

  @override
  State<DisasterGuideScreen> createState() => _DisasterGuideScreenState();
}

class _DisasterGuideScreenState extends State<DisasterGuideScreen> {
  late final List<DisasterGuide> _guides;
  int _selectedGuideIndex = 0;

  @override
  void initState() {
    super.initState();
    _guides = getDefaultDisasterGuides();
  }

  @override
  Widget build(BuildContext context) {
    final activeGuide = _guides[_selectedGuideIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Preparedness Guides'),
      ),
      body: Column(
        children: [
          // Disaster Selector Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(_guides.length, (index) {
                  final guide = _guides[index];
                  final isSelected = index == _selectedGuideIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getDisasterIcon(guide.type),
                            size: 16,
                            color: isSelected ? Colors.white : AppTheme.primaryCrimson,
                          ),
                          const SizedBox(width: 6),
                          Text(guide.type.shortName),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryCrimson,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedGuideIndex = index);
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          const Divider(height: 1),

          // Disaster Details Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryCrimson,
                        AppTheme.primaryDark,
                      ],
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
                          Icon(
                            _getDisasterIcon(activeGuide.type),
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activeGuide.type.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        activeGuide.overview,
                        style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tips_and_updates, size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                activeGuide.type.quickTip,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // PHASE 1: BEFORE DISASTER
                _buildPhaseCard(
                  title: '1. BEFORE THE DISASTER (Paghandaan)',
                  subtitle: 'Mitigation, pre-planning, and kit preparation',
                  icon: Icons.shield_outlined,
                  color: Colors.blue.shade700,
                  steps: activeGuide.beforeSteps,
                ),
                const SizedBox(height: 14),

                // PHASE 2: DURING DISASTER
                _buildPhaseCard(
                  title: '2. DURING THE DISASTER (Aksyon)',
                  subtitle: 'Immediate safety protocols & survival reactions',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.accentAlert,
                  steps: activeGuide.duringSteps,
                ),
                const SizedBox(height: 14),

                // PHASE 3: AFTER DISASTER
                _buildPhaseCard(
                  title: '3. AFTER THE DISASTER (Tugon at Pagbangon)',
                  subtitle: 'Damage inspection, first-aid, and safe recovery',
                  icon: Icons.health_and_safety_outlined,
                  color: AppTheme.safeGreen,
                  steps: activeGuide.afterSteps,
                ),
                const SizedBox(height: 14),

                // ESSENTIAL SUPPLIES PACK LIST
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                  color: const Color(0xFFFFF8E1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.backpack_outlined, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Priority Supplies for ${activeGuide.type.shortName}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...activeGuide.essentialSupplies.map(
                          (supply) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Expanded(
                                  child: Text(
                                    supply,
                                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade900),
                                  ),
                                ),
                              ],
                            ),
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
        ],
      ),
    );
  }

  Widget _buildPhaseCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> steps,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(26),
                  radius: 16,
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            ...steps.asMap().entries.map((entry) {
              final stepNum = entry.key + 1;
              final stepText = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$stepNum',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stepText,
                        style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.darkSlate),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getDisasterIcon(DisasterType type) {
    switch (type) {
      case DisasterType.typhoon:
        return Icons.cyclone;
      case DisasterType.earthquake:
        return Icons.vibration;
      case DisasterType.flood:
        return Icons.tsunami;
      case DisasterType.fire:
        return Icons.local_fire_department;
      case DisasterType.volcanicEruption:
        return Icons.volcano;
    }
  }
}
