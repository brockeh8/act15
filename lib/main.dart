import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 


class Item {
  final String? id; 
  final String name;
  final int quantity;
  final double price;
  final String category;
  final DateTime createdAt;

  Item({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.category,
    required this.createdAt,
  });


  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }


  factory Item.fromMap(String id, Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return Item(
      id: id,
      name: (map['name'] ?? '') as String,
      quantity: (map['quantity'] ?? 0) as int,
      price: (map['price'] is int)
          ? (map['price'] as int).toDouble()
          : (map['price'] ?? 0.0) as double,
      category: (map['category'] ?? '') as String,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}


class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('items');

  Future<void> addItem(Item item) async {
    await _col.add(item.toMap());
  }

  Stream<List<Item>> getItemsStream() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => Item.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateItem(Item item) async {
    if (item.id == null) return;
    await _col.doc(item.id!).update(item.toMap());
  }

  Future<void> deleteItem(String id) async {
    await _col.doc(id).delete();
  }


  Future<void> deleteMany(List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
  }
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const InventoryHomePage(title: 'Inventory Home Page'),
    );
  }
}

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key, required this.title});
  final String title;

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final _searchCtrl = TextEditingController();
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected items?'),
        content: Text('This will delete ${_selectedIds.length} item(s).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirestoreService.instance.deleteMany(_selectedIds.toList());
      if (mounted) {
        setState(() {
          _selectMode = false;
          _selectedIds.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _selectMode ? 'Exit select mode' : 'Select multiple',
            icon: Icon(
              _selectMode ? Icons.close : Icons.check_box_outlined,
            ),
            onPressed: _toggleSelectMode,
          ),
          if (_selectMode)
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete),
              onPressed: _bulkDelete,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: FirestoreService.instance.getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snapshot.data!;
                final q = _searchCtrl.text.toLowerCase();

                // Apply search filter
                if (q.isNotEmpty) {
                  items = items
                      .where((e) => e.name.toLowerCase().contains(q))
                      .toList();
                }

                if (items.isEmpty) {
                  return const Center(
                    child: Text('No items yet. Tap + to add.'),
                  );
                }

                final totalValue = items.fold<double>(
                  0,
                  (sum, it) => sum + it.quantity * it.price,
                );

                return Column(
                  children: [
                    // Tiny data insight
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total value: \$${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final it = items[i];
                          final id = it.id ?? '${it.name}-$i';
                          final selected = _selectedIds.contains(id);

                          return Dismissible(
                            key: ValueKey(id),
                            direction: _selectMode
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) async {
                              if (!_selectMode && it.id != null) {
                                await FirestoreService.instance
                                    .deleteItem(it.id!);
                              }
                            },
                            child: ListTile(
                              leading: _selectMode
                                  ? Checkbox(
                                      value: selected,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedIds.add(id);
                                          } else {
                                            _selectedIds.remove(id);
                                          }
                                        });
                                      },
                                    )
                                  : null,
                              title: Text(it.name),
                              subtitle: Text(
                                '${it.category} • Qty: ${it.quantity} • \$${it.price.toStringAsFixed(2)}',
                              ),
                              trailing: Text(
                                '${it.createdAt.month}/${it.createdAt.day}/${it.createdAt.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              onTap: () {
                                if (_selectMode) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(id);
                                    } else {
                                      _selectedIds.add(id);
                                    }
                                  });
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AddEditItemScreen(item: it),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Item',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditItemScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


class AddEditItemScreen extends StatefulWidget {
  const AddEditItemScreen({super.key, this.item});
  final Item? item; // if not null → edit mode

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  bool get _edit => widget.item != null;

  @override
  void initState() {
    super.initState();
    if (_edit) {
      final it = widget.item!;
      _nameCtrl.text = it.name;
      _qtyCtrl.text = it.quantity.toString();
      _priceCtrl.text = it.price.toStringAsFixed(2);
      _categoryCtrl.text = it.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newItem = Item(
      id: widget.item?.id,
      name: _nameCtrl.text.trim(),
      quantity: int.parse(_qtyCtrl.text.trim()),
      price: double.parse(_priceCtrl.text.trim()),
      category: _categoryCtrl.text.trim(),
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );

    if (_edit) {
      await FirestoreService.instance.updateItem(newItem);
    } else {
      await FirestoreService.instance.addItem(newItem);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (! _edit || widget.item!.id == null) return;
    await FirestoreService.instance.deleteItem(widget.item!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_edit ? 'Edit Item' : 'Add Item'),
        actions: [
          if (_edit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) {
                    return 'Enter a non-negative integer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) {
                    return 'Enter a non-negative number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(
                    labelText: 'Category (e.g., Food, Tech)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(_edit ? 'Save Changes' : 'Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
