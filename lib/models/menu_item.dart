class MenuItem {
  final int id;
  final int categoryId;
  final String name;
  final double price;

  MenuItem({
    required this.id, 
    required this.categoryId, 
    required this.name, 
    required this.price
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'name': name,
    'price': price,
  };
}