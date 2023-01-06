import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'command.dart';
import 'grid.dart';
import 'roles.dart';
import 'main.dart';

void legacyExecPacket(String data, WebSocketChannel ws) {
  if (!webSockets.contains(ws)) return;

  if (config['log']) {
    print('Packet from ${clientIDs[ws] ?? "Unknown"} > $data');
  }

  final args = data.split(' ');

  final typeBasedPackets = [];

  if (type == ServerType.level) {
    typeBasedPackets.addAll([
      "bg",
      "wrap",
    ]);
  }

  if (bannedPackets.contains(args.first) || typeBasedPackets.contains(args.first)) {
    print('Kicking user for sending banned packet ${args.first}');
    kickWS(ws);
    return;
  }

  final id = clientIDs[ws];
  for (var plugin in pluginLoader.luaPlugins) {
    plugin.onPacket(id, data);
  }

  switch (args.first) {
    case "place":
      if (args.length == 6) {
        args.add("0");
      }
      if (args.length != 7) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      var x = int.parse(args[1]);
      var y = int.parse(args[2]);
      if (wrap) {
        x = (x + grid.length) % grid.length;
        y = (y + grid.first.length) % grid.first.length;
      }
      var size = int.parse(args[6]);
      for (var cx = x - size; cx <= x + size; cx++) {
        for (var cy = y - size; cy <= y + size; cy++) {
          if (!insideGrid(cx, cy)) continue;

          grid[cx][cy].id = args[3];
          grid[cx][cy].rot = int.parse(args[4]);
          grid[cx][cy].data = parseCellDataStr(args[5]);
          grid[cx][cy].invisible = false;
          grid[cx][cy].tags = {};
          grid[cx][cy].lifespan = 0;
        }
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
      break;
    case "bg":
      if (args.length == 4) {
        args.add("0");
      }
      if (args.length != 5) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      var x = int.parse(args[1]);
      var y = int.parse(args[2]);
      if (wrap) {
        x = (x + grid.length) % grid.length;
        y = (y + grid.first.length) % grid.first.length;
      }
      final size = int.parse(args[4]);

      for (var cx = x - size; cx <= x + size; cx++) {
        for (var cy = y - size; cy <= y + size; cy++) {
          if (!insideGrid(cx, cy)) break;

          grid[cx][cy].bg = args[3];
        }
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
      break;
    case "wrap":
      if (args.length != 1) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      wrap = !wrap;
      for (var ows in webSockets) {
        ows.sink.add(data);
      }
      gridCache = null;
      break;
    case "setinit":
      if (getRole(ws) == UserRole.guest) {
        //ws.sink.add('drop-hover ${args[1]}');
        break;
      }
      if (gridCache != args[1]) {
        loadStr(args[1]);
        for (var ws in webSockets) {
          ws.sink.add(data);
        }
        gridCache = args[1];
      }
      break;
    case "new-hover":
      if (args.length <= 6) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      hovers[args[1]] = CellHover(
        double.parse(args[2]),
        double.parse(args[3]),
        args[4],
        int.parse(
          args[5],
        ),
        {},
      );
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      break;
    case "set-hover":
      if (args.length != 4) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      hovers[args[1]]!.x = double.parse(args[2]);
      hovers[args[1]]!.y = double.parse(args[3]);
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      break;
    case "drop-hover":
      if (args.length != 2) {
        kickWS(ws);
        break;
      }
      if (getRole(ws) == UserRole.guest) {
        break;
      }
      hovers.remove(args[1]);
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      break;
    case "set-cursor":
      if (args.length != 7 && args.length != 8 && args.length != 4) {
        kickWS(ws);
        break;
      }
      if (args[1] != clientIDs[ws]) break;

      if (args.length == 7) {
        args.add(":");
      }
      if (args.length == 4) {
        args.add("empty");
        args.add("0");
        args.add("cursor");
        args.add("0");
      }

      if (cursors[args[1]] == null) {
        cursors[args[1]] = ClientCursor(
          double.parse(args[2]),
          double.parse(args[3]),
          args[4],
          int.parse(args[5]),
          args[6],
          parseCellDataStr(args[7]),
          ws,
        );
        if (!config['silent']) {
          print('New cursor created. Client ID: ${args[1]}');
        }
      } else {
        cursors[args[1]]!.x = double.parse(args[2]);
        cursors[args[1]]!.y = double.parse(args[3]);
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      break;
    case "token":
      if (clientIDs[ws] != null) return;
      final tokenJSON = jsonDecode(args.sublist(1).join(" "));
      final v = tokenJSON["version"];
      if (v is! String) {
        kickWS(ws);
        break;
      }
      final id = tokenJSON["clientID"];
      if (id is! String) {
        kickWS(ws);
        break;
      }

      if (id.length > 500 || !isValidID(id)) {
        kickWS(ws);
        break;
      }

      if (clientIDList.contains(id)) {
        if (!config['silent']) {
          print("A user attempted to connect with duplicate ID");
        }
        kickWS(ws);
        break;
      }
      if (whitelist.isNotEmpty) {
        if (whitelist.contains(id)) {
          if (!config['silent']) {
            print("User with whitelisted ID: $id has joined.");
          }
        } else {
          print("User attempted to join with blocked ID");
          kickWS(ws);
          break;
        }
      }

      if (blacklist.isNotEmpty) {
        if (blacklist.contains(id)) {
          if (!config['silent']) {
            print("User attempted to join with a blocked ID");
          }
          kickWS(ws);
          break;
        }
      }

      if (config['block_uuid'] || uuidBl) {
        if (!config['silent']) {
          print('UUID blocking is enabled, validating ID...');
        }
        if (id.split('-').length == 5) {
          if (!config['silent']) print('Blocked ID $id');
          kickWS(ws);
          break;
        }
      }

      roles[id] = defaultRole;

      sendRoles();

      clientIDList.add(id);

      fixVersions();

      final fv = fixVersion(v);

      if (versions.contains(fv)) {
        versionMap[ws] = fv;
        clientIDs[ws] = id;
        if (!config['silent']) {
          print("A new user has joined. ID: $id. Version: $v");
        }
        for (var plugins in pluginLoader.luaPlugins) {
          plugins.onConnect(id, v);
        }
      } else if (versions.isEmpty) {
        versionMap[ws] = fv;
        clientIDs[ws] = id;
        if (!config['silent']) {
          print("A new user has joined. ID: $id. Version: $v");
        }
        for (var plugins in pluginLoader.luaPlugins) {
          plugins.onConnect(id, v);
        }
      } else if (versions.isNotEmpty) {
        if (!config['silent']) {
          print("A user has joined with incompatible version");
        }
        kickWS(ws);
      } else {
        versionMap[ws] = fv;
        clientIDs[ws] = id;
        if (!config['silent']) {
          print("A new user has joined. ID: $id. Version: $v");
        }
        for (var plugins in pluginLoader.luaPlugins) {
          plugins.onConnect(id, v);
        }
      }
      break;
    case "toggle-invis":
      if (args.length != 3) {
        kickWS(ws);
        break;
      }
      final x = int.parse(args[1]);
      final y = int.parse(args[2]);

      if (insideGrid(x, y)) {
        grid[x][y].invisible = !grid[x][y].invisible;
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      break;
    case "chat":
      final jsonBlob = args.sublist(1).join(" ");
      var shouldKick = false;

      try {
        final payload = jsonDecode(jsonBlob) as Map<String, dynamic>;

        final signed = payload["author"].toString();
        if (signed.toLowerCase() == "server") throw "User attempted to forge message as server";

        final content = payload["content"].toString();

        final id = clientIDs[ws];
        if (id == null) throw "Pending User tried to send message";
        if (!clientIDList.contains(id)) {
          shouldKick;
          return;
        }
        if (id == signed) {
          var filterOut = false;
          for (var plugin in pluginLoader.luaPlugins) {
            if (filterOut) break;
            filterOut = plugin.filterMessage(id, content);
          }
          if (!filterOut) {
            for (var ows in webSockets) {
              ows.sink.add(data);
            }
          }
        } else {
          shouldKick = true;
          throw "User($id) attempted to forge signature of User($signed)";
        }

        if (content.startsWith('/')) {
          final cmdList = content.substring(1).split(' ');

          final cmd = cmdList.first;
          final args = cmdList.sublist(1);

          runChatCmd(id, cmd, args);
        }
      } catch (e) {
        ws.sink.add('chat ${jsonEncode({"author": "Server", "content": e.toString()})}');
        print("A user sent an invalid message and an error was raised: $e");
      }

      if (shouldKick) {
        kickWS(ws);
      }
      break;
    case 'set-role':
      if (args.length != 3) {
        kickWS(ws);
        break;
      }
      final id = args[1];
      if (!clientIDs.containsKey(id)) break;
      final role = getRoleStr(args[2]);
      final userRole = getRole(ws);
      final otherRole = (roles[id] ?? defaultRole);

      if (userRole == UserRole.member || userRole == UserRole.guest) break;

      // Only owner can change admin and owner role
      if (otherRole == UserRole.owner || otherRole == UserRole.admin) {
        if (userRole != UserRole.owner) {
          break;
        }
      }

      // Only owner can promote to owner
      if (role == UserRole.owner && userRole != UserRole.owner) {
        break;
      }

      if (role == null) {
        kickWS(ws);
        break;
      }

      roles[id] = role;

      for (var ws in webSockets) {
        ws.sink.add(data);
      }

      break;
    case 'kick':
      if (args.length != 2) {
        kickWS(ws);
        break;
      }

      final role = getRole(ws);

      if (role != UserRole.admin && role != UserRole.owner) {
        break;
      }

      final id = args[1];
      if (clientIDs.containsKey(id)) break;

      WebSocketChannel? user;
      clientIDs.forEach((iuser, uid) {
        if (id == uid) {
          user = iuser;
        }
      });
      if (user != null) {
        kickWS(user!);
      }

      break;
    default:
      if (config['packetpass']) {
        if (!config['silent']) {
          print(
            'Randomly got invalid packet $data. Sending to other clients.',
          );
        }
        for (var ws in webSockets) {
          ws.sink.add(data);
        }
      }
      break;
  }
}

void execPacket(String data, WebSocketChannel sender) {
  if (!(data.startsWith('{') && data.endsWith('}'))) return legacyExecPacket(data, sender);

  if (!webSockets.contains(sender)) return;

  if (config['log']) {
    print('Packet from ${clientIDs[sender] ?? "Unknown"} > $data');
  }

  try {
    final packet = jsonDecode(data) as Map<String, dynamic>;

    final packetType = packet["pt"].toString();

    // If the user tries to do anything but login without logging in, kick them.
    if (packetType != "token" && clientIDs[sender] == null) {
      kickWS(sender);
      return;
    }

    final role = getRole(sender);

    if (packetType == "place") {
      if (role == UserRole.guest) {
        return;
      }
      final x = (packet["x"] as num).toInt();
      final y = (packet["y"] as num).toInt();
      final id = packet["id"] as String;
      final rot = (packet["rot"] as num).toInt();
      final data = packet["data"] as Map<String, dynamic>;
      final size = (packet["size"] as num).toInt();

      for (var cx = x - size; cx <= x + size; cx++) {
        for (var cy = y - size; cy <= y + size; cy++) {
          final wcx = wrap ? cx % grid.length : cx;
          final wcy = wrap ? cy % grid.first.length : cy;
          if (!insideGrid(wcx, wcy)) continue;
          grid[wcx][wcy].id = id;
          grid[wcx][wcy].rot = rot;
          grid[wcx][wcy].data = data;
          grid[wcx][wcy].invisible = false;
          grid[wcx][wcy].tags = {};
          grid[wcx][wcy].lifespan = 0;
        }
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
    }
    if (packetType == "bg") {
      if (role == UserRole.guest) {
        return;
      }
      final x = (packet["x"] as num).toInt();
      final y = (packet["y"] as num).toInt();
      final size = (packet["size"] as num).toInt();
      final bg = packet["bg"] as String;

      for (var cx = x - size; cx <= x + size; cx++) {
        for (var cy = y - size; cy <= y + size; cy++) {
          final wcx = wrap ? cx % grid.length : cx;
          final wcy = wrap ? cy % grid.first.length : cy;
          if (!insideGrid(wcx, wcy)) continue;
          grid[wcx][wcy].bg = bg;
        }
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
    }
    if (packetType == "wrap") {
      wrap = packet["v"] as bool;
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
    }
    if (packetType == "setinit") {
      if (role == UserRole.guest) return;
      final levelCode = packet["code"] as String;
      if (gridCache == levelCode) return;
      loadStr(levelCode);
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
      gridCache = null;
    }
    if (packetType == "new-hover") {
      if (role == UserRole.guest) return;
      final uuid = packet["uuid"] as String;
      final x = (packet["x"] as num).toDouble();
      final y = (packet["y"] as num).toDouble();
      final id = packet["id"] as String;
      final rot = (packet["rot"] as num).toInt();
      final data = packet["data"] as Map<String, dynamic>;

      hovers[uuid] = CellHover(x, y, id, rot, data);
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "set-hover") {
      if (role == UserRole.guest) return;
      final uuid = packet["uuid"] as String;
      final x = (packet["x"] as num).toDouble();
      final y = (packet["y"] as num).toDouble();

      hovers[uuid]?.x = x;
      hovers[uuid]?.y = y;
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "drop-hover") {
      if (role == UserRole.guest) return;
      final uuid = packet["uuid"] as String;

      hovers.remove(uuid);
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "set-cursor") {
      final id = packet["id"] as String;
      if (id != clientIDs[sender]) return;

      final x = (packet["x"] as num).toDouble();
      final y = (packet["y"] as num).toDouble();
      final selection = packet["selection"] as String;
      final texture = packet["texture"] as String;
      final rot = (packet["rot"] as num).toInt();
      final data = packet["data"] as Map<String, dynamic>;

      if (cursors[id] == null) {
        cursors[id] = ClientCursor(x, y, selection, rot, texture, data, sender);
      } else {
        if (cursors[id]?.author != sender) return;
        cursors[id]?.x = x;
        cursors[id]?.y = y;
        cursors[id]?.selection = selection;
        cursors[id]?.texture = texture;
        cursors[id]?.rotation = rot;
        cursors[id]?.data = data;
      }

      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "token") {
      final id = packet["clientID"] as String;
      final v = packet["version"] as String;

      if (id.length > 500 || !isValidID(id)) {
        kickWS(sender);
        return;
      }

      if (clientIDList.contains(id)) {
        if (!config["silent"]) {
          print("A user attempted to connect with duplicate ID");
        }
        kickWS(sender);
        return;
      }

      if (whitelist.isNotEmpty) {
        if (whitelist.contains(id)) {
          if (!config["silent"]) {
            print("User with whitelisted ID: $id has joined");
          }
        } else {
          print("User attempted to join with blocked ID");
          kickWS(sender);
          return;
        }
      }

      if (blacklist.isNotEmpty) {
        if (blacklist.contains(id)) {
          if (!config['silent']) {
            print("User attempted to join with blocked ID");
          }
          kickWS(sender);
          return;
        }
      }

      if (config["block_uuid"] || uuidBl) {
        if (!config["silent"]) {
          print("UUID blocking is enabled, validating ID...");
        }
        if (id.split('-').length == 5) {
          if (!config["silent"]) print("Blocked ID: $id");
          kickWS(sender);
          return;
        }
      }
      fixVersions();
      final fv = fixVersion(v);

      if (versions.contains(fv) || versions.isEmpty) {
        versionMap[sender] = fv;
        clientIDs[sender] = id;
        roles[id] = defaultRole;
        sendRoles();
        clientIDList.add(id);
        if (!config["silent"]) {
          print("A new user has joined. ID: $id. Version $v");
        }
        for (var plugins in pluginLoader.luaPlugins) {
          plugins.onConnect(id, fv);
        }
      } else if (versions.isNotEmpty) {
        if (!config["silent"]) {
          print("A user has joined with incompatible version");
        }
        kickWS(sender);
        return;
      }
    }
    if (packetType == "invis") {
      final x = (packet["x"] as num).toInt();
      final y = (packet["y"] as num).toInt();
      final v = packet["v"] as bool;

      final cx = wrap ? x % grid.length : x;
      final cy = wrap ? y % grid.first.length : y;

      if (insideGrid(cx, cy)) {
        grid[cx][cy].invisible = v;
      }
      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "chat") {
      var shouldKick = false;

      try {
        final signed = packet["author"].toString();
        if (signed.toLowerCase() == "server") throw "User attempted to forge a message as server";

        final content = packet["content"].toString();

        final id = clientIDs[sender];
        if (id == null) throw "Pending User tried to send message";

        if (!clientIDList.contains(id)) {
          shouldKick = true;
          throw "User with foreign ID tried to send message";
        }

        if (id == signed) {
          var filterOut = false;
          for (var plugin in pluginLoader.luaPlugins) {
            if (filterOut) break;
            filterOut = plugin.filterMessage(id, content);
          }
          if (!filterOut) {
            for (var ws in webSockets) {
              ws.sink.add(data);
            }
          }
        } else {
          shouldKick = true;
          throw "User($id) attempted to forge signature of User($signed)";
        }

        if (content.startsWith('/')) {
          final cmdlist = content.substring(1).split(' ');

          final cmd = cmdlist.first;
          final args = cmdlist.sublist(1);

          runChatCmd(id, cmd, args);
        }
      } catch (e) {
        sender.sink.add(jsonEncode({
          "pt": "chat",
          "author": "Server",
          "content": e.toString(),
        }));
        print("A user sent an invalid message and an error was raised: $e");
      }

      if (shouldKick) {
        kickWS(sender);
      }
    }
    if (packetType == "set-role") {
      final id = packet["id"];
      if (!clientIDList.contains(id)) return;
      final userRole = getRole(sender);
      final role = getRoleStr(packet["role"]);

      final otherRole = roles[id] ?? defaultRole;

      if (userRole == UserRole.member || userRole == UserRole.guest) return;

      // Only owner can change admin and owner role
      if (otherRole == UserRole.owner || otherRole == UserRole.admin) {
        if (userRole != UserRole.owner) {
          return;
        }
      }

      // Only owner can promote to owner
      if (role == UserRole.owner && userRole != UserRole.owner) {
        return;
      }

      if (role == null) {
        kickWS(sender);
        return;
      }

      roles[id] = role;

      for (var ws in webSockets) {
        ws.sink.add(data);
      }
    }
    if (packetType == "kick") {
      final id = packet["id"];
      if (role != UserRole.admin && role != UserRole.owner) {
        return;
      }

      if (!clientIDList.contains(id)) return;

      WebSocketChannel? user;

      clientIDs.forEach((iuser, uid) {
        if (id == uid) {
          user = iuser;
        }
      });

      if (user != null) {
        kickWS(user!);
      }
    }
  } catch (e) {
    print("[ Error happened while executing a packet ]");
    print("Error: $e");
    print("Packet: $data");
  }
}
