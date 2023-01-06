import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:lua_vm_bindings/lua_vm_bindings.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'command.dart';
import 'grid.dart';
import 'packets.dart';
import 'roles.dart';
import 'plugins/plugins.dart';

final v = "Release Beta 5";

// API docs
/*

[Grid Management]
> place <x> <y> <id> <rot> <data> <brushSize> - Places cell
> bg <x> <y> <bg> <brushSize> - Sets background
> wrap - Toggles wrap mode
> setinit <code> - Sets initial state on the server
> toggle-invis <x> <y>

[Logic Management]
> edtype <type> - Is the editor type wanted by the server
> token <token JSON> - Server only, is how server knows of Client's ID and version.

[Hover Management]
> new-hover <uuid> <x> <y> <id> <rot> - Creates new hover
> set-hover <uuid> <x> <y> - Sets the new hover position
> drop-hover <uuid> - Removes the hover

[Cursor Management]
> set-cursor <uuid> <x> <y> <selection> <rotation> <texture> <data> - Sets cursor state
> remove-cursor <uuid> - Removes the cursor (client only)

[User Management]
> kick <uuid> - Kicks the user
> set-role <uuid> <role> - Sets a user's role to another user
> del-role <uuid> - Locally deletes a role, for memory management
*/

var whitelist = <String>[];
var blacklist = <String>[];

enum ServerType {
  sandbox,
  level,
}

var type = ServerType.sandbox;
var uuidBl = false;

late ArgResults config;

void getConfig(List<String> arguments) {
  final args = ArgParser();
  args.addOption('ip', defaultsTo: 'local');
  args.addOption('port', defaultsTo: '8080');
  args.addOption('versions', defaultsTo: '');
  args.addOption('whitelist', defaultsTo: '');
  args.addOption('blacklist', defaultsTo: '');
  args.addOption('banned_packets', defaultsTo: '');
  args.addOption('wait_time', defaultsTo: '1000');
  args.addFlag('kick-allowed', defaultsTo: true, negatable: true);
  args.addFlag('silent', negatable: false);
  args.addFlag('block_uuid', negatable: false);
  args.addFlag('log', negatable: false);
  args.addFlag('packetpass', negatable: true, defaultsTo: true);

  args.addOption('type', defaultsTo: 'false');
  args.addOption('width', defaultsTo: 'false');
  args.addOption('height', defaultsTo: 'false');

  config = args.parse(arguments);
}

late String ip;
late int port;

