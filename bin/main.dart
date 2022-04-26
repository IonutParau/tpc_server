import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'grid.dart';

final v = "2.0.0.2";

// API docs
/*

[Grid Management]
- place <x> <y> <id> <rot> - Places cell
- bg <x> <y> <bg> - Sets background
- wrap - Toggles wrap mode
- setinit - Sets initial state on the server

[Logic Management]
- edtype <type> - Is the editor type wanted by the server
- version <version> - Sends the version to the server for versionb validation (server only)

[Hover Management]
- new-hover <uuid> <x> <y> <id> <rot> - Creates new hover
- set-hover <uuid> <x> <y> - Sets the new hover position
- drop-hover <uuid> - Removes the hover

[Cursor Management]
- set-cursor <uuid> <x> <y> - Sets cursor state
- remove-cursor <uuid> - Removes the cursor (client only)

*/

var whitelist = <String>[];

enum ServerType {
  sandbox,
  level,
}

var type = ServerType.sandbox;

late ArgResults config;

void main(List<String> arguments) async {
  final vf = File('versions.txt');
  if (vf.existsSync()) {
    print('Reading allowed versions...');
    versions = vf.readAsLinesSync();
  }

  final whitelistFile = File('whitelist.txt');
  if (whitelistFile.existsSync()) {
    print('Reading allowed IDs...');
    whitelist = whitelistFile.readAsLinesSync();
  }

  final args = ArgParser();
  args.addOption('ip', defaultsTo: 'local');
  args.addOption('port', defaultsTo: '8080');
  args.addOption('kick-allowed', defaultsTo: 'true');
  args.addFlag('silent', negatable: false);
  args.addFlag('block_uuid', negatable: false);
  args.addFlag('log', negatable: false);

  args.addOption('type', defaultsTo: 'false');
  args.addOption('width', defaultsTo: 'false');
  args.addOption('height', defaultsTo: 'false');

  config = args.parse(arguments);

  var serverType = config['type'];
  var width = config['width'];
  var height = config['height'];

  print("Welcome to The Puzzle Cell Server Handling System");
  print("Server version: $v");

  if (serverType == "false") {
    print("Please input server type (sandbox / level)");
    serverType = stdin.readLineSync();
  }

  if (serverType != "sandbox" && serverType != "level") {
    print("Invalid server type");
    return;
  }

  if (serverType == "level") type = ServerType.level;

  if (serverType == "sandbox") {
    type = ServerType.sandbox;

    if (width == "false") {
      print("Please input grid width");
      width = stdin.readLineSync()!;
    }

    if (height == "false") {
      print("Please input grid height");
      height = stdin.readLineSync()!;
    }

    makeGrid(int.parse(width), int.parse(height));
  } else {
    print("Please input level code (P2 only)");
    final code = stdin.readLineSync()!;

    if (code.startsWith('P2;')) {
      P2.decodeGrid(code);
    } else {
      print("Error: Not a P2 code");
      return;
    }
  }

  final server = await createServer();

  if (config['silent']) {
    print('Server should be online');
  } else {
    if (config['ip'] == "local" || config['ip'] == "127.0.0.1") {
      print(
        "You have ran this server on the localhost IP address constant (127.0.0.1)",
      );
      print(
        "This means only you can connect to the server, as the localhost IP address only allows the computer it is hosted on to access it",
      );
    } else if (config['ip'] == 'zero' || config['ip'] == '0.0.0.0') {
      print("You have ran this server on IP 0.0.0.0");
      print(
        "This means only people connected through an ethernet wire can connect to it",
      );
    } else if (config['ip'] == 'self') {
      print(
        "WARNING: In 5 seconds it will say at what IP the server is hosted. You have no configured it to be local or zero, meaning it will display your actual IP",
      );
      await Future.delayed(Duration(seconds: 5));
    }
    print(
      'Server should be online, at ws://${server.address.address}:${server.port}/',
    );
  }

  // Timer.periodic(Duration(seconds: 1), (timer) {
  //   stdout.write('> ');
  //   final msg = stdin.readLineSync()!.split(' ');

  //   processCommand(msg.first, msg.sublist(1));
  // });
}

var versions = <String>[];

final List<WebSocketChannel> webSockets = [];

String? gridCache;

class CellHover {
  double x;
  double y;
  String id;
  int rot;

  CellHover(this.x, this.y, this.id, this.rot);
}

final Map<String, CellHover> hovers = {};

class ClientCursor {
  double x, y;
  WebSocketChannel author;

  ClientCursor(this.x, this.y, this.author);
}

final Map<String, ClientCursor> cursors = {};

final Map<WebSocketChannel, String> clientIDs = {};
final Set<String> clientIDList = {};

void removeWebsocket(WebSocketChannel ws) {
  if (!webSockets.contains(ws)) return;
  print('User left');
  ws.sink.close();
  webSockets.remove(ws);

  versionMap.remove(ws);
  String? cursorID = clientIDs[ws];
  if (cursorID == null) return;
  clientIDList.remove(cursorID);
  print('User ID: $cursorID');
  cursors.remove(cursorID);
  for (var ws in webSockets) {
    ws.sink.add('remove-cursor $cursorID');
  }
}

Map<WebSocketChannel, String> versionMap = {};

Future<HttpServer> createServer() async {
  final ws = webSocketHandler(
    (WebSocketChannel ws) {
      webSockets.add(ws);
      ws.stream.listen(
        (data) {
          if (data is String) {
            if (config['log']) {
              print('Packet from ${clientIDs[ws] ?? "Unknown"} > $data');
            }

            final args = data.split(' ');

            switch (args.first) {
              case "place":
                var x = int.parse(args[1]);
                var y = int.parse(args[2]);
                if (wrap) {
                  x = (x + grid.length) % grid.length;
                  y = (y + grid.first.length) % grid.first.length;
                }
                grid[x][y].id = args[3];
                grid[x][y].rot = int.parse(args[4]);
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                gridCache = null;
                break;
              case "bg":
                var x = int.parse(args[1]);
                var y = int.parse(args[2]);
                if (wrap) {
                  x = (x + grid.length) % grid.length;
                  y = (y + grid.first.length) % grid.first.length;
                }
                grid[x][y].bg = args[3];
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                gridCache = null;
                break;
              case "wrap":
                wrap = !wrap;
                for (var ows in webSockets) {
                  if (ows != ws) {
                    ows.sink.add(data);
                  }
                }
                gridCache = null;
                break;
              case "setinit":
                P2.decodeGrid(args[1]);
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                gridCache = args[1];
                break;
              case "new-hover":
                hovers[args[1]] = CellHover(
                  double.parse(args[2]),
                  double.parse(args[3]),
                  args[4],
                  int.parse(
                    args[5],
                  ),
                );
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                break;
              case "set-hover":
                hovers[args[1]]!.x = double.parse(args[2]);
                hovers[args[1]]!.y = double.parse(args[3]);
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                break;
              case "drop-hover":
                hovers.remove(args[1]);
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                break;
              case "set-cursor":
                if (args[1] != clientIDs[ws]) break;
                if (cursors[args[1]] == null) {
                  cursors[args[1]] = ClientCursor(
                    double.parse(args[2]),
                    double.parse(args[3]),
                    ws,
                  );
                  print('New cursor created. Client ID: ${args[1]}');
                } else {
                  cursors[args[1]]!.x = double.parse(args[2]);
                  cursors[args[1]]!.y = double.parse(args[3]);
                }
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                break;
              case "token":
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

                if (clientIDList.contains(id)) {
                  print("A user attempted to connect with duplicate ID");
                  kickWS(ws);
                  break;
                }
                if (whitelist.isNotEmpty) {
                  if (whitelist.contains(id)) {
                    print("User with whitelisted ID: $id has joined.");
                  } else {
                    print("User attempted to join with blocked ID");
                    kickWS(ws);
                    break;
                  }
                }

                if (config['block_uuid']) {
                  print('UUID blocking is enabled, validating ID...');
                  if (id.split('-').length == 5) {
                    print('Blocked ID $id');
                    kickWS(ws);
                    break;
                  }
                }

                clientIDList.add(id);

                if (versions.contains(v) || versions.isEmpty) {
                  versionMap[ws] = v;
                  clientIDs[ws] = id;
                  print("A new user has joined. ID: $id. Version: $v");
                } else if (versions.isNotEmpty) {
                  print("A user has joined with incompatible version");
                  kickWS(ws);
                }
                break;
              default:
                print(
                  'Randomly got invalid packet $data. Sending to other clients.',
                );
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                break;
            }
          }
        },
        onDone: () => removeWebsocket(ws),
        onError: (e) => removeWebsocket(ws),
      );

      gridCache ??= P2.encodeGrid();
      ws.sink.add('grid $gridCache');

      if (type == ServerType.level) {
        ws.sink.add(
          'edtype puzzle',
        );

        hovers.forEach(
          (uuid, hover) {
            ws.sink.add(
              'new-hover $uuid ${hover.x} ${hover.y} ${hover.id} ${hover.rot}',
            );
          },
        );

        cursors.forEach(
          (id, cursor) {
            ws.sink.add('set-cursor $id ${cursor.x} ${cursor.y}');
          },
        );
      } // Send grid to client

      if (versions.isNotEmpty) {
        Future.delayed(Duration(milliseconds: 500)).then(
          (v) {
            if (!versions.contains(versionMap[ws])) {
              kickWS(ws);
            }
          },
        );
      }
    },
  );

  final ip = await parseIP(config['ip']!);

  final port = int.parse(config['port']);

  final server = await sio.serve(ws, ip, port);

  return server;
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

  if (kickAllowed == 'true') {
    removeWebsocket(ws);
    print('A user has been kicked');
  } else {
    print('A user wasnt kicked');
  }
}
