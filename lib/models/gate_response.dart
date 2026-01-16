class GateResponse {
  final String? name;
  final String? status;
  final double? balance;
  final String? error;
  final String? warning;
  final String? className;
  final String? parentName;
  final String? parentPhone;
  final String? img;
  final bool isOffline;
  final String? rfidUid;
  final String? sex; 

  GateResponse({
    this.name,
    this.status,
    this.balance,
    this.error,
    this.warning,
    this.className,
    this.parentName,
    this.parentPhone,
    this.img,
    this.isOffline = false,
    this.rfidUid,
    this.sex,
  });

  factory GateResponse.fromJson(Map<String, dynamic> json) {
    return GateResponse(
      name: json['name'],
      status: json['status'],
      balance: json['balance']?.toDouble(),
      error: json['error'],
      warning: json['warning'],
      className: json['class'], 
      parentName: json['parentName'],
      parentPhone: json['parentPhone'],
      img: json['img'],
      isOffline: json['isOffline'] ?? false,
      rfidUid: json['rfidUid'],
      sex: json['sex'], // 👈 Read it here
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'status': status,
      'balance': balance,
      'error': error,
      'warning': warning,
      'class': className,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'img': img,
      'isOffline': true,
      'rfidUid': rfidUid,
      'sex': sex, // 👈 Save it here
    };
  }
}