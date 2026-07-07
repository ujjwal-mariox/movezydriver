import 'dart:convert';

OtpResponse otpResponseFromJson(String str) => OtpResponse.fromJson(json.decode(str));


class OtpResponse {
  int? code;
  String? message;
  Data? data;

  OtpResponse({this.code, this.message, this.data});

  OtpResponse.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  String? token;
  String? userId;
  String? driverId;
  String? status;
  bool? isNewDriver;

  Data({this.token, this.userId, this.driverId, this.status, this.isNewDriver});

  Data.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    userId = json['userId'];
    driverId = json['driverId'];
    status = json['status'];
    isNewDriver = json['isNewDriver'];
  }

}
