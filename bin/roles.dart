import 'package:web_socket_channel/web_socket_channel.dart';

import 'main.dart';

enum UserRole {
  owner,
  admin,
  member,
  guest,
}

Map<String, UserRole> roles = {};

UserRole defaultRole = UserRole.member;

UserRole getRole(WebSocketChannel ws) => roles[clientIDs[ws] ?? "Unknown"] ?? defaultRole;
