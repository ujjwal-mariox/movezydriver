import 'dart:convert';

LoginResponse loginResponseFromJson(String str) => LoginResponse.fromJson(json.decode(str));


class LoginResponse {
  int? code;
  String? message;
  Data? data;

  LoginResponse({this.code, this.message, this.data});

  LoginResponse.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['code'] = code;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  bool? userRegister;
  String? txnId;

  Data({this.userRegister, this.txnId});

  Data.fromJson(Map<String, dynamic> json) {
    userRegister = json['userRegister'];
    txnId = json['txnId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['userRegister'] = userRegister;
    data['txnId'] = txnId;
    return data;
  }
}
