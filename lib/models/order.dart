class Order {
  final String id;
  final int? tableId; // Nullable for takeaway/delivery
  final String captainId;
  final String orderType; // dine_in, delivery, takeaway
  final String status; // active, completed, cancelled
  final double totalAmount;
  final DateTime createdAt;

  Order({
    required this.id,
    this.tableId,
    required this.captainId,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      tableId: json['table_id'] as int?,
      captainId: json['captain_id'] as String,
      orderType: json['order_type'] as String,
      status: json['status'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    // We don't send id or created_at for new inserts; Supabase handles them
    if (tableId != null) 'table_id': tableId,
    'captain_id': captainId,
    'order_type': orderType,
    'status': status,
    'total_amount': totalAmount,
  };
}