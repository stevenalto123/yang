import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/kit_item.dart';
import '../models/household_profile.dart';
import '../providers/kit_provider.dart';
import '../utils/app_theme.dart';
import 'notifications_screen.dart';

class KitManagementScreen extends StatelessWidget {
  const KitManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kit = context.watch<KitProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Kit Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Smart Kit Recommender',
            onPressed: () => _showSmartRecommenderDialog(context, kit),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Replacement Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Default Checklist',
            onPressed: () => _showResetDialog(context, kit),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search, Recommender & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Smart Recommender Banner
                InkWell(
                  onTap: () => _showSmartRecommenderDialog(context, kit),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCrimson.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppTheme.primaryCrimson.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 18, color: AppTheme.primaryCrimson),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Household Size: ${kit.householdProfile.totalPeople} person(s) • Tap to customize & recommend items',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryCrimson,
                            ),
                          ),
                        ),
                        const Icon(Icons.tune,
                            size: 16, color: AppTheme.primaryCrimson),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Search Input Field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supplies (e.g., water, meds, battery)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: kit.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => kit.setSearchQuery(''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
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
                        label: 'All (${kit.totalItemsCount})',
                        status: ItemFilterStatus.all,
                        isSelected: kit.filterStatus == ItemFilterStatus.all,
                        onSelected: () =>
                            kit.setFilterStatus(ItemFilterStatus.all),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Missing (${kit.missingItemsCount})',
                        status: ItemFilterStatus.missing,
                        isSelected:
                            kit.filterStatus == ItemFilterStatus.missing,
                        selectedColor: Colors.orange.shade700,
                        onSelected: () =>
                            kit.setFilterStatus(ItemFilterStatus.missing),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label:
                            'Expiring (${kit.expiringSoonItemsCount})',
                        status: ItemFilterStatus.expiringSoon,
                        isSelected:
                            kit.filterStatus == ItemFilterStatus.expiringSoon,
                        selectedColor: AppTheme.warningAmber,
                        onSelected: () =>
                            kit.setFilterStatus(ItemFilterStatus.expiringSoon),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Expired (${kit.expiredItemsCount})',
                        status: ItemFilterStatus.expired,
                        isSelected:
                            kit.filterStatus == ItemFilterStatus.expired,
                        selectedColor: AppTheme.accentAlert,
                        onSelected: () =>
                            kit.setFilterStatus(ItemFilterStatus.expired),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Packed (${kit.packedItemsCount})',
                        status: ItemFilterStatus.packed,
                        isSelected: kit.filterStatus == ItemFilterStatus.packed,
                        selectedColor: AppTheme.safeGreen,
                        onSelected: () =>
                            kit.setFilterStatus(ItemFilterStatus.packed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Category Selector
                Row(
                  children: [
                    const Text('Category: ',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<KitCategory?>(
                          value: kit.selectedCategory,
                          isDense: true,
                          isExpanded: true,
                          hint: const Text('All Categories',
                              style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<KitCategory?>(
                              value: null,
                              child: Text('All Categories',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            ...KitCategory.values.map(
                              (cat) => DropdownMenuItem<KitCategory?>(
                                value: cat,
                                child: Text(cat.displayName,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                          onChanged: (cat) => kit.setSelectedCategory(cat),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Items List
          Expanded(
            child: kit.filteredItems.isEmpty
                ? _buildEmptyState(kit)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    itemCount: kit.filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = kit.filteredItems[index];
                      return _buildItemCard(context, item, kit);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryCrimson,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        onPressed: () => _showAddEditItemDialog(context, kit),
      ),
    );
  }

  Widget _buildStatusFilterChip(
    BuildContext context, {
    required String label,
    required ItemFilterStatus status,
    required bool isSelected,
    Color? selectedColor,
    required VoidCallback onSelected,
  }) {
    final activeColor = selectedColor ?? AppTheme.primaryCrimson;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      selected: isSelected,
      selectedColor: activeColor,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? activeColor : Colors.grey.shade300,
        width: 1,
      ),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildEmptyState(KitProvider kit) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Supplies Found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              kit.searchQuery.isNotEmpty ||
                      kit.selectedCategory != null ||
                      kit.filterStatus != ItemFilterStatus.all
                  ? 'No items match your active search or filters.'
                  : 'Start by adding essential supplies to your Go-Bag.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                kit.setSearchQuery('');
                kit.setSelectedCategory(null);
                kit.setFilterStatus(ItemFilterStatus.all);
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, KitItem item, KitProvider kit) {
    final isExpiring = item.isExpiringWithin(kit.expiryAlertDays);
    Color cardBorder = Colors.grey.shade200;
    if (item.isExpired) {
      cardBorder = AppTheme.accentAlert.withAlpha(140);
    } else if (isExpiring) {
      cardBorder = AppTheme.warningAmber.withAlpha(140);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: cardBorder,
            width: item.isExpired || isExpiring ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 1.15,
                  child: Checkbox(
                    value: item.isComplete,
                    activeColor: AppTheme.safeGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: item.isComplete
                              ? AppTheme.darkSlate
                              : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.displayName,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.blueGrey.shade800,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            'Target: ${item.targetQuantity} ${item.unit}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                          if (item.isPartial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Low Stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditItemDialog(context, kit,
                          existingItem: item);
                    } else if (val == 'replace') {
                      _quickReplaceItem(context, kit, item);
                    } else if (val == 'delete') {
                      kit.deleteItem(item.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Item'),
                        ],
                      ),
                    ),
                    if (item.expirationDate != null)
                      const PopupMenuItem(
                        value: 'replace',
                        child: Row(
                          children: [
                            Icon(Icons.autorenew,
                                size: 18, color: AppTheme.safeGreen),
                            SizedBox(width: 8),
                            Text('Mark Replaced'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
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
                padding: const EdgeInsets.only(left: 42),
                child: Text(
                  item.notes,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Responsive Wrap layout prevents narrow-screen horizontal overflow
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildExpiryBadge(item, kit.expiryAlertDays),

                  if (item.isExpired || isExpiring)
                    ActionChip(
                      avatar: const Icon(Icons.autorenew,
                          size: 14, color: Colors.white),
                      label: const Text('Replace',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      backgroundColor: item.isExpired
                          ? AppTheme.accentAlert
                          : AppTheme.warningAmber,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _quickReplaceItem(context, kit, item),
                    ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: Colors.grey.shade700,
                        onPressed: item.quantity > 0
                            ? () =>
                                kit.updateQuantity(item.id, item.quantity - 1)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity} ${item.unit}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppTheme.primaryCrimson,
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

  Widget _buildExpiryBadge(KitItem item, int thresholdDays) {
    if (item.expirationDate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Non-perishable',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      );
    }

    final formattedDate =
        DateFormat('MMM dd, yyyy').format(item.expirationDate!);
    final days = item.daysUntilExpiration ?? 0;

    if (item.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.accentAlert),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 12, color: AppTheme.accentAlert),
            const SizedBox(width: 4),
            Text(
              'EXPIRED ($formattedDate)',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentAlert,
              ),
            ),
          ],
        ),
      );
    } else if (item.isExpiringWithin(thresholdDays)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.warningAmber),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, size: 12, color: AppTheme.warningAmber),
            const SizedBox(width: 4),
            Text(
              'Expires in $days days',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.warningAmber,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Exp: $formattedDate ($days d)',
          style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
        ),
      );
    }
  }

  Future<void> _quickReplaceItem(
      BuildContext context, KitProvider kit, KitItem item) async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'New Expiration Date for Replaced Supply',
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
                '${item.name} updated! New expiry: ${DateFormat('MMM dd, yyyy').format(picked)}'),
          ),
        );
      }
    }
  }

  void _showAddEditItemDialog(BuildContext context, KitProvider kit,
      {KitItem? existingItem}) {
    showDialog(
      context: context,
      builder: (_) => _AddEditItemDialog(kit: kit, existingItem: existingItem),
    );
  }

  void _showSmartRecommenderDialog(BuildContext context, KitProvider kit) {
    final p = kit.householdProfile;
    int adults = p.adults;
    int children = p.children;
    int infants = p.infants;
    int seniors = p.seniors;
    int pets = p.pets;
    bool isFloodProne = p.isFloodProne;
    bool isEarthquakeZone = p.isEarthquakeZone;
    bool hasChronicMeds = p.hasChronicMedicalNeeds;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primaryCrimson),
              SizedBox(width: 8),
              Expanded(
                child: Text('Smart Kit Recommender',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure your household profile to automatically calculate 72-hour quantities and recommend specialized supplies.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                _buildStepperRow('Adults (18-59)', adults,
                    (v) => setState(() => adults = v), min: 1),
                _buildStepperRow('Children (3-17)', children,
                    (v) => setState(() => children = v)),
                _buildStepperRow('Infants / Toddlers', infants,
                    (v) => setState(() => infants = v)),
                _buildStepperRow('Senior Citizens (60+)', seniors,
                    (v) => setState(() => seniors = v)),
                _buildStepperRow(
                    'Pets', pets, (v) => setState(() => pets = v)),
                const Divider(),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Flood-Prone Barangay',
                      style: TextStyle(fontSize: 13)),
                  value: isFloodProne,
                  onChanged: (v) =>
                      setState(() => isFloodProne = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Earthquake / High-Rise Zone',
                      style: TextStyle(fontSize: 13)),
                  value: isEarthquakeZone,
                  onChanged: (v) =>
                      setState(() => isEarthquakeZone = v ?? false),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chronic Medical Needs',
                      style: TextStyle(fontSize: 13)),
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
              child: const Text('Cancel'),
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
              child: const Text('Apply Recommendations'),
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
        Text(label, style: const TextStyle(fontSize: 13)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: val > min ? () => onChanged(val - 1) : null,
            ),
            Text('$val', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => onChanged(val + 1),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, KitProvider kit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Standard 72-Hour Kit?'),
        content: const Text(
          'This will restore the standard Philippine NDRRMC / Red Cross emergency go-bag supplies checklist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAlert),
            onPressed: () {
              kit.resetToDefault();
              Navigator.pop(ctx);
            },
            child: const Text('Reset Checklist'),
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

  const _AddEditItemDialog({required this.kit, this.existingItem});

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

    return AlertDialog(
      title: Text(isEditing ? 'Edit Supply Item' : 'Add New Supply Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Bottled Water, Paracetamol',
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter an item name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<KitCategory>(
                value: _selectedCat,
                decoration: const InputDecoration(labelText: 'Category'),
                items: KitCategory.values
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c.displayName)))
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
                      decoration: const InputDecoration(labelText: 'Current Qty'),
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
                      decoration: const InputDecoration(labelText: 'Target Qty *'),
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
                    labelText: 'Unit (pcs, cans, gallons, etc)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _selectedExpDate == null
                      ? 'No Expiration Date Set'
                      : 'Expires: ${DateFormat('yyyy-MM-dd').format(_selectedExpDate!)}',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedExpDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear Expiration Date',
                        onPressed: () =>
                            setState(() => _selectedExpDate = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today,
                          color: AppTheme.primaryCrimson),
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
          child: const Text('Cancel'),
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
          child: Text(isEditing ? 'Save Changes' : 'Add Item'),
        ),
      ],
    );
  }
}
