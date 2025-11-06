import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../browse.dart' show Item, primaryColor;
import 'user_borrowing.dart';

class BorrowRequestScreen extends StatefulWidget {
  static const String routeName = '/user/borrow-request';
  final Item item;

  const BorrowRequestScreen({super.key, required this.item});

  @override
  State<BorrowRequestScreen> createState() => _BorrowRequestScreenState();
}

class _BorrowRequestScreenState extends State<BorrowRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  final _borrowDate = TextEditingController();
  final _returnDate = TextEditingController();
  final _reason = TextEditingController();

  Future<bool?> _showCancelDialog() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel Rent Request?'),
      content: const Text(
        'Are you sure you want to cancel the Rent Request? All info inputs will be reseted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  Future<void> _selecFromDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
        controller.text = DateFormat('dd/MM/yy').format(picked);
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
          _returnDate.text = DateFormat('dd/MM/yy').format(_fromDate);
        }
      });
    }
  }

  Future<void> _selecToDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    if (_borrowDate.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a borrow date first.')),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
        controller.text = DateFormat('dd/MM/yy').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _borrowDate.dispose();
    _returnDate.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _showCancelDialog();
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _showCancelDialog();
              if (shouldPop == true && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Borrow Request',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(item.imageUrl, height: 180),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField('Borrow date', _borrowDate),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _buildDatePickerField('Return date', _returnDate),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                TextFormField(
                  controller: _reason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a reason' : null,
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Important: Students can only request to borrow one asset per day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),

                const SizedBox(height: 25),

                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (_toDate.isBefore(_fromDate)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Return date cannot be before borrow date.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pushNamed(
                        context,
                        UserBorrowingScreen.routeName,
                        arguments: {
                          'item': item,
                          'borrowDate': _borrowDate.text,
                          'returnDate': _returnDate.text,
                          'reason': _reason.text,
                        },
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Rent',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        suffixIcon: const Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      ),
      onTap: () {
        if (label == 'Return date') {
          _selecToDate(context, controller);
        } else {
          _selecFromDate(context, controller);
        }
      },
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please select a date' : null,
    );
  }
}
