import 'dart:convert';

class ConnectionProfile {
  final String id;
  final String name;
  final String ip;
  final String shareName;
  final String username;
  final String password;
  final DateTime lastUsed;

  ConnectionProfile({
    required this.id,
    required this.name,
    required this.ip,
    required this.shareName,
    required this.username,
    required this.password,
    DateTime? lastUsed,
  }) : lastUsed = lastUsed ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'shareName': shareName,
      'username': username,
      'password': password,
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory ConnectionProfile.fromMap(Map<String, dynamic> map) {
    return ConnectionProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ip: map['ip'] ?? '',
      shareName: map['shareName'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      lastUsed: DateTime.parse(map['lastUsed']),
    );
  }

  String toJson() => json.encode(toMap());
  factory ConnectionProfile.fromJson(String source) =>
      ConnectionProfile.fromMap(json.decode(source));

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? ip,
    String? shareName,
    String? username,
    String? password,
    DateTime? lastUsed,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      shareName: shareName ?? this.shareName,
      username: username ?? this.username,
      password: password ?? this.password,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}
