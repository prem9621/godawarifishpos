class CustomerModel {
  static const String typeCustomer = 'customer';
  static const String typeSupplier = 'supplier';

  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final double balance;
  /// [typeCustomer] = they owe you (receivable when balance > 0). [typeSupplier] = you owe them (payable when balance > 0).
  final String partyType;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.gstNumber,
    this.balance = 0,
    this.partyType = typeCustomer,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isSupplier => partyType == typeSupplier;
  bool get isCustomer => !isSupplier;

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    DateTime safeDt(String key) {
      final raw = map[key] as String?;
      if (raw == null || raw.isEmpty) return DateTime.now();
      return DateTime.tryParse(raw) ?? DateTime.now();
    }

    final rawName = map['name'];
    final name = rawName is String && rawName.trim().isNotEmpty ? rawName.trim() : 'Unknown';

    return CustomerModel(
      id: map['id'] as int?,
      name: name,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      gstNumber: map['gst_number'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      partyType: (map['party_type'] as String?)?.isNotEmpty == true ? map['party_type'] as String : typeCustomer,
      createdAt: safeDt('created_at'),
      updatedAt: safeDt('updated_at'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'gst_number': gstNumber,
      'balance': balance,
      'party_type': partyType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? gstNumber,
    double? balance,
    String? partyType,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      balance: balance ?? this.balance,
      partyType: partyType ?? this.partyType,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
