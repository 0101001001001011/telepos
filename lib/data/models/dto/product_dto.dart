library;

class ProductDto {
  const ProductDto({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.price,
    this.costPrice,
    this.quantity,
    this.unit,
    this.vatRate,
    this.isActive = true,
    this.isMarked = false,
    this.createdAt,
    this.modifiedAt,
  });

  final int id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? price;
  final String? costPrice;
  final String? quantity;
  final String? unit;
  final String? vatRate;
  final bool isActive;
  final bool isMarked;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    return ProductDto(
      id: json['id'] as int,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      categoryId: json['categoryId'] as int?,
      price: json['price'] as String?,
      costPrice: json['costPrice'] as String?,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      vatRate: json['vatRate'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isMarked: json['isMarked'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (barcode != null) 'barcode': barcode,
      if (categoryId != null) 'categoryId': categoryId,
      if (price != null) 'price': price,
      if (costPrice != null) 'costPrice': costPrice,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (vatRate != null) 'vatRate': vatRate,
      'isActive': isActive,
      'isMarked': isMarked,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class ProductPriceDto {
  const ProductPriceDto({
    required this.productId,
    required this.priceTypeId,
    required this.price,
    this.minPrice,
    this.modifiedAt,
  });

  final int productId;
  final int priceTypeId;
  final String price;
  final String? minPrice;
  final DateTime? modifiedAt;

  factory ProductPriceDto.fromJson(Map<String, dynamic> json) {
    return ProductPriceDto(
      productId: json['productId'] as int,
      priceTypeId: json['priceTypeId'] as int,
      price: json['price'] as String,
      minPrice: json['minPrice'] as String?,
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'priceTypeId': priceTypeId,
      'price': price,
      if (minPrice != null) 'minPrice': minPrice,
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
    };
  }
}

class ProductAliasDto {
  const ProductAliasDto({
    required this.id,
    required this.productId,
    required this.barcode,
    this.coefficient,
  });

  final int id;
  final int productId;
  final String barcode;
  final String? coefficient;

  factory ProductAliasDto.fromJson(Map<String, dynamic> json) {
    return ProductAliasDto(
      id: json['id'] as int,
      productId: json['productId'] as int,
      barcode: json['barcode'] as String,
      coefficient: json['coefficient'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'barcode': barcode,
      if (coefficient != null) 'coefficient': coefficient,
    };
  }
}

class ProductPackageDto {
  const ProductPackageDto({
    required this.id,
    required this.productId,
    required this.name,
    required this.coefficient,
    this.barcode,
  });

  final int id;
  final int productId;
  final String name;
  final String coefficient;
  final String? barcode;

  factory ProductPackageDto.fromJson(Map<String, dynamic> json) {
    return ProductPackageDto(
      id: json['id'] as int,
      productId: json['productId'] as int,
      name: json['name'] as String,
      coefficient: json['coefficient'] as String,
      barcode: json['barcode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'coefficient': coefficient,
      if (barcode != null) 'barcode': barcode,
    };
  }
}

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    this.parentId,
    this.sortOrder,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int? parentId;
  final int? sortOrder;
  final bool isActive;

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: json['parentId'] as int?,
      sortOrder: json['sortOrder'] as int?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (parentId != null) 'parentId': parentId,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}

class CategoryRestrictionDto {
  const CategoryRestrictionDto({
    required this.categoryId,
    required this.userId,
    this.canSell = true,
    this.canRefund = true,
    this.canDiscount = true,
  });

  final int categoryId;
  final int userId;
  final bool canSell;
  final bool canRefund;
  final bool canDiscount;

  factory CategoryRestrictionDto.fromJson(Map<String, dynamic> json) {
    return CategoryRestrictionDto(
      categoryId: json['categoryId'] as int,
      userId: json['userId'] as int,
      canSell: json['canSell'] as bool? ?? true,
      canRefund: json['canRefund'] as bool? ?? true,
      canDiscount: json['canDiscount'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'userId': userId,
      'canSell': canSell,
      'canRefund': canRefund,
      'canDiscount': canDiscount,
    };
  }
}
