import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../../core/theme/mpesa_theme.dart';

class VendorMenuEditor extends StatefulWidget {
  const VendorMenuEditor({super.key});

  @override
  State<VendorMenuEditor> createState() => _VendorMenuEditorState();
}

class _VendorMenuEditorState extends State<VendorMenuEditor> {
  final _picker = ImagePicker();
  bool _isLoading = false;

  void _showAddEditDialog([DocumentSnapshot? doc]) {
    final isEditing = doc != null;
    final nameController = TextEditingController(text: isEditing ? doc['name'] : '');
    final priceController = TextEditingController(text: isEditing ? doc['price'].toString() : '');
    final descController = TextEditingController(text: isEditing ? doc['description'] : '');
    File? selectedImage;
    String? existingImageUrl = isEditing ? doc['imageUrl'] : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isSaving = false;

            Future<void> saveItem() async {
              if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) return;
              
              setStateDialog(() => isSaving = true);
              try {
                final vendorId = FirebaseAuth.instance.currentUser!.uid;
                String? finalImageUrl = existingImageUrl;

                if (selectedImage != null) {
                  final ref = FirebaseStorage.instance.ref().child('vendor_menus').child(vendorId).child('${const Uuid().v4()}.jpg');
                  await ref.putFile(selectedImage!);
                  finalImageUrl = await ref.getDownloadURL();
                }

                final data = {
                  'vendorId': vendorId,
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0.0,
                  'description': descController.text.trim(),
                  'imageUrl': finalImageUrl,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEditing) {
                  await doc.reference.update(data);
                } else {
                  data['createdAt'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('vendor_menus').add(data);
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Item updated' : 'Item added'), backgroundColor: MPesaTheme.primaryGreen));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
              } finally {
                setStateDialog(() => isSaving = false);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF131A2A),
              title: Text(isEditing ? 'Edit Menu Item' : 'Add Menu Item', style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                        if (pickedFile != null) {
                          setStateDialog(() => selectedImage = File(pickedFile.path));
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MPesaTheme.primaryGreen),
                        ),
                        child: selectedImage != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(selectedImage!, fit: BoxFit.cover))
                            : (existingImageUrl != null && existingImageUrl!.isNotEmpty)
                                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(existingImageUrl!, fit: BoxFit.cover))
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, color: MPesaTheme.primaryGreen, size: 40),
                                      SizedBox(height: 8),
                                      Text('Tap to add photo', style: TextStyle(color: Colors.white54)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Item Name', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Price (KSH)', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Description/Allergens', labelStyle: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: MPesaTheme.primaryGreen),
                  onPressed: isSaving ? null : saveItem,
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Save', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteItem(DocumentSnapshot doc) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131A2A),
        title: const Text('Delete Item?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this menu item?', style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      )
    );
    if (confirm == true) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      appBar: AppBar(
        title: const Text('Menu Management'),
        backgroundColor: MPesaTheme.primaryGreen,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        backgroundColor: MPesaTheme.primaryGreen,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vendor_menus').where('vendorId', isEqualTo: vendorId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: MPesaTheme.primaryGreen));
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Your menu is empty.\nTap + to add items.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 18)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'];
              
              return Card(
                color: const Color(0xFF131A2A),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: imageUrl != null && imageUrl.toString().isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover))
                      : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.fastfood, color: Colors.white54)),
                  title: Text(data['name'] ?? 'Unnamed', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('KSH ${data['price']}\n${data['description'] ?? ''}', style: const TextStyle(color: MPesaTheme.primaryGreen)),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _showAddEditDialog(doc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteItem(doc)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
