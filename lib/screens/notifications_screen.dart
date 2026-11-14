import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../utils/notification_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _permissionStatus = NotificationHelper.getPermissionStatus();

  Future<void> _triggerReplacementNotification(
    KitProvider kit,
    bool isFil,
  ) async {
    final expired = kit.expiredItems;
    final soon = kit.expiringSoonItems;
    final missing = kit.missingItems;

    final title = expired.isNotEmpty
        ? 'LifeCheckpoint URGENT: ${expired.length} Expired Supply Item(s)'
        : soon.isNotEmpty
            ? 'LifeCheckpoint Alert: ${soon.length} Item(s) Expiring Soon'
            : 'LifeCheckpoint Kit Status: ${missing.length} Missing Item(s)';

    final body = expired.isNotEmpty
        ? 'Replace immediately: ${expired.map((e) => e.name).take(2).join(', ')}'
        : soon.isNotEmpty
            ? 'Expiring within ${kit.expiryAlertDays} days: ${soon.map((e) => e.name).take(2).join(', ')}'
            : 'Your kit readiness is ${kit.readinessPercentage.toStringAsFixed(0)}%.';

    final granted = await NotificationHelper.requestPermission();
    setState(() {
      _permissionStatus = NotificationHelper.getPermissionStatus();
    });

    final sent = await NotificationHelper.showAlert(title: title, body: body);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              expired.isNotEmpty ? AppTheme.dangerRed : AppTheme.primaryNavy,
          content: Text(
            sent
                ? 'PWA Notification sent: $title'
                : 'In-App Alert: $title — $body${!granted ? ' (Browser notifications blocked/unsupported)' : ''}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;

    final expired = kit.expiredItems;
    final soon = kit.expiringSoonItems;
    final missing = kit.missingItems;

    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;
    final accentTone = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFil
              ? 'Mga Alerto sa Pagpapalit'
              : 'Replacement Alerts & Restock',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: isFil
                ? 'Kopyahin ang Listahan ng Bibilhin'
                : 'Copy Restock Shopping List',
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: kit.generateRestockSummaryText()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFil
                        ? 'Nakopya na ang restock shopping list!'
                        : 'Restock shopping list copied to clipboard!',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification Control Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active, color: accentTone),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFil
                              ? 'Setting ng Paalala sa Expiration'
                              : 'Replacement Reminder Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: headingColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _permissionStatus == 'granted'
                              ? (isDark
                                  ? AppTheme.safeGreen.withAlpha(45)
                                  : Colors.green.shade50)
                              : (isDark
                                  ? AppTheme.darkBg
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Push: ${_permissionStatus.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _permissionStatus == 'granted'
                                ? (isDark
                                    ? Colors.green.shade200
                                    : AppTheme.safeGreen)
                                : subtleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isFil
                        ? 'Balaan ako kapag mapapaso ang gamit sa loob ng:'
                        : 'Warn me when supplies will expire within:',
                    style: TextStyle(fontSize: 14, color: subtleText),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [7, 14, 30, 60].map((days) {
                      final selected = kit.expiryAlertDays == days;
                      return ChoiceChip(
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        label: Text('$days ${isFil ? 'araw' : 'days'}'),
                        selected: selected,
                        selectedColor: AppTheme.primaryNavy,
                        backgroundColor:
                            isDark ? AppTheme.darkBg : Colors.grey.shade100,
                        side: BorderSide(
                          color: selected
                              ? AppTheme.primaryNavy
                              : (isDark
                                  ? AppTheme.darkBorder
                                  : Colors.grey.shade300),
                        ),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : headingColor,
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => kit.setExpiryAlertDays(days),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.notification_add, size: 20),
                      label: Text(
                        isFil
                            ? 'Magpadala ng Paalala Ngayon'
                            : 'Send Replacement Alert Notification',
                      ),
                      onPressed: () =>
                          _triggerReplacementNotification(kit, isFil),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Urgent Expired Items
          _buildGroupHeader(
            isFil
                ? 'Paso Na — Palitan Agad (${expired.length})'
                : 'Expired Items — Replace Immediately (${expired.length})',
            isDark ? Colors.red.shade300 : AppTheme.dangerRed,
            Icons.error_outline,
          ),
          if (expired.isEmpty)
            _buildEmptyRow(
              isFil ? 'Walang pasong gamit.' : 'No expired items found.',
              subtleText,
            )
          else
            ...expired.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  isDark: isDark,
                  badgeText:
                      'Expired ${DateFormat('MMM dd, yyyy').format(item.expirationDate!)}',
                  accent: AppTheme.dangerRed,
                  textAccent: isDark ? Colors.red.shade200 : AppTheme.dangerRed,
                  actionLabel: isFil ? 'Pinalitan' : 'Mark Replaced',
                  onAction: () =>
                      _showReplaceDateDialog(context, kit, item, isFil),
                )),

          const SizedBox(height: 16),

          // Expiring Soon Items
          _buildGroupHeader(
            isFil
                ? 'Malapit Ma-expire sa ${kit.expiryAlertDays} Araw (${soon.length})'
                : 'Expiring Within ${kit.expiryAlertDays} Days (${soon.length})',
            isDark ? Colors.amber.shade300 : AppTheme.warningAmber,
            Icons.schedule,
          ),
          if (soon.isEmpty)
            _buildEmptyRow(
              isFil
                  ? 'Walang malapit ma-expire sa loob ng ${kit.expiryAlertDays} araw.'
                  : 'No items expiring within the next ${kit.expiryAlertDays} days.',
              subtleText,
            )
          else
            ...soon.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  isDark: isDark,
                  badgeText: '${item.daysUntilExpiration} days remaining',
                  accent: AppTheme.warningAmber,
                  textAccent:
                      isDark ? Colors.amber.shade200 : AppTheme.warningAmber,
                  actionLabel: isFil ? 'I-update' : 'Update Expiry',
                  onAction: () =>
                      _showReplaceDateDialog(context, kit, item, isFil),
                )),

          const SizedBox(height: 16),

          // Missing / Low Stock Items
          _buildGroupHeader(
            isFil
                ? 'Kulang o Hindi Kumpleto (${missing.length})'
                : 'Missing or Incomplete Supplies (${missing.length})',
            isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700,
            Icons.inventory_2_outlined,
          ),
          if (missing.isEmpty)
            _buildEmptyRow(
              isFil
                  ? 'Kumpleto na ang lahat ng emergency kit items!'
                  : 'All emergency kit items are completely packed!',
              subtleText,
            )
          else
            ...missing.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  isDark: isDark,
                  badgeText:
                      'Have ${item.quantity} / ${item.targetQuantity} ${item.unit}',
                  accent: Colors.orange.shade800,
                  textAccent:
                      isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                  actionLabel: isFil ? 'Kumpleto' : 'Mark Packed',
                  onAction: () => kit.togglePacked(item.id),
                )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(String text, Color subtleText) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: TextStyle(fontSize: 14, color: subtleText)),
      ),
    );
  }

  Widget _buildAlertItemCard(
    BuildContext context,
    KitProvider kit,
    KitItem item, {
    required bool isDark,
    required String badgeText,
    required Color accent,
    required Color textAccent,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withAlpha(110)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.darkSlate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 14,
                      color: textAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReplaceDateDialog(
    BuildContext context,
    KitProvider kit,
    KitItem item,
    bool isFil,
  ) async {
    final picked = await showDatePicker(
      context: context,
      helpText: isFil
          ? 'Piliin ang Bagong Expiration Date'
          : 'Select New Expiration Date for Replaced Supply',
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      kit.markItemReplaced(item.id, picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.safeGreen,
            content: Text(
              '${item.name} marked replaced (Exp: ${DateFormat('MMM dd, yyyy').format(picked)})',
            ),
          ),
        );
      }
    }
  }
}
