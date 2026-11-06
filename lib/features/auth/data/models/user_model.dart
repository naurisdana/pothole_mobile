/// Model representasi data Pengguna RoadSafe.
class UserModel {
  final dynamic id;
  final String nama;
  final String email;
  final String peran;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.peran,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      nama: json['nama'] ?? json['name'] ?? '',
      email: json['email'] ?? '',
      peran: json['peran'] ?? json['role'] ?? 'pelapor',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'email': email,
      'peran': peran,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    dynamic id,
    String? nama,
    String? email,
    String? peran,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      peran: peran ?? this.peran,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'UserModel(id: $id, nama: $nama, email: $email, peran: $peran)';
}

/// Model respons ketika berhasil login (`POST /auth/login`).
class AuthResponse {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      user: UserModel.fromJson(userMap),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user': user.toJson(),
    };
  }
}

