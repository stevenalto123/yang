import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/disaster_data.dart';
import '../models/disaster_protocol.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';

class DisasterGuideScreen extends StatefulWidget {
  final bool isEmbedded;

  const DisasterGuideScreen({super.key, this.isEmbedded = false});

  @override
  State<DisasterGuideScreen> createState() => _DisasterGuideScreenState();
}

class _DisasterGuideScreenState extends State<DisasterGuideScreen> {
  static const String _checksStorageKey = 'lifecheckpoint_guide_checks_v1';

  late final List<DisasterGuide> _guides;
  int _selectedGuideIndex = 0;
  Set<String> _checkedKeys = {};

  @override
  void initState() {
    super.initState();
    _guides = getDefaultDisasterGuides();
    _loadCheckedSteps();
  }

  Future<void> _loadCheckedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_checksStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List<dynamic>;
        if (mounted) {
          setState(() {
            _checkedKeys = decoded.map((e) => e.toString()).toSet();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCheckedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_checksStorageKey, json.encode(_checkedKeys.toList()));
    } catch (_) {}
  }

  String _stepKey(DisasterType type, String phase, int index) =>
      '${type.name}_${phase}_$index';

  void _toggleStep(String key) {
    setState(() {
      if (_checkedKeys.contains(key)) {
        _checkedKeys.remove(key);
      } else {
        _checkedKeys.add(key);
      }
    });
    _persistCheckedSteps();
  }

  int _countCheckedForGuide(DisasterGuide guide) {
    int count = 0;
    for (int i = 0; i < guide.beforeSteps.length; i++) {
      if (_checkedKeys.contains(_stepKey(guide.type, 'before', i))) count++;
    }
    for (int i = 0; i < guide.duringSteps.length; i++) {
      if (_checkedKeys.contains(_stepKey(guide.type, 'during', i))) count++;
    }
    for (int i = 0; i < guide.afterSteps.length; i++) {
      if (_checkedKeys.contains(_stepKey(guide.type, 'after', i))) count++;
    }
    return count;
  }

  void _resetCurrentGuideChecks(DisasterGuide guide) {
    final prefix = '${guide.type.name}_';
    setState(() {
      _checkedKeys.removeWhere((k) => k.startsWith(prefix));
    });
    _persistCheckedSteps();
  }

  @override
  Widget build(BuildContext context) {
    final activeGuide = _guides[_selectedGuideIndex];
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final s = AppStrings(isFil);

    final subTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final totalSteps = activeGuide.beforeSteps.length +
        activeGuide.duringSteps.length +
        activeGuide.afterSteps.length;
    final checkedCount = _countCheckedForGuide(activeGuide);

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
                    showCheckmark: false,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          child: ResponsiveContainer(
            maxWidth: 920,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // Header Banner with interactive checklist progress & Reset
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
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(64),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.tips_and_updates,
                              size: 18,
                              color: Colors.amberAccent,
                            ),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.checklist_rounded,
                            color: Color(0xFF4ADE80),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isFil
                                  ? 'I-tap ang bawat hakbang para i-check ($checkedCount/$totalSteps tapos)'
                                  : 'Tap any step below to check off ($checkedCount/$totalSteps completed)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          if (checkedCount > 0)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: Text(
                                isFil ? 'I-reset' : 'Reset',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                              onPressed: () =>
                                  _resetCurrentGuideChecks(activeGuide),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildPhaseCard(
                  context,
                  guideType: activeGuide.type,
                  phaseKey: 'before',
                  title: isFil
                      ? '1. BAGO ANG SAKUNA (Paghandaan)'
                      : '1. BEFORE THE DISASTER (Paghandaan)',
                  subtitle: isFil
                      ? 'Paghahanda at pag-iimpake ng emergency kit'
                      : 'Mitigation, pre-planning, and kit preparation',
                  icon: Icons.shield_outlined,
                  color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700,
                  steps: activeGuide.beforeSteps,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                _buildPhaseCard(
                  context,
                  guideType: activeGuide.type,
                  phaseKey: 'during',
                  title: isFil
                      ? '2. HABANG MAY SAKUNA (Aksyon)'
                      : '2. DURING THE DISASTER (Aksyon)',
                  subtitle: isFil
                      ? 'Mabilisang aksyon at ligtas na pagkilos'
                      : 'Immediate safety protocols & survival reactions',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.dangerRed,
                  steps: activeGuide.duringSteps,
                  subTextColor: subTextColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 14),

                _buildPhaseCard(
                  context,
                  guideType: activeGuide.type,
                  phaseKey: 'after',
                  title: isFil
                      ? '3. PAGKATAPOS NG SAKUNA (Tugon at Pagbangon)'
                      : '3. AFTER THE DISASTER (Tugon at Pagbangon)',
                  subtitle: isFil
                      ? 'Pagsusuri sa pinsala at ligtas na pagbawi'
                      : 'Damage inspection, first-aid, and safe recovery',
                  icon: Icons.health_and_safety_outlined,
                  color: isDark ? const Color(0xFF4ADE80) : AppTheme.safeGreen,
                  steps: activeGuide.afterSteps,
                  subTextColor: subTextColor,
                  isDark: isDark,
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
                                isFil
                                    ? 'Mga Kailangang Gamit para sa ${activeGuide.type.shortName}'
                                    : 'Priority Supplies for ${activeGuide.type.shortName}',
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
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
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
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.disasterGuides),
      ),
      body: bodyContent,
    );
  }

  Widget _buildPhaseCard(
    BuildContext context, {
    required DisasterType guideType,
    required String phaseKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<String> steps,
    required Color subTextColor,
    required bool isDark,
  }) {
    int phaseDone = 0;
    for (int i = 0; i < steps.length; i++) {
      if (_checkedKeys.contains(_stepKey(guideType, phaseKey, i))) {
        phaseDone++;
      }
    }

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
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (phaseDone == steps.length
                            ? AppTheme.safeGreen
                            : color)
                        .withAlpha(isDark ? 45 : 22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$phaseDone/${steps.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: phaseDone == steps.length
                          ? AppTheme.safeGreen
                          : color,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...steps.asMap().entries.map((entry) {
              final idx = entry.key;
              final stepText = entry.value;
              final key = _stepKey(guideType, phaseKey, idx);
              final isChecked = _checkedKeys.contains(key);

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _toggleStep(key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppTheme.safeGreen
                              : color.withAlpha(24),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isChecked
                                ? AppTheme.safeGreen
                                : color.withAlpha(110),
                          ),
                        ),
                        child: isChecked
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stepText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            decoration: isChecked
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: isChecked ? subTextColor : null,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      case DisasterType.landslide:
        return Icons.terrain;
      case DisasterType.volcanicEruption:
        return Icons.volcano;
    }
  }
}
