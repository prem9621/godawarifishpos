class FishModel {
  final int? id;
  final String name;
  final String? category;
  final String unit;
  final double price;
  final double stock;
  final double minStock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FishModel({
    this.id,
    required this.name,
    this.category,
    this.unit = 'Kg',
    required this.price,
    this.stock = 0,
    this.minStock = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory FishModel.fromMap(Map<String, dynamic> map) {
    return FishModel(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      unit: map['unit'] ?? 'Kg',
      price: (map['price'] as num).toDouble(),
      stock: (map['stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'price': price,
      'stock': stock,
      'min_stock': minStock,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FishModel copyWith({
    int? id,
    String? name,
    String? category,
    String? unit,
    double? price,
    double? stock,
    double? minStock,
    bool? isActive,
  }) {
    return FishModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  bool get isLowStock => stock <= minStock && minStock > 0;
}