// Main function
void main(List<String> arguments) async {
  getConfig(arguments);

  if (config['banned_packets'] != "") {
    bannedPackets.addAll(config['banned_packets'].split(':'));
  }

  final vf = File('versions.txt');
  if (vf.existsSync()) {
    if (!config['silent']) print('Reading allowed versions...');
    versions = vf.readAsLinesSync();
  }

  final whitelistFile = File('whitelist.txt');
  if (whitelistFile.existsSync()) {
    if (!config['silent']) print('Reading allowed IDs...');
    whitelist = whitelistFile.readAsLinesSync();
  }

  final blacklistFile = File('blacklist.txt');
  if (blacklistFile.existsSync()) {
    if (!config['silent']) print('Reading banned IDs...');
    blacklist = blacklistFile.readAsLinesSync();
  }

  final aV = config['versions'].split(':') as List<String>;
  if (aV.isNotEmpty && (config['versions'] != "")) versions.addAll(aV);

  fixVersions();

  final aWL = config['whitelist'].split(':') as List<String>;
  if ((aWL.isNotEmpty) && (config['whitelist'] != "")) versions.addAll(aWL);
  final aBL = config['blacklist'].split(':') as List<String>;
  if (aBL.isNotEmpty) {
    versions.addAll(aBL);
    if (blacklist.contains("@uuid")) {
      uuidBl = true;
    }
  }

  var serverType = config['type'];
  var width = config['width'];
  var height = config['height'];

  if (!config['silent']) {
    print("Welcome to The Puzzle Cell Server Handling System");
  }
  if (!config['silent']) print("Server version: $v");

  if (serverType == "false") {
    print("Please input server type (sandbox [1]/ level [2])");
    stdout.write("Server Type > ");
    serverType = stdin.readLineSync();
  }

  if (serverType != "sandbox" && serverType != "level" && serverType != "1" && serverType != "2") {
    print("Invalid server type");
    return;
  }

  if (serverType == "level" || serverType == "2") type = ServerType.level;

  if (serverType == "sandbox" || serverType == "1") {
    type = ServerType.sandbox;

    if (width == "false") {
      print("Please input grid width");
      stdout.write("Width > ");
      width = stdin.readLineSync()!;
    }

    if (height == "false") {
      print("Please input grid height");
      stdout.write("Height > ");
      height = stdin.readLineSync()!;
    }

    makeGrid(int.parse(width), int.parse(height));
  } else {
    print("Please input level code (P2, P3, P4 or P5 only)");
    stdout.write("Level code > ");
    final code = stdin.readLineSync()!;

    loadStr(code);
  }

  var ip = await parseIP(config['ip']!); // Parse IP

  var port = int.parse(config['port']); // Parse port

  if (arguments.isEmpty) {
    print("[ IP & Port Config ]");
    print(
      "Since there were no arguments passed in, the server has detected that you ran the executable by itself.",
    );
    print(
      "To avoid a bad experience, the server is now prompting you to choose the IP and port",
    );
    print("Options:");
    print(
      "local - This puts it on 127.0.0.1, which is the local host IP. If the ip is local, only your computer can connect to it!",
    );
    print(
      "zero - This puts it on 0.0.0.0, meaning any user connected to your WiFi or Ethernet will be able to join. Also, any person with your IP address can also connect, making this ideal for hosting a server for everyone to join",
    );
    stdout.write("IP > ");
    ip = await parseIP(stdin.readLineSync()!);

    print("Now, on to the port. The port must be a 4-digit number.");
    print(
      "If you don't input a valid number, it will use the default port 8080",
    );
    print(
      "Due to many other types of programs using 8080, since the port has to be different from all other apps using the network, we recommend using something other than the default. You can choose something random, like 5283",
    );

    stdout.write('Port > ');

    port = int.tryParse(stdin.readLineSync()!) ?? 8080;
  }

  final server = await createServer(ip, port);

  if (config['silent']) {
    print('Server should be online');
  } else {
    if (arguments.isNotEmpty) {
      if (ip == "local" || ip == "127.0.0.1") {
        print(
          "You have ran this server on the localhost IP address constant (127.0.0.1 [localhost])",
        );
        print(
          "This means only you can connect to the server, as the localhost IP address only allows the computer it is hosted on to access it",
        );
      } else if (ip == 'zero' || ip == '0.0.0.0') {
        print("You have ran this server on IP 0.0.0.0");
        print(
          "This means only people connected through an ethernet wire can connect to it",
        );
      } else if (ip == 'self') {
        print(
          "WARNING: In 7 seconds it will say at what IP the server is hosted. You have no configured it to be local or zero, meaning it will display your actual IP",
        );
        await Future.delayed(Duration(seconds: 7));
      }
    }
    print(
      'Server should be online, at ws://${server.address.address}:${server.port}/',
    );
  }

  print("Loading plugins...");
  LuaState.loadLibLua(windows: 'dlls/lua54.dll', linux: 'dlls/liblua54.so', macos: 'dlls/liblua52.dylib');
  pluginLoader.getPluginDirs().forEach(pluginLoader.addPlugin);
  for (var plugin in pluginLoader.luaPlugins) {
    plugin.prepare();
    plugin.load();
  }

  Future.delayed(Duration(milliseconds: 500)).then(
    (v) => setupCommandIso(),
  ); // Commands

  // Timer.periodic(Duration(seconds: 1), (timer) {
  //   stdout.write('> ');
  //   final msg = stdin.readLineSync()!.split(' ');

  //   processCommand(msg.first, msg.sublist(1));
  // });
}

void fixVersions() {
  for (var i = 0; i < versions.length; i++) {
    versions[i] = fixVersion(versions[i]);
  }

  while (versions.contains('')) {
    versions.remove('');
  }
}

String fixVersion(String v) {
  while (v.endsWith(".0")) {
    v = v.substring(
      0,
      v.length - 2,
    ); // No more .0
  }

  return v;
}

var versions = <String>[];

final List<WebSocketChannel> webSockets = [];

String? gridCache;

class CellHover {
  double x;
  double y;
  String id;
  int rot;
  Map<String, dynamic> data;

  CellHover(this.x, this.y, this.id, this.rot, this.data);
}

final Map<String, CellHover> hovers = {};

final List<String> bannedPackets = [
  "edtype",
  "remove-cursor",
];

class ClientCursor {
  double x, y;
  String selection, texture;
  int rotation;
  Map<String, dynamic> data;
  WebSocketChannel author;

  ClientCursor(this.x, this.y, this.selection, this.rotation, this.texture, this.data, this.author);

  String toPacket(String id) {
    return jsonEncode({
      "id": id,
      "x": x,
      "y": y,
      "selection": selection,
      "rot": rotation,
      "texture": texture,
      "data": data,
    });
  }
}

final Map<String, ClientCursor> cursors = {};

final Map<WebSocketChannel, String> clientIDs = {};
final Set<String> clientIDList = {};
final pluginLoader = PluginLoader();

void removeWebsocket(WebSocketChannel ws) {
  if (!webSockets.contains(ws)) return;
  final id = clientIDs[ws];
  if (id != null) {
    for (var plugin in pluginLoader.luaPlugins) {
      plugin.onDisconnect(id);
    }
  }
  if (!config['silent']) print('User left');
  ws.sink.close();
  webSockets.remove(ws);

  versionMap.remove(ws);
  String? cursorID = clientIDs[ws];
  if (cursorID == null) return;
  clientIDList.remove(cursorID);
  if (!config['silent']) print('User ID: $cursorID');
  cursors.remove(cursorID);
  for (var ws in webSockets) {
    ws.sink.add('del-role $cursorID');
    ws.sink.add('remove-cursor $cursorID');
  }
}

