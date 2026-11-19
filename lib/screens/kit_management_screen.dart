import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/kit_item.dart';
import '../models/household_profile.dart';
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
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFil ? 'Checklist ng Emergency Kit' : 'Emergency Kit Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: isFil ? 'Smart Recommender' : 'Smart Kit Recommender',
            onPressed: () => _showSmartRecommenderDialog(context, kit, isDark, isFil),
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
            icon: const Icon(Icons.refresh),
            tooltip: isFil ? 'I-reset ang Checklist' : 'Reset Default Checklist',
            onPressed: () => _showResetDialog(context, kit, isFil),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search, Readiness Progress, Recommender & Filter Header
          Container(
            color: isDark ? AppTheme.darkCard : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: ResponsiveContainer(
              maxWidth: 960,
              child: Column(
                children: [
                  // Compact Live Readiness Progress Bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (kit.readinessPercentage / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor:
                                isDark ? AppTheme.darkBg : Colors.grey.shade200,
                            color: kit.readinessPercentage >= 85
                                ? AppTheme.safeGreen
                                : (kit.readinessPercentage >= 50
                                    ? AppTheme.warningAmber
                                    : AppTheme.dangerRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${kit.readinessPercentage.toStringAsFixed(0)}% • ${kit.packedItemsCount}/${kit.totalItemsCount}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: accentTone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Smart Recommender Banner
                InkWell(
                  onTap: () => _showSmartRecommenderDialog(context, kit, isDark, isFil),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryNavy.withAlpha(90)
                          : AppTheme.primaryNavy.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.lightBlue.shade200.withAlpha(80)
                            : AppTheme.primaryNavy.withAlpha(55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20, color: accentTone),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isFil
                                ? 'Laki ng Sambahayan: ${kit.householdProfile.totalPeople} • I-tap para i-customize'
                                : 'Household Size: ${kit.householdProfile.totalPeople} person(s) • Tap to customize kit',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: accentTone,
                            ),
                          ),
                        ),
                        Icon(Icons.tune, size: 18, color: accentTone),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Search Input Field
                TextField(
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: isFil
                        ? 'Maghanap ng gamit (tubig, gamot, baterya)...'
                        : 'Search supplies (e.g., water, meds, battery)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: kit.searchQuery.isNotEmpty
                        ? IconButton(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => kit.setSearchQuery(''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
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
                        context,
                        isDark: isDark,
                        label: '${isFil ? 'Lahat' : 'All'} (${kit.totalItemsCount})',
                        status: ItemFilterStatus.all,
                        isSelected: kit.filterStatus == ItemFilterStatus.all,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.all),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        context,
                        isDark: isDark,
                        label: '${isFil ? 'Kulang' : 'Missing'} (${kit.missingItemsCount})',
                        status: ItemFilterStatus.missing,
                        isSelected: kit.filterStatus == ItemFilterStatus.missing,
                        selectedColor: Colors.orange.shade700,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.missing),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        context,
                        isDark: isDark,
                        label: '${isFil ? 'Malapit Ma-expire' : 'Expiring'} (${kit.expiringSoonItemsCount})',
                        status: ItemFilterStatus.expiringSoon,
                        isSelected: kit.filterStatus == ItemFilterStatus.expiringSoon,
                        selectedColor: AppTheme.warningAmber,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.expiringSoon),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        context,
                        isDark: isDark,
                        label: '${isFil ? 'Paso Na' : 'Expired'} (${kit.expiredItemsCount})',
                        status: ItemFilterStatus.expired,
                        isSelected: kit.filterStatus == ItemFilterStatus.expired,
                        selectedColor: AppTheme.dangerRed,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.expired),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusFilterChip(
                        context,
                        isDark: isDark,
                        label: '${isFil ? 'Kumpleto' : 'Packed'} (${kit.packedItemsCount})',
                        status: ItemFilterStatus.packed,
                        isSelected: kit.filterStatus == ItemFilterStatus.packed,
                        selectedColor: AppTheme.safeGreen,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.packed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Category Selector + Add Item Button (positioned away from bottom-right global SOS FAB)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBg : AppTheme.surfaceBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<KitCategory?>(
                            value: kit.selectedCategory,
                            isExpanded: true,
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            hint: Text(
                              isFil ? 'Lahat ng Kategorya' : 'All Categories',
                              style: const TextStyle(fontSize: 14),
                            ),
                            items: [
                              DropdownMenuItem<KitCategory?>(
                                value: null,
                                child: Text(
                                  isFil ? 'Lahat ng Kategorya' : 'All Categories',
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(isFil ? 'Dagdag' : 'Add Item'),
                      onPressed: () => _showAddEditItemDialog(context, kit, isDark, isFil),
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                      itemCount: kit.filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = kit.filteredItems[index];
                        return _buildItemCard(context, item, kit, s, isDark, isFil);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(
    BuildContext context, {
    required bool isDark,
    required String label,
    required ItemFilterStatus status,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onSelected,
  }) {
    final activeColor = selectedColor ?? AppTheme.primaryNavy;
    return ChoiceChip(
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.darkSlate),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? AppTheme.darkBg : Colors.grey.shade100,
      side: BorderSide(
        color: isSelected
            ? activeColor
            : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        width: 1,
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
            Icon(Icons.inventory_2_outlined, size: 64, color: subtleText),
            const SizedBox(height: 12),
            Text(
              isFil ? 'Walang Nahanap na Gamit' : 'No Supplies Found',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              kit.searchQuery.isNotEmpty ||
                      kit.selectedCategory != null ||
                      kit.filterStatus != ItemFilterStatus.all
                  ? (isFil
                      ? 'Walang tumugma sa iyong search o filter.'
                      : 'No items match your active search or filters.')
                  : (isFil
                      ? 'Magsimula sa pagdagdag ng mahahalagang gamit sa Go-Bag.'
                      : 'Start by adding essential supplies to your Go-Bag.'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subtleText),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                kit.setSearchQuery('');
                kit.setSelectedCategory(null);
                kit.setFilterStatus(ItemFilterStatus.all);
              },
              child: Text(isFil ? 'I-clear ang Filter' : 'Clear Filters'),
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
    Color cardBorder = isDark ? AppTheme.darkBorder : Colors.grey.shade200;
    if (item.isExpired) {
      cardBorder = AppTheme.dangerRed.withAlpha(180);
    } else if (isExpiring) {
      cardBorder = AppTheme.warningAmber.withAlpha(180);
    }

    final titleColor = isDark ? Colors.white : AppTheme.darkSlate;
    final subtleText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cardBorder,
          width: item.isExpired || isExpiring ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(
                    value: item.isComplete,
                    activeColor: AppTheme.safeGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (_) => kit.togglePacked(item.id),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withAlpha(20)
                                  : Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.categoryName(item.category),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.blueGrey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${isFil ? 'Target' : 'Target'}: ${item.targetQuantity} ${item.unit}',
                            style: TextStyle(fontSize: 14, color: subtleText),
                          ),
                          if (item.isPartial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.orange.withAlpha(45)
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isFil ? 'Kulang' : 'Low Stock',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange.shade200
                                      : Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 22, color: subtleText),
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
                          const Icon(Icons.edit, size: 18),
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
                            const Icon(Icons.autorenew,
                                size: 18, color: AppTheme.safeGreen),
                            const SizedBox(width: 8),
                            Text(isFil ? 'Markahang Pinalitan' : 'Mark Replaced'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete,
                              size: 18, color: AppTheme.dangerRed),
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
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(
                  item.notes,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: subtleText,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildExpiryBadge(item, kit.expiryAlertDays, isDark, isFil),

                  if (item.isExpired || isExpiring)
                    ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      avatar: const Icon(Icons.autorenew,
                          size: 16, color: Colors.white),
                      label: Text(
                        isFil ? 'Palitan' : 'Replace',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: item.isExpired
                          ? AppTheme.dangerRed
                          : AppTheme.warningAmber,
                      onPressed: () => _quickReplaceItem(context, kit, item, isFil),
                    ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        color: subtleText,
                        onPressed: item.quantity > 0
                            ? () => kit.updateQuantity(item.id, item.quantity - 1)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBg : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity} ${item.unit}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        color: isDark
                            ? Colors.lightBlue.shade200
                            : AppTheme.primaryNavy,
                        onPressed: () =>
                            kit.updateQuantity(item.id, item.quantity + 1),
                      ),
                    ],
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
          color: isDark ? AppTheme.darkBg : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isFil ? 'Hindi napapanis' : 'Non-perishable',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      );
    }

    final formattedDate = DateFormat('MMM dd, yyyy').format(item.expirationDate!);
    final days = item.daysUntilExpiration ?? 0;

    if (item.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.dangerRed.withAlpha(45)
              : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.dangerRed),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error,
              size: 16,
              color: isDark ? Colors.red.shade200 : AppTheme.dangerRed,
            ),
            const SizedBox(width: 6),
            Text(
              'EXPIRED ($formattedDate)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.red.shade200 : AppTheme.dangerRed,
              ),
            ),
          ],
        ),
      );
    } else if (item.isExpiringWithin(thresholdDays)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.warningAmber.withAlpha(45)
              : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.warningAmber),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
              size: 16,
              color: isDark ? Colors.amber.shade200 : AppTheme.warningAmber,
            ),
            const SizedBox(width: 6),
            Text(
              isFil ? 'Mapapaso sa $days araw' : 'Expires in $days days',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.amber.shade200 : AppTheme.warningAmber,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.safeGreen.withAlpha(45)
              : Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Exp: $formattedDate ($days d)',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.green.shade200 : Colors.green.shade800,
          ),
        ),
      );
    }
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
          ? 'Bagong Expiration Date ng Kapalit'
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
              '${item.name} updated! New expiry: ${DateFormat('MMM dd, yyyy').format(picked)}',
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

    final accentColor = isDark ? Colors.lightBlue.shade200 : AppTheme.primaryNavy;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFil ? 'Smart Kit Recommender' : 'Smart Kit Recommender',
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
                      ? 'Itakda ang laki ng iyong sambahayan para awtomatikong kalkulahin ang 72-oras na rasyon.'
                      : 'Configure your household profile to automatically calculate 72-hour quantities and recommend specialized supplies.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStepperRow(
                  isFil ? 'Matanda (18-59)' : 'Adults (18-59)',
                  adults,
                  (v) => setState(() => adults = v),
                  min: 1,
                ),
                _buildStepperRow(
                  isFil ? 'Bata (3-17)' : 'Children (3-17)',
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
                    isFil ? 'Bahang Barangay' : 'Flood-Prone Barangay',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: isFloodProne,
                  onChanged: (v) => setState(() => isFloodProne = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isFil ? 'Lindol / High-Rise Zone' : 'Earthquake / High-Rise Zone',
                    style: const TextStyle(fontSize: 14),
                  ),
                  value: isEarthquakeZone,
                  onChanged: (v) =>
                      setState(() => isEarthquakeZone = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isFil ? 'May Maintenance na Gamot' : 'Chronic Medical Needs',
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
            ElevatedButton(
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
                        'Kit customized for ${profile.totalPeople} people! Scaled ${res.updatedCount} items, added ${res.addedCount} tailored items.',
                      ),
                    ),
                  );
                }
              },
              child: Text(isFil ? 'Ilapat' : 'Apply'),
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
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              onPressed: val > min ? () => onChanged(val - 1) : null,
            ),
            Text('$val',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
              ? 'Ibabalik nito ang standard na Philippine NDRRMC / Red Cross emergency go-bag checklist.'
              : 'This will restore the standard Philippine NDRRMC / Red Cross emergency go-bag supplies checklist.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFil ? 'Kanselahin' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              kit.resetToDefault();
              Navigator.pop(ctx);
            },
            child: Text(isFil ? 'I-reset' : 'Reset Checklist'),
          ),
        ],
      ),
    );
  }
}

