import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

class Item {
  final String? id;        // Firestore doc id
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
    return Item(
      id: id,
      name: (map['name'] ?? '') as String,
      quantity: (map['quantity'] ?? 0) as int,
      price: (map['price'] is int)
          ? (map['price'] as int).toDouble()
          : (map['price'] ?? 0.0) as double,
      category: (map['category'] ?? '') as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _col = FirebaseFirestore.instance.collection('items');

  Future<void> addItem(Item item) async => _col.add(item.toMap());

  Stream<List<Item>> getItemsStream() => _col
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Item.fromMap(d.id, d.data())).toList());

  Future<void> updateItem(Item item) async {
    if (item.id == null) return;
    await _col.doc(item.id!).update(item.toMap());
  }

  Future<void> deleteItem(String id) async => _col.doc(id).delete();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Management App',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/': (_) => const InventoryHomePage(title: 'Inventory Home Page'),
        AddEditItemScreen.routeName: (_) => const AddEditItemScreen(),
        DashboardScreen.routeName: (_) => const DashboardScreen(),
      },
    );
  }
}

class AddEditItemScreen extends StatefulWidget {
  static const routeName = '/addEdit';
  const AddEditItemScreen({super.key, this.item});
  final Item? item; // if non-null => edit mode

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

    final item = Item(
      id: widget.item?.id,
      name: _nameCtrl.text.trim(),
      quantity: int.parse(_qtyCtrl.text.trim()),
      price: double.parse(_priceCtrl.text.trim()),
      category: _categoryCtrl.text.trim(),
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );

    if (_edit) {
      await FirestoreService.instance.updateItem(item);
    } else {
      await FirestoreService.instance.addItem(item);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.item?.id != null) {
      await FirestoreService.instance.deleteItem(widget.item!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // also accept Item via Navigator arguments\
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Item && !_edit && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = arg.name;
      _qtyCtrl.text = arg.quantity.toString();
      _priceCtrl.text = arg.price.toStringAsFixed(2);
      _categoryCtrl.text = arg.category;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_edit ? 'Edit Item' : 'Add Item'),
        actions: [
          if (_edit)
            IconButton(
              tooltip: 'Delete',
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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Enter a non-negative integer';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Enter a non-negative number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category (e.g., Food, Tech)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
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
//bonus feature: dashboard screen