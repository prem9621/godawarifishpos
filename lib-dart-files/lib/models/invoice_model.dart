import 'invoice_item_model.dart';

class InvoiceModel {
  final int? id;

  final String invoiceNo;

  final int? customerId;

  final String? customerName;

  final String? customerPhone;

  final List<InvoiceItemModel> items;

  final double subtotal;

  final double discount;

  final double tax;

  final double total;

  final double paid;

  final double balance;

  final double previousBalance;

  final double currentBalance;

  final String paymentMethod;

  final String status;

  final String? notes;

  final DateTime? dueDate;

  final DateTime createdAt;

  final DateTime updatedAt;

  InvoiceModel({
    this.id,
    required this.invoiceNo,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.items = const [],
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.paid = 0,
    this.balance = 0,
    this.previousBalance = 0,
    this.currentBalance = 0,
    this.paymentMethod = 'Cash',
    this.status = 'unpaid',
    this.notes,
    this.dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory InvoiceModel.fromMap(
    Map<String, dynamic> map,
  ) {
    List<InvoiceItemModel> items = [];

    if (map['items'] != null) {
      items = (map['items'] as List)
          .map(
            (i) => InvoiceItemModel.fromMap(i),
          )
          .toList();
    }

    return InvoiceModel(
      id: map['id'],
      invoiceNo: map['invoice_no'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      items: items,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount:
          (map['discount'] as num?)?.toDouble() ?? 0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num).toDouble(),
      paid: (map['paid'] as num?)?.toDouble() ?? 0,
      balance:
          (map['balance'] as num?)?.toDouble() ?? 0,
      previousBalance:
          (map['previous_balance'] as num?)
                  ?.toDouble() ??
              0,
      currentBalance:
          (map['current_balance'] as num?)
                  ?.toDouble() ??
              0,
      paymentMethod:
          map['payment_method'] ?? 'Cash',
      status: map['status'] ?? 'unpaid',
      notes: map['notes'],
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'])
          : null,
      createdAt:
          DateTime.parse(map['created_at']),
      updatedAt:
          DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_no': invoiceNo,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid': paid,
      'balance': balance,
      'previous_balance': previousBalance,
      'current_balance': currentBalance,
      'payment_method': paymentMethod,
      'status': status,
      'notes': notes,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get totalQty {
    return items.fold(
      0,
      (sum, i) => sum + i.quantity.ceil(),
    );
  }

  bool get isPaid => status == 'paid';

  bool get isPartiallyPaid =>
      status == 'partial';

  bool get isOverdue {
    return dueDate != null &&
        dueDate!.isBefore(DateTime.now()) &&
        !isPaid;
  }
}