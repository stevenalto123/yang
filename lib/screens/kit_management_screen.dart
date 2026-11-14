import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/kit_item.dart';
import '../providers/kit_provider.dart';
import '../utils/app_theme.dart';

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
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Default Checklist',
            onPressed: () => _showResetDialog(context, kit),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Custom Item',
            onPressed: () => _showAddEditItemDialog(context, kit),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.all),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Missing (${kit.missingItemsCount})',
                        status: ItemFilterStatus.missing,
                        isSelected: kit.filterStatus == ItemFilterStatus.missing,
                        selectedColor: Colors.orange.shade700,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.missing),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Expiring Soon (${kit.expiringSoonItemsCount})',
                        status: ItemFilterStatus.expiringSoon,
                        isSelected: kit.filterStatus == ItemFilterStatus.expiringSoon,
                        selectedColor: AppTheme.warningAmber,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.expiringSoon),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Expired (${kit.expiredItemsCount})',
                        status: ItemFilterStatus.expired,
                        isSelected: kit.filterStatus == ItemFilterStatus.expired,
                        selectedColor: AppTheme.accentAlert,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.expired),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusFilterChip(
                        context,
                        label: 'Packed (${kit.packedItemsCount})',
                        status: ItemFilterStatus.packed,
                        isSelected: kit.filterStatus == ItemFilterStatus.packed,
                        selectedColor: AppTheme.safeGreen,
                        onSelected: () => kit.setFilterStatus(ItemFilterStatus.packed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Category Selector
                Row(
                  children: [
                    const Text('Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<KitCategory?>(
                          value: kit.selectedCategory,
                          isDense: true,
                          isExpanded: true,
                          hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
                          items: [
                            const DropdownMenuItem<KitCategory?>(
                              value: null,
                              child: Text('All Categories', style: TextStyle(fontSize: 13)),
                            ),
                            ...KitCategory.values.map(
                              (cat) => DropdownMenuItem<KitCategory?>(
                                value: cat,
                                child: Text(cat.displayName, style: const TextStyle(fontSize: 13)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No Supplies Found',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              kit.searchQuery.isNotEmpty || kit.selectedCategory != null || kit.filterStatus != ItemFilterStatus.all
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
    Color cardBorder = Colors.grey.shade200;
    if (item.isExpired) {
      cardBorder = AppTheme.accentAlert.withAlpha(128);
    } else if (item.isExpiringSoon) {
      cardBorder = AppTheme.warningAmber.withAlpha(128);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: item.isExpired || item.isExpiringSoon ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Packed Checkbox
                Transform.scale(
                  scale: 1.15,
                  child: Checkbox(
                    value: item.isPacked,
                    activeColor: AppTheme.safeGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    onChanged: (_) => kit.togglePacked(item.id),
                  ),
                ),
                const SizedBox(width: 4),
                // Item Name and Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: item.isPacked ? AppTheme.darkSlate : Colors.grey.shade800,
                          decoration: item.isPacked && !item.isExpired ? null : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category.displayName,
                              style: TextStyle(fontSize: 10.5, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Target: ${item.targetQuantity} ${item.unit}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Edit & Delete actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showAddEditItemDialog(context, kit, existingItem: item);
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
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Bottom bar: Expiry Badge and Quantity Controls
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expiry Tracking Badge
                  _buildExpiryBadge(item),

                  // Quantity Stepper
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: Colors.grey.shade700,
                        onPressed: item.quantity > 0
                            ? () => kit.updateQuantity(item.id, item.quantity - 1)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.quantity} ${item.unit}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        color: AppTheme.primaryCrimson,
                        onPressed: () => kit.updateQuantity(item.id, item.quantity + 1),
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

  Widget _buildExpiryBadge(KitItem item) {
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

    final formattedDate = DateFormat('MMM dd, yyyy').format(item.expirationDate!);
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
    } else if (item.isExpiringSoon) {
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
          'Exp: $formattedDate ($days days)',
          style: TextStyle(fontSize: 10.5, color: Colors.green.shade800),
        ),
      );
    }
  }

  void _showAddEditItemDialog(BuildContext context, KitProvider kit, {KitItem? existingItem}) {
    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final notesCtrl = TextEditingController(text: existingItem?.notes ?? '');
    final unitCtrl = TextEditingController(text: existingItem?.unit ?? 'pcs');
    int targetQty = existingItem?.targetQuantity ?? 1;
    int currentQty = existingItem?.quantity ?? 0;
    KitCategory selectedCat = existingItem?.category ?? KitCategory.waterAndFood;
    DateTime? selectedExpDate = existingItem?.expirationDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Supply Item' : 'Add New Supply Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'e.g. Bottled Water, Paracetamol',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<KitCategory>(
                      value: selectedCat,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: KitCategory.values
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.displayName)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: 'Target Qty'),
                            keyboardType: TextInputType.number,
                            controller: TextEditingController(text: targetQty.toString()),
                            onChanged: (val) => targetQty = int.tryParse(val) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(labelText: 'Unit (pcs, cans, etc)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Expiration Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedExpDate == null
                            ? 'No Expiration Date Set'
                            : 'Expires: ${DateFormat('yyyy-MM-dd').format(selectedExpDate!)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedExpDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => selectedExpDate = null),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today, color: AppTheme.primaryCrimson),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedExpDate ?? DateTime.now().add(const Duration(days: 90)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => selectedExpDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Storage Instructions / Notes',
                        hintText: 'e.g. Keep dry, store in airtight container',
                      ),
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
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    if (isEditing) {
                      kit.editItem(
                        existingItem.copyWith(
                          name: name,
                          category: selectedCat,
                          targetQuantity: targetQty,
                          unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                          expirationDate: selectedExpDate,
                          notes: notesCtrl.text.trim(),
                        ),
                      );
                    } else {
                      kit.addItem(
                        KitItem(
                          id: const Uuid().v4(),
                          name: name,
                          category: selectedCat,
                          quantity: currentQty,
                          targetQuantity: targetQty,
                          unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                          expirationDate: selectedExpDate,
                          notes: notesCtrl.text.trim(),
                          isPacked: false,
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Add Item'),
                ),
              ],
            );
          },
        );
      },
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAlert),
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
