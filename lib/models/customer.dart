class Customer {
  int? id;
  String name;
  String phone;

  Customer({this.id, required this.name, required this.phone});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone};
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(id: map['id'], name: map['name'], phone: map['phone']);
  }
}
