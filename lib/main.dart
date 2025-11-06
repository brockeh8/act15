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