/// Dedicated StatefulWidget for Add/Edit Item dialog so controllers persist cleanly across setState rebuilds
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
                  labelText: widget.isFil ? 'Pangalan ng Gamit *' : 'Item Name *',
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
                        labelText: widget.isFil ? 'Kasalukuyan' : 'Current Qty',
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
                        labelText: widget.isFil ? 'Target *' : 'Target Qty *',
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
                  labelText: 'Unit (pcs, cans, gallons, etc)',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedExpDate == null
                      ? (widget.isFil
                          ? 'Walang Expiration Date'
                          : 'No Expiration Date Set')
                      : 'Expires: ${DateFormat('yyyy-MM-dd').format(_selectedExpDate!)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedExpDate != null)
                      IconButton(
                        constraints:
                            const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: 'Clear Expiration Date',
                        onPressed: () =>
                            setState(() => _selectedExpDate = null),
                      ),
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(
                        Icons.calendar_today,
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
                  labelText: 'Storage Instructions / Notes',
                  hintText: 'e.g. Keep dry, store in airtight container',
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
        ElevatedButton(
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
                ? (widget.isFil ? 'I-save' : 'Save Changes')
                : (widget.isFil ? 'Idagdag' : 'Add Item'),
          ),
        ),
      ],
    );
  }
}
