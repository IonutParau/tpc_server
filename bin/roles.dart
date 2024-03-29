import 'dart:convert';

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

void sendRoles() {
  for (var ws in webSockets) {
    roles.forEach((id, role) {
      ws.sink.add(jsonEncode({
        "pt": "set-role",
        "id": id,
        "role": role.toString().replaceAll('UserRole.', ''),
      }));
    });
  }
}
