import 'package:flutter/material.dart';
import '../models/disaster_protocol.dart';
import '../data/disaster_data.dart';
import '../utils/app_theme.dart';

class DisasterGuideScreen extends StatefulWidget {
  final bool isEmbedded;

  const DisasterGuideScreen({super.key, this.isEmbedded = false});

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    final bodyContent = Column(
      children: [
        // Disaster Selector Tabs
        Container(
          color: isDark ? AppTheme.darkCard : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getDisasterIcon(guide.type),
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(guide.type.shortName),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryNavy,
                    labelStyle: TextStyle(
                      fontSize: 13.5,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // Header Banner (Calm Navy Brand — Danger Red reserved for actual warnings)
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
                              fontSize: 19,
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
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(64),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tips_and_updates,
                              size: 18, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeGuide.type.quickTip,
                              style: const TextStyle(
                                fontSize: 13.5,
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

              _buildPhaseCard(
                context,
                title: '1. BEFORE THE DISASTER (Paghandaan)',
                subtitle: 'Mitigation, pre-planning, and kit preparation',
                icon: Icons.shield_outlined,
                color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700,
                steps: activeGuide.beforeSteps,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 14),

              _buildPhaseCard(
                context,
                title: '2. DURING THE DISASTER (Aksyon)',
                subtitle: 'Immediate safety protocols & survival reactions',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.dangerRed,
                steps: activeGuide.duringSteps,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 14),

              _buildPhaseCard(
                context,
                title: '3. AFTER THE DISASTER (Tugon at Pagbangon)',
                subtitle: 'Damage inspection, first-aid, and safe recovery',
                icon: Icons.health_and_safety_outlined,
                color: isDark ? const Color(0xFF4ADE80) : AppTheme.safeGreen,
                steps: activeGuide.afterSteps,
                subTextColor: subTextColor,
              ),
              const SizedBox(height: 14),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? Colors.amber.shade700
                        : Colors.orange.shade300,
                  ),
                ),
                color: isDark
                    ? const Color(0xFF292112)
                    : const Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.backpack_outlined,
                            color: isDark
                                ? Colors.amberAccent
                                : Colors.orange.shade800,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Priority Supplies for ${activeGuide.type.shortName}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.amberAccent
                                    : Colors.orange.shade900,
                              ),
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
                              const Text('• ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Expanded(
                                child: Text(
                                  supply,
                                  style: const TextStyle(fontSize: 14),
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
            ],
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Preparedness Guides'),
      ),
      body: bodyContent,
    );
  }

  Widget _buildPhaseCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> steps,
    required Color subTextColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(30),
                  radius: 18,
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...steps.asMap().entries.map((entry) {
              final stepNum = entry.key + 1;
              final stepText = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$stepNum',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stepText,
                        style: const TextStyle(fontSize: 14, height: 1.4),
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
