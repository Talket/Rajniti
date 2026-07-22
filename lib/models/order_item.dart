class OrderItem {
  final int id;
  final String orderId;
  final int menuItemId;
  final int quantity;
  final double historicalPrice;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.historicalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      orderId: json['order_id'] as String,
      menuItemId: json['menu_item_id'] as int,
      quantity: json['quantity'] as int,
      historicalPrice: (json['historical_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id': orderId,
    'menu_item_id': menuItemId,
    'quantity': quantity,
    'historical_price': historicalPrice,
  };
}