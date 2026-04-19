import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InventoryItem {
  final String id;
  final String name;
  final String price;
  final bool available;

  InventoryItem({
    required this.id,
    required this.name,
    required this.price,
    required this.available,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      available: json['available'],
    );
  }

  String toChatMessage() => 'I would like: $name ($price)';
}

class InventoryPanel extends StatefulWidget {
  final Function(String message) onItemSelected;

  const InventoryPanel({super.key, required this.onItemSelected});

  @override
  State<InventoryPanel> createState() => _InventoryPanelState();
}

class _InventoryPanelState extends State<InventoryPanel> {
  List<InventoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final String data = await rootBundle.loadString('assets/inventory.json');
    final Map<String, dynamic> json = jsonDecode(data);
    setState(() {
      _items = (json['items'] as List)
          .map((e) => InventoryItem.fromJson(e))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Available Items',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _ItemTile(
                        item: item,
                        onTap: item.available
                            ? () {
                                widget.onItemSelected(item.toChatMessage());
                                Navigator.pop(context);
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;

  const _ItemTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool available = item.available;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: available
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: available
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: available ? Colors.white : Colors.white38,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.price,
                    style: TextStyle(
                      color: available ? Colors.white54 : Colors.white24,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (!available)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Unavailable',
                  style: TextStyle(color: Colors.white30, fontSize: 11),
                ),
              )
            else
              Icon(Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.2), size: 14),
          ],
        ),
      ),
    );
  }
}