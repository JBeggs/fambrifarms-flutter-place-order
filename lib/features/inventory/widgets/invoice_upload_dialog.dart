import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/api_service.dart';
import '../../../models/supplier.dart';

class InvoiceUploadDialog extends ConsumerStatefulWidget {
  const InvoiceUploadDialog({super.key});

  @override
  ConsumerState<InvoiceUploadDialog> createState() => _InvoiceUploadDialogState();
}

class _InvoiceUploadDialogState extends ConsumerState<InvoiceUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  Supplier? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  final List<XFile> _selectedImages = [];
  bool _isUploading = false;
  List<Supplier> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.getSuppliers();
      
      if (mounted) {
        setState(() {
          _suppliers = response
              .map((s) => Supplier.fromJson(s))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suppliers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _uploadInvoices() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier and at least one invoice photo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        
        await apiService.uploadInvoicePhoto(
          supplierId: _selectedSupplier!.id,
          invoiceDate: _selectedDate,
          photoFile: File(image.path),
          notes: _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${_selectedImages.length} invoice(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading invoices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.upload, color: Color(0xFF2D5016)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Upload Invoice Photos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Supplier Selection
                      const Text(
                        'Supplier *',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Supplier>(
                        initialValue: _selectedSupplier,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Select supplier',
                        ),
                        items: _suppliers.map((supplier) {
                          return DropdownMenuItem(
                            value: supplier,
                            child: Text(supplier.name),
                          );
                        }).toList(),
                        onChanged: (supplier) {
                          setState(() {
                            _selectedSupplier = supplier;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a supplier';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Invoice Date
                      const Text(
                        'Invoice Date *',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Notes
                      const Text(
                        'Notes (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Add any notes about this delivery...',
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Photo Selection
                      Row(
                        children: [
                          const Text(
                            'Invoice Photos *',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedImages.length} selected',
                            style: TextStyle(
                              color: _selectedImages.isEmpty ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Photo Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _takePicture,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('From Gallery'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Selected Images Grid
                      if (_selectedImages.isNotEmpty) ...[
                        const Text(
                          'Selected Photos:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            final image = _selectedImages[index];
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(image.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              const Divider(),
              Row(
                children: [
                  TextButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadInvoices,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Invoices'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5016),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
