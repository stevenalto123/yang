import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../utils/app_theme.dart';
import '../utils/notification_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _permissionStatus = NotificationHelper.getPermissionStatus();

  Future<void> _triggerReplacementNotification(KitProvider kit) async {
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
              expired.isNotEmpty ? AppTheme.accentAlert : AppTheme.primaryCrimson,
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
    final expired = kit.expiredItems;
    final soon = kit.expiringSoonItems;
    final missing = kit.missingItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Replacement Alerts & Restock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy Restock Shopping List',
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: kit.generateRestockSummaryText()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Restock shopping list copied to clipboard!'),
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
                      const Icon(Icons.notifications_active,
                          color: AppTheme.primaryCrimson),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Replacement Reminder Settings',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _permissionStatus == 'granted'
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Push: ${_permissionStatus.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _permissionStatus == 'granted'
                                ? AppTheme.safeGreen
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Warn me when supplies will expire within:',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [7, 14, 30, 60].map((days) {
                      final selected = kit.expiryAlertDays == days;
                      return ChoiceChip(
                        label: Text('$days days'),
                        selected: selected,
                        selectedColor: AppTheme.primaryCrimson,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) => kit.setExpiryAlertDays(days),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notification_add, size: 18),
                      label: const Text('Send Replacement Alert Notification'),
                      onPressed: () => _triggerReplacementNotification(kit),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Urgent Expired Items
          _buildGroupHeader(
            'Expired Items — Replace Immediately (${expired.length})',
            AppTheme.accentAlert,
            Icons.error_outline,
          ),
          if (expired.isEmpty)
            _buildEmptyRow('No expired items found.')
          else
            ...expired.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  badgeText:
                      'Expired ${DateFormat('MMM dd, yyyy').format(item.expirationDate!)}',
                  accent: AppTheme.accentAlert,
                  actionLabel: 'Mark Replaced',
                  onAction: () => _showReplaceDateDialog(context, kit, item),
                )),

          const SizedBox(height: 14),

          // Expiring Soon Items
          _buildGroupHeader(
            'Expiring Within ${kit.expiryAlertDays} Days (${soon.length})',
            AppTheme.warningAmber,
            Icons.schedule,
          ),
          if (soon.isEmpty)
            _buildEmptyRow(
                'No items expiring within the next ${kit.expiryAlertDays} days.')
          else
            ...soon.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  badgeText: '${item.daysUntilExpiration} days remaining',
                  accent: AppTheme.warningAmber,
                  actionLabel: 'Update Expiry',
                  onAction: () => _showReplaceDateDialog(context, kit, item),
                )),

          const SizedBox(height: 14),

          // Missing / Low Stock Items
          _buildGroupHeader(
            'Missing or Incomplete Supplies (${missing.length})',
            Colors.blueGrey.shade700,
            Icons.inventory_2_outlined,
          ),
          if (missing.isEmpty)
            _buildEmptyRow('All emergency kit items are completely packed!')
          else
            ...missing.map((item) => _buildAlertItemCard(
                  context,
                  kit,
                  item,
                  badgeText:
                      'Have ${item.quantity} / ${item.targetQuantity} ${item.unit}',
                  accent: Colors.orange.shade800,
                  actionLabel: 'Mark Packed',
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
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildAlertItemCard(
    BuildContext context,
    KitProvider kit,
    KitItem item, {
    required String badgeText,
    required Color accent,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withAlpha(80)),
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
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badgeText,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: accent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle:
                    const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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
      BuildContext context, KitProvider kit, KitItem item) async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'Select New Expiration Date for Replaced Supply',
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
                '${item.name} marked replaced (Exp: ${DateFormat('MMM dd, yyyy').format(picked)})'),
          ),
        );
      }
    }
  }
}
