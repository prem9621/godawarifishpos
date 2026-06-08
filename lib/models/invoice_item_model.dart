class InvoiceItemModel {
  final int? id;
  final int? invoiceId;
  final int? itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double price;
  final double amount;

  InvoiceItemModel({
    this.id,
    this.invoiceId,
    this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'Kg',
    required this.price,
    required this.amount,
  });

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return InvoiceItemModel(
      id: map['id'],
      invoiceId: map['invoice_id'],
      itemId: map['item_id'],
      itemName: map['item_name'],
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] ?? 'Kg',
      price: (map['price'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'amount': amount,
    };
  }

  InvoiceItemModel copyWith({
    double? quantity,
    double? price,
    double? amount,
  }) {
    return InvoiceItemModel(
      id: id,
      invoiceId: invoiceId,
      itemId: itemId,
      itemName: itemName,
      quantity: quantity ?? this.quantity,
      unit: unit,
      price: price ?? this.price,
      amount: amount ?? this.amount,
    );
  }
}