Map<WebSocketChannel, String> versionMap = {};

String? latestIP = "";
final ipMap = <WebSocketChannel, String>{};
final bannedIps = <String>{};

Future<HttpServer> createServer(String ip, int port) async {
  final ws = webSocketHandler(
    (WebSocketChannel ws) {
      webSockets.add(ws);
      if (latestIP != null) {
        ipMap[ws] = sha256.convert(utf8.encode(latestIP!)).toString();
        latestIP = null;
      }
      ws.stream.listen(
        (data) {
          if (data is String) {
            final d = data.split('\n');
            for (var dt in d) {
              execPacket(dt, ws);
            }
          }
        },
        onDone: () => removeWebsocket(ws),
        onError: (e) => removeWebsocket(ws),
      );

      // Send grid
      gridCache ??= SavingFormat.encodeGrid(); // Speeeeeed
      ws.sink.add(jsonEncode({
        "pt": "grid",
        "code": gridCache,
      })); // Send to client

      if (type == ServerType.level) {
        ws.sink.add(jsonEncode({"pt": "edtype", "et": "puzzle"})); // Send special editor type

        hovers.forEach(
          (uuid, hover) {
            ws.sink.add(
              jsonEncode({
                "pt": "new-hover",
                "uuid": uuid,
                "x": hover.x,
                "y": hover.y,
                "id": hover.id,
                "rot": hover.rot,
                "data": hover.data,
              }),
            );
          },
        ); // Send hovering cells
      }

      cursors.forEach(
        (id, cursor) {
          ws.sink.add(cursor.toPacket(id));
        },
      ); // Send cursors

      roles.forEach((id, role) {
        ws.sink.add(jsonEncode({
          "pt": "set-role",
          "id": id,
          "role": role.toString().replaceAll('UserRole.', ''),
        }));
      });

      fixVersions();
      if (versions.isNotEmpty) {
        Future.delayed(Duration(milliseconds: int.parse(config['wait_time']))).then(
          (v) {
            if (!versions.contains(versionMap[ws])) {
              print("User kicked for no connection token sent");
              kickWS(ws); // Remove for invalid version
            } // Version check

            if (!cursors.containsKey(clientIDs[ws] ?? "")) {
              print("User kicked for no cursor packet sent");
              kickWS(ws); // Remove for invalid version
            } // Version check
          },
        );
      } // Version checking
    },
  );

  final server = await sio.serve(serverThing(ws), ip, port); // Create server

  return server; // Return server
}

Future<String> parseIP(String ip) async {
  if (ip == 'local' || ip == 'localhost') {
    return '127.0.0.1';
  }

  if (ip == 'zero') {
    return '0.0.0.0';
  }

  if (ip == 'self') {
    return await Ipify.ipv4();
  }

  return ip;
}

void kickWS(WebSocketChannel ws) {
  final kickAllowed = config['kick-allowed'];

  if (kickAllowed) {
    final id = clientIDs[ws];
    if (id != null) {
      for (var plugin in pluginLoader.luaPlugins) {
        plugin.onDisconnect(id);
      }
    }
    removeWebsocket(ws);
    if (!config['silent']) print('A user has been kicked');
  } else {
    if (!config['silent']) print('A user wasnt kicked');
  }
}

final validIDAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-";

bool isValidID(String id) {
  final chars = id.split('');

  for (var char in chars) {
    if (!validIDAlphabet.contains(char)) {
      return false;
    }
  }

  return true;
}

FutureOr<Response> Function(Request rq) serverThing(FutureOr<Response> Function(Request) wsHandler) {
  return (Request rq) {
    final ip = rq.headers['X-Forwarded-For'];

    // IP would be null if this was from the host computer
    if (ip != null) {
      final ipHash = sha256.convert(utf8.encode(ip)).toString();

      if (bannedIps.contains(ipHash)) {
        return Future<Response>.value(Response.forbidden("IP has been banned"));
      }
    }

    latestIP = ip;

    if (rq.method != "GET") {
      for (var plugin in pluginLoader.luaPlugins) {
        final res = plugin.onPing(rq.headers, ip);
        if (res != null) return Future<Response>.value(Response.ok(res));
      }
      return Future<Response>.value(Response.ok("Server exists"));
    } else {
      return wsHandler(rq);
    }
  };
}

num getTimeSinceEpoch(String unit) {
  unit = unit.replaceAll(' ', '');
  final date = DateTime.now();

  if (unit == "ms") return date.millisecondsSinceEpoch;
  if (unit == "us" || unit == "μs") return date.microsecondsSinceEpoch;
  if (unit == "ns") return date.microsecondsSinceEpoch / 1000;
  if (unit == "s") return date.millisecondsSinceEpoch / 1000;
  if (unit == "min") return date.millisecondsSinceEpoch / 1000 / 60;
  if (unit == "h") return date.millisecondsSinceEpoch / 1000 / 60 / 60;
  if (unit == "d") return date.millisecondsSinceEpoch / 1000 / 60 / 60 / 24;

  return 0;
}
