import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/monitoring_provider.dart';
import '../utils/app_theme.dart';

class DrrmAdvisoryBannerList extends StatelessWidget {
  final List<DrrmAdvisory> advisories;
  final bool isDark;
  final bool isFil;
  final int maxItems;

  const DrrmAdvisoryBannerList({
    super.key,
    required this.advisories,
    required this.isDark,
    required this.isFil,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (advisories.isEmpty) return const SizedBox.shrink();

    final visible = advisories.take(maxItems).toList();
    return Column(
      children: visible.map((adv) {
        final isCritical = adv.severity == 'critical';
        final isInfo = adv.severity == 'info';
        final accent = isCritical
            ? (isDark ? Colors.red.shade300 : AppTheme.dangerRed)
            : (isInfo
                ? (isDark ? Colors.lightBlue.shade200 : AppTheme.primaryAccent)
                : (isDark ? Colors.amber.shade300 : AppTheme.warningAmber));
        final bg = isCritical
            ? (isDark ? AppTheme.dangerRed.withAlpha(42) : const Color(0xFFFEF2F2))
            : (isInfo
                ? (isDark
                    ? AppTheme.primaryAccent.withAlpha(36)
                    : const Color(0xFFEFF6FF))
                : (isDark
                    ? AppTheme.warningAmber.withAlpha(38)
                    : const Color(0xFFFFFBEB)));
        final badgeText = isCritical
            ? (isFil ? 'KRITIKAL' : 'CRITICAL')
            : (isInfo ? 'INFO' : (isFil ? 'BABALA' : 'WARNING'));

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withAlpha(150), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withAlpha(isDark ? 45 : 26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCritical
                      ? Icons.campaign_rounded
                      : (isInfo
                          ? Icons.info_outline_rounded
                          : Icons.warning_amber_rounded),
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(isDark ? 55 : 28),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DRRM $badgeText',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          '${adv.area} • ${DateFormat('MMM d, h:mm a').format(adv.createdAt.toLocal())}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : AppTheme.mutedSlate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      adv.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adv.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: isDark ? Colors.white70 : AppTheme.darkSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
