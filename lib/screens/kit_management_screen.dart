import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/household_profile.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_strings.dart';
import '../utils/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'notifications_screen.dart';

class KitManagementScreen extends StatelessWidget {
  const KitManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = settings.isDarkMode;
    final isFil = settings.isFilipino;
    final s = AppStrings(isFil);

    final accentTone = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;
    final headingColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFil ? 'Checklist ng Go-Bag' : 'Go-Bag Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: isFil
                ? 'Kopyahin ang Listahan ng Bibilhin'
                : 'Copy Shopping / Missing List',
            onPressed: () => _showShoppingListSheet(context, kit, isDark, isFil),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: isFil
                ? 'I-customize para sa Pamilya'
                : 'Customize for My Family',
            onPressed: () =>
                _showSmartRecommenderDialog(context, kit, isDark, isFil),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: s.replacementAlerts,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: isFil ? 'I-reset sa Standard' : 'Reset Default List',
            onPressed: () => _showResetDialog(context, kit, isFil),
          ),
        ],
      ),
      body: Column(
        children: [
          // Clean Header: Progress, Family Customizer, Search & Filters
          Container(
            color: isDark ? AppTheme.darkCard : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: ResponsiveContainer(
              maxWidth: 960,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress summary + Family size pill
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFil
                                  ? '${kit.packedItemsCount} sa ${kit.totalItemsCount} handa (${kit.readinessPercentage.toStringAsFixed(0)}%)'
                                  : '${kit.packedItemsCount} of ${kit.totalItemsCount} packed (${kit.readinessPercentage.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: (kit.readinessPercentage / 100)
                                    .clamp(0.0, 1.0),
                                minHeight: 7,
                                backgroundColor: isDark
                                    ? AppTheme.darkElevated
                                    : AppTheme.lightBorder,
                                color: kit.readinessPercentage >= 85
                                    ? AppTheme.safeGreen
                                    : (kit.readinessPercentage >= 50
                                        ? AppTheme.warningAmber
                                        : AppTheme.dangerRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          foregroundColor: accentTone,
                          side: BorderSide(
                            color: accentTone.withAlpha(110),
                          ),
                        ),
                        icon: const Icon(Icons.groups_outlined, size: 18),
                        label: Text(
                          isFil
                              ? '${kit.householdProfile.totalPeople} tao'
                              : 'Family: ${kit.householdProfile.totalPeople}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _showSmartRecommenderDialog(
                          context,
                          kit,
                          isDark,
                          isFil,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Field
                  TextField(
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isFil
                          ? 'Maghanap ng gamit (tubig, gamot, flashlight)...'
                          : 'Search supplies (water, medicine, flashlight)...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: kit.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 19),
                              onPressed: () => kit.setSearchQuery(''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 14,
                      ),
                    ),
                    onChanged: (val) => kit.setSearchQuery(val),
                  ),
                  const SizedBox(height: 10),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilterChip(
                          isDark: isDark,
                          label:
                              '${isFil ? 'Lahat' : 'All'} (${kit.totalItemsCount})',
                          isSelected: kit.filterStatus == ItemFilterStatus.all,
                          onSelected: () =>
                              kit.setFilterStatus(ItemFilterStatus.all),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          isDark: isDark,
                          label:
                              '${isFil ? 'Kulang' : 'To Pack'} (${kit.missingItemsCount})',
                          isSelected:
                              kit.filterStatus == ItemFilterStatus.missing,
                          selectedColor: const Color(0xFFEA580C),
                          onSelected: () =>
                              kit.setFilterStatus(ItemFilterStatus.missing),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          isDark: isDark,
                          label:
                              '${isFil ? 'Malapit' : 'Expiring'} (${kit.expiringSoonItemsCount})',
                          isSelected:
                              kit.filterStatus == ItemFilterStatus.expiringSoon,
                          selectedColor: AppTheme.warningAmber,
                          onSelected: () => kit
                              .setFilterStatus(ItemFilterStatus.expiringSoon),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          isDark: isDark,
                          label:
                              '${isFil ? 'Paso Na' : 'Expired'} (${kit.expiredItemsCount})',
                          isSelected:
                              kit.filterStatus == ItemFilterStatus.expired,
                          selectedColor: AppTheme.dangerRed,
                          onSelected: () =>
                              kit.setFilterStatus(ItemFilterStatus.expired),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusFilterChip(
                          isDark: isDark,
                          label:
                              '${isFil ? 'Handa Na' : 'Packed'} (${kit.packedItemsCount})',
                          isSelected:
                              kit.filterStatus == ItemFilterStatus.packed,
                          selectedColor: AppTheme.safeGreen,
                          onSelected: () =>
                              kit.setFilterStatus(ItemFilterStatus.packed),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Dropdown + Add Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevated
                                : AppTheme.surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.lightBorder,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<KitCategory?>(
                              value: kit.selectedCategory,
                              isExpanded: true,
                              dropdownColor:
                                  isDark ? AppTheme.darkCard : Colors.white,
                              hint: Text(
                                isFil ? 'Lahat ng Kategorya' : 'All Categories',
                                style: const TextStyle(fontSize: 14),
                              ),
                              items: [
                                DropdownMenuItem<KitCategory?>(
                                  value: null,
                                  child: Text(
                                    isFil
                                        ? 'Lahat ng Kategorya'
                                        : 'All Categories',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                ...KitCategory.values.map(
                                  (cat) => DropdownMenuItem<KitCategory?>(
                                    value: cat,
                                    child: Text(
                                      s.categoryName(cat),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (cat) => kit.setSelectedCategory(cat),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(isFil ? 'Dagdag' : 'Add'),
                        onPressed: () =>
                            _showAddEditItemDialog(context, kit, isDark, isFil),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Items List
          Expanded(
            child: kit.filteredItems.isEmpty
                ? _buildEmptyState(kit, subtleText, isFil)
                : ResponsiveContainer(
                    maxWidth: 960,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: kit.filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = kit.filteredItems[index];
                        return _buildItemCard(
                          context,
                          item,
                          kit,
                          s,
                          isDark,
                          isFil,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip({
    required bool isDark,
    required String label,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onSelected,
  }) {
    final activeColor = selectedColor ?? AppTheme.primaryNavy;
    return ChoiceChip(
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelStyle: TextStyle(
        fontSize: 13.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white : AppTheme.darkSlate),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
      side: BorderSide(
        color: isSelected
            ? activeColor
            : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildEmptyState(KitProvider kit, Color subtleText, bool isFil) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backpack_outlined, size: 56, color: subtleText),
            const SizedBox(height: 12),
            Text(
              isFil ? 'Walang Nahanap na Gamit' : 'No Supplies Found',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              kit.searchQuery.isNotEmpty ||
                      kit.selectedCategory != null ||
                      kit.filterStatus != ItemFilterStatus.all
                  ? (isFil
                      ? 'Walang tumugma sa iyong filter.'
                      : 'No items match your current filter.')
                  : (isFil
                      ? 'Magdagdag ng mahahalagang gamit sa iyong Go-Bag.'
                      : 'Start by adding essential items to your Go-Bag.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subtleText),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                kit.setSearchQuery('');
                kit.setSelectedCategory(null);
                kit.setFilterStatus(ItemFilterStatus.all);
              },
              child: Text(isFil ? 'Ipakita Lahat' : 'Show All Items'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    KitItem item,
    KitProvider kit,
    AppStrings s,
    bool isDark,
    bool isFil,
  ) {
    final isExpiring = item.isExpiringWithin(kit.expiryAlertDays);
    Color cardBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    if (item.isExpired) {
      cardBorder = AppTheme.dangerRed.withAlpha(170);
    } else if (isExpiring) {
      cardBorder = AppTheme.warningAmber.withAlpha(170);
    }

    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : AppTheme.mutedSlate;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cardBorder,
          width: item.isExpired || isExpiring ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isComplete,
                  activeColor: AppTheme.safeGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (_) => kit.togglePacked(item.id),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            decoration: item.isComplete
                                ? TextDecoration.none
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${s.categoryName(item.category)} • ${isFil ? 'Kailangan' : 'Goal'}: ${item.targetQuantity} ${item.unit}',
                              style: TextStyle(
                                fontSize: 13,
                                color: subtleText,
                              ),
                            ),
                            if (item.isPartial)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningAmber
                                      .withAlpha(isDark ? 45 : 22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isFil ? 'Kulang Pa' : 'Low',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.amber.shade200
                                        : AppTheme.warningAmber,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: subtleText),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditItemDialog(
                        context,
                        kit,
                        isDark,
                        isFil,
                        existingItem: item,
                      );
                    } else if (val == 'replace') {
                      _quickReplaceItem(context, kit, item, isFil);
                    } else if (val == 'delete') {
                      kit.deleteItem(item.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(isFil ? 'I-edit' : 'Edit Item'),
                        ],
                      ),
                    ),
                    if (item.expirationDate != null)
                      PopupMenuItem(
                        value: 'replace',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.autorenew_rounded,
                              size: 18,
                              color: AppTheme.safeGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isFil
                                  ? 'Markahang Pinalitan'
                                  : 'Mark as Replaced',
                            ),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppTheme.dangerRed,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFil ? 'Burahin' : 'Delete',
                            style: const TextStyle(color: AppTheme.dangerRed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 50, right: 8),
                child: Text(
                  item.notes,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subtleText,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 50, right: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildExpiryBadge(
                          item,
                          kit.expiryAlertDays,
                          isDark,
                          isFil,
                        ),
                        if (item.isExpired || isExpiring) ...[
                          InkWell(
                            onTap: () {
                              final nextYear = DateTime.now()
                                  .add(const Duration(days: 365));
                              kit.markItemReplaced(item.id, nextYear);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.safeGreen,
                                  content: Text(
                                    isFil
                                        ? 'Napalitan ang ${item.name} (+1 taon)!'
                                        : '${item.name} marked restocked (+1 yr)!',
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.safeGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFil ? 'Napalitan (+1 yr)' : 'Restocked (+1 yr)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () =>
                                _quickReplaceItem(context, kit, item, isFil),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: (item.isExpired
                                        ? AppTheme.dangerRed
                                        : AppTheme.warningAmber)
                                    .withAlpha(isDark ? 65 : 28),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isFil ? 'Petsa' : 'Pick Date',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: item.isExpired
                                      ? AppTheme.dangerRed
                                      : AppTheme.warningAmber,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Compact inline stepper
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove_rounded, size: 18),
                          color: subtleText,
                          onPressed: item.quantity > 0
                              ? () =>
                                  kit.updateQuantity(item.id, item.quantity - 1)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${item.quantity}/${item.targetQuantity}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          color: isDark
                              ? Colors.lightBlue.shade200
                              : AppTheme.primaryNavy,
                          onPressed: () =>
                              kit.updateQuantity(item.id, item.quantity + 1),
                        ),
                      ],
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

  Widget _buildExpiryBadge(
    KitItem item,
    int thresholdDays,
    bool isDark,
    bool isFil,
  ) {
    if (item.expirationDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFil ? 'Hindi napapanis' : 'No expiry',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : AppTheme.mutedSlate,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final formattedDate = DateFormat('MMM d, yyyy').format(item.expirationDate!);
    final days = item.daysUntilExpiration ?? 0;

    if (item.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withAlpha(isDark ? 45 : 20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFil ? 'Paso na ($formattedDate)' : 'Expired ($formattedDate)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.red.shade200 : AppTheme.dangerRed,
          ),
        ),
      );
    } else if (item.isExpiringWithin(thresholdDays)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.warningAmber.withAlpha(isDark ? 45 : 20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isFil ? 'Mapapaso sa $days araw' : 'Expires in $days days',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.amber.shade200 : AppTheme.warningAmber,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.safeGreen.withAlpha(isDark ? 40 : 18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Exp: $formattedDate',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.green.shade200 : AppTheme.safeGreen,
          ),
        ),
      );
    }
  }

  Future<void> _showShoppingListSheet(
    BuildContext context,
    KitProvider kit,
    bool isDark,
    bool isFil,
  ) async {
    final missing = kit.missingItems;
    final expired = kit.expiredItems;
    final expiring = kit.expiringSoonItems;

    final buf = StringBuffer();
    buf.writeln(
      'LifeCheckpoint Go-Bag Shopping List (Family of ${kit.householdProfile.totalPeople})',
    );
    if (missing.isNotEmpty) {
      buf.writeln('\nMISSING / LOW SUPPLIES (${missing.length}):');
      for (final item in missing) {
        final need = (item.targetQuantity - item.quantity).clamp(1, 999);
        buf.writeln('[ ] ${item.name} — need $need ${item.unit}');
      }
    }
    if (expired.isNotEmpty) {
      buf.writeln('\nEXPIRED — REPLACE NOW (${expired.length}):');
      for (final item in expired) {
        buf.writeln('[ ] ${item.name} (${item.targetQuantity} ${item.unit})');
      }
    }
    if (expiring.isNotEmpty) {
      buf.writeln('\nEXPIRING SOON (${expiring.length}):');
      for (final item in expiring) {
        buf.writeln('[ ] ${item.name} (${item.targetQuantity} ${item.unit})');
      }
    }
    if (missing.isEmpty && expired.isEmpty && expiring.isEmpty) {
      buf.writeln('\nAll Go-Bag essentials are packed and fresh!');
    }

    final text = buf.toString().trim();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        color: AppTheme.safeGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isFil
                              ? 'Listahan ng Bibilhin (Nakopya Na!)'
                              : 'Go-Bag Shopping List (Copied!)',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isFil
                        ? 'I-paste ito sa Notes, Messenger, o Viber kapag mamimili sa grocery o botika.'
                        : 'Paste into Notes, Messenger, or Viber when restocking at the grocery or pharmacy.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppTheme.darkElevated : AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        text,
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 17),
                          label: Text(isFil ? 'Kopyahin Ulit' : 'Copy Again'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Shopping list copied!'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(isFil ? 'Tapos' : 'Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _quickReplaceItem(
    BuildContext context,
    KitProvider kit,
    KitItem item,
    bool isFil,
  ) async {
    final picked = await showDatePicker(
      context: context,
      helpText: isFil
          ? 'Bagong Expiration Date'
          : 'New Expiration Date for Replaced Supply',
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
              '${item.name} updated! New expiry: ${DateFormat('MMM d, yyyy').format(picked)}',
            ),
          ),
        );
      }
    }
  }

  void _showAddEditItemDialog(
    BuildContext context,
    KitProvider kit,
    bool isDark,
    bool isFil, {
    KitItem? existingItem,
  }) {
    showDialog(
      context: context,
      builder: (_) => _AddEditItemDialog(
        kit: kit,
        existingItem: existingItem,
        isDark: isDark,
        isFil: isFil,
      ),
    );
  }

  void _showSmartRecommenderDialog(
    BuildContext context,
    KitProvider kit,
    bool isDark,
    bool isFil,
  ) {
    final p = kit.householdProfile;
    int adults = p.adults;
    int children = p.children;
    int infants = p.infants;
    int seniors = p.seniors;
    int pets = p.pets;
    bool isFloodProne = p.isFloodProne;
    bool isEarthquakeZone = p.isEarthquakeZone;
    bool hasChronicMeds = p.hasChronicMedicalNeeds;

    final accentColor =
        isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.groups_rounded, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFil
                      ? 'I-customize para sa Pamilya'
                      : 'Customize for My Family',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFil
                      ? 'Ilagay ang bilang ng miyembro ng pamilya para awtomatikong ma-adjust ang 72-oras na tubig, pagkain, at gamot.'
                      : 'Set your household size to automatically calculate 72-hour water, food, and special supplies.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : AppTheme.mutedSlate,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStepperRow(
                  isFil ? 'Matanda (18–59)' : 'Adults (18–59)',
                  adults,
                  (v) => setState(() => adults = v),
                  min: 1,
                ),
                _buildStepperRow(
                  isFil ? 'Bata (3–17)' : 'Children (3–17)',
                  children,
                  (v) => setState(() => children = v),
                ),
                _buildStepperRow(
                  isFil ? 'Sanggol' : 'Infants / Toddlers',
                  infants,
                  (v) => setState(() => infants = v),
                ),
                _buildStepperRow(
                  isFil ? 'Senior Citizen (60+)' : 'Senior Citizens (60+)',
                  seniors,
                  (v) => setState(() => seniors = v),
                ),
                _buildStepperRow(
                  isFil ? 'Alagang Hayop' : 'Pets',
                  pets,
                  (v) => setState(() => pets = v),
                ),
                const Divider(),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isFil ? 'Binabaha ang lugar namin' : 'Flood-Prone Area',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: isFloodProne,
                  onChanged: (v) => setState(() => isFloodProne = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isFil
                        ? 'Malapit sa Fault / High-Rise'
                        : 'Earthquake / High-Rise Area',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: isEarthquakeZone,
                  onChanged: (v) =>
                      setState(() => isEarthquakeZone = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isFil
                        ? 'May Maintenance na Gamot'
                        : 'Daily Maintenance Medicine',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: hasChronicMeds,
                  onChanged: (v) =>
                      setState(() => hasChronicMeds = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isFil ? 'Kanselahin' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final profile = HouseholdProfile(
                  adults: adults,
                  children: children,
                  infants: infants,
                  seniors: seniors,
                  pets: pets,
                  isFloodProne: isFloodProne,
                  isEarthquakeZone: isEarthquakeZone,
                  hasChronicMedicalNeeds: hasChronicMeds,
                );
                final res = await kit.applySmartRecommendations(profile);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.safeGreen,
                      content: Text(
                        'Go-Bag adjusted for ${profile.totalPeople} people (${res.updatedCount} updated, ${res.addedCount} added).',
                      ),
                    ),
                  );
                }
              },
              child: Text(isFil ? 'I-apply' : 'Update Checklist'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow(String label, int val, Function(int) onChanged,
      {int min = 0}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Row(
          children: [
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              onPressed: val > min ? () => onChanged(val - 1) : null,
            ),
            Text(
              '$val',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              onPressed: () => onChanged(val + 1),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, KitProvider kit, bool isFil) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isFil
              ? 'I-reset sa Standard 72-Hour Kit?'
              : 'Reset to Standard 72-Hour Kit?',
        ),
        content: Text(
          isFil
              ? 'Ibabalik nito ang standard na Philippine NDRRMC / Red Cross Go-Bag checklist.'
              : 'This will restore the standard Philippine NDRRMC / Red Cross emergency Go-Bag checklist.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              kit.resetToDefault();
              Navigator.pop(ctx);
            },
            child: Text(isFil ? 'I-reset' : 'Reset List'),
          ),
        ],
      ),
    );
  }
}

class _AddEditItemDialog extends StatefulWidget {
  final KitProvider kit;
  final KitItem? existingItem;
  final bool isDark;
  final bool isFil;

  const _AddEditItemDialog({
    required this.kit,
    this.existingItem,
    required this.isDark,
    required this.isFil,
  });

  @override
  State<_AddEditItemDialog> createState() => _AddEditItemDialogState();
}

class _AddEditItemDialogState extends State<_AddEditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetQtyCtrl;
  late final TextEditingController _currentQtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _notesCtrl;
  late KitCategory _selectedCat;
  DateTime? _selectedExpDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetQtyCtrl =
        TextEditingController(text: (e?.targetQuantity ?? 1).toString());
    _currentQtyCtrl =
        TextEditingController(text: (e?.quantity ?? 0).toString());
    _unitCtrl = TextEditingController(text: e?.unit ?? 'pcs');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _selectedCat = e?.category ?? KitCategory.waterAndFood;
    _selectedExpDate = e?.expirationDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetQtyCtrl.dispose();
    _currentQtyCtrl.dispose();
    _unitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    final s = AppStrings(widget.isFil);

    return AlertDialog(
      title: Text(
        isEditing
            ? (widget.isFil ? 'I-edit ang Gamit' : 'Edit Supply Item')
            : (widget.isFil ? 'Magdagdag ng Gamit' : 'Add New Supply Item'),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText:
                      widget.isFil ? 'Pangalan ng Gamit *' : 'Item Name *',
                  hintText: 'e.g. Bottled Water, Paracetamol',
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter an item name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<KitCategory>(
                initialValue: _selectedCat,
                decoration: InputDecoration(
                  labelText: widget.isFil ? 'Kategorya' : 'Category',
                ),
                items: KitCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(s.categoryName(c)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCat = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _currentQtyCtrl,
                      decoration: InputDecoration(
                        labelText:
                            widget.isFil ? 'Meron Ngayon' : 'Current Qty',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final parsed = int.tryParse(val ?? '');
                        if (parsed == null || parsed < 0) return 'Min 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _targetQtyCtrl,
                      decoration: InputDecoration(
                        labelText: widget.isFil ? 'Kailangan *' : 'Goal Qty *',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final parsed = int.tryParse(val ?? '');
                        if (parsed == null || parsed < 1) return 'Min 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit (pcs, cans, liters, etc.)',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedExpDate == null
                      ? (widget.isFil
                          ? 'Walang Expiration Date'
                          : 'No Expiration Date')
                      : 'Expires: ${DateFormat('MMM d, yyyy').format(_selectedExpDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedExpDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        tooltip: 'Clear Expiration Date',
                        onPressed: () =>
                            setState(() => _selectedExpDate = null),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.calendar_today_rounded,
                        color: widget.isDark
                            ? Colors.lightBlue.shade200
                            : AppTheme.primaryNavy,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedExpDate ??
                              DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _selectedExpDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Storage Notes (Optional)',
                  hintText: 'e.g. Keep dry in waterproof bag',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isFil ? 'Kanselahin' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final name = _nameCtrl.text.trim();
            final target = int.tryParse(_targetQtyCtrl.text.trim()) ?? 1;
            final current = int.tryParse(_currentQtyCtrl.text.trim()) ?? 0;
            final unit =
                _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim();
            final notes = _notesCtrl.text.trim();

            if (isEditing) {
              widget.kit.editItem(
                widget.existingItem!.copyWith(
                  name: name,
                  category: _selectedCat,
                  quantity: current,
                  targetQuantity: target,
                  unit: unit,
                  expirationDate: _selectedExpDate,
                  clearExpirationDate: _selectedExpDate == null,
                  isPacked: current >= target,
                  notes: notes,
                ),
              );
            } else {
              widget.kit.addItem(
                KitItem(
                  id: const Uuid().v4(),
                  name: name,
                  category: _selectedCat,
                  quantity: current,
                  targetQuantity: target,
                  unit: unit,
                  expirationDate: _selectedExpDate,
                  notes: notes,
                  isPacked: current >= target,
                ),
              );
            }
            Navigator.pop(context);
          },
          child: Text(
            isEditing
                ? (widget.isFil ? 'I-save' : 'Save')
                : (widget.isFil ? 'Idagdag' : 'Add Item'),
          ),
        ),
      ],
    );
  }
}
