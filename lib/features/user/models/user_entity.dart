import 'package:objectbox/objectbox.dart';
import 'package:ikuyo_finance/features/user/models/user_model.dart';

@Entity()
class UserEntity {
  @Id()
  int id;

  @Unique()
  String supabaseId;

  String name;
  String email;
  String password;
  String role;
  String profilePicture;
  String phoneNumber;
  String bio;

  int? createdAt;
  int? updatedAt;

  UserEntity({
    this.id = 0,
    this.supabaseId = '',
    this.name = '',
    this.email = '',
    this.password = '',
    this.role = '',
    this.profilePicture = '',
    this.phoneNumber = '',
    this.bio = '',
    this.createdAt,
    this.updatedAt,
  });
}

extension UserEntityX on UserEntity {
  UserModel toModel() {
    return UserModel(
      id: supabaseId,
      supabaseId: supabaseId,
      name: name,
      email: email,
      password: password,
      role: UserRole.values.firstWhere((e) => e.value == role),
      profilePicture: profilePicture,
      phoneNumber: phoneNumber,
      bio: bio,
      createdAt: createdAt != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAt!)
          : null,
      updatedAt: updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt!)
          : null,
    );
  }
}

extension UserModelX on UserModel {
  UserEntity toEntity() {
    return UserEntity(
      supabaseId: supabaseId,
      name: name,
      email: email,
      password: password,
      role: role.value,
      profilePicture: profilePicture,
      phoneNumber: phoneNumber,
      bio: bio,
      createdAt: createdAt?.millisecondsSinceEpoch,
      updatedAt: updatedAt?.millisecondsSinceEpoch,
    );
  }
}
