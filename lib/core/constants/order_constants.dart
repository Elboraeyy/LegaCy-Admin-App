class OrderConstants {
  OrderConstants._();

  static const List<Map<String, String>> statuses = [
    {'key': 'all', 'label': 'All'},
    {'key': 'pending', 'label': 'Pending'},
    {'key': 'confirmed', 'label': 'Confirmed'},
    {'key': 'preparing', 'label': 'Preparing'},
    {'key': 'shipped', 'label': 'Shipped'},
    {'key': 'delivered', 'label': 'Delivered'},
    {'key': 'cancelled', 'label': 'Cancelled'},
  ];

  static const Map<String, List<String>> allowedTransitions = {
    'draft': ['pending', 'cancelled'],
    'payment_pending': ['pending', 'cancelled'],
    'pending': ['confirmed', 'paid', 'cancelled'],
    'paid': ['confirmed', 'cancelled'],
    'confirmed': ['preparing', 'cancelled'],
    'preparing': ['shipped', 'cancelled'],
    'shipped': ['delivered', 'cancelled'],
    'delivered': ['cash_received'],
    'cash_received': [],
    'cancelled': [],
    'refunded': [],
    'payment_failed': [],
  };

  static const List<String> terminalStates = [
    'delivered',
    'cancelled',
    'refunded',
    'payment_failed',
    'cash_received'
  ];
}
