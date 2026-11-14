import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/evacuation_center.dart';
import '../providers/emergency_provider.dart';
import '../utils/app_theme.dart';

class EvacuationMapScreen extends StatelessWidget {
  const EvacuationMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final centers = emergency.filteredEvacuationCenters;
    final cities = emergency.availableCities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evacuation Shelters & Maps'),
      ),
      body: Column(
        children: [
          // Offline banner
          Container(
            color: const Color(0xFFE0F2F1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pre-loaded Designated Evacuation Centers • Offline Accessible',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // City Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: cities.map((city) {
                final isSelected = emergency.selectedCity == city;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(city == 'All' ? 'All Locations' : city),
                    selected: isSelected,
                    selectedColor: Colors.teal.shade700,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => emergency.setSelectedCity(city),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Evacuation Centers List
          Expanded(
            child: centers.isEmpty
                ? const Center(child: Text('No evacuation shelters found for selected area.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: centers.length,
                    itemBuilder: (context, index) {
                      final center = centers[index];
                      return _buildShelterCard(context, center, emergency);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelterCard(
    BuildContext context,
    EvacuationCenter center,
    EmergencyProvider emergency,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal.shade50,
                  radius: 20,
                  child: Icon(Icons.roofing_rounded, color: Colors.teal.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkSlate,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              center.address,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: center.isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    center.isOpen ? 'ACTIVE' : 'STANDBY',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: center.isOpen ? AppTheme.safeGreen : AppTheme.accentAlert,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Facilities & Capacity
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 15, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(
                            'Capacity: ${center.capacityPeople} individuals',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        'City: ${center.city}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Facilities: ${center.facilities}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Navigation and Call actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('View Route & Map', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      emergency.openMapLocation(
                        center.latitude,
                        center.longitude,
                        center.name,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade800,
                    side: BorderSide(color: Colors.teal.shade700),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call Officer', style: TextStyle(fontSize: 12)),
                  onPressed: () => emergency.makePhoneCall(center.contactNumber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
