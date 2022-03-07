import 'dart:io';
import 'package:args/args.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:shelf/shelf_io.dart' as sio;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'grid.dart';

// API docs
/*

[Grid Management]
- place <x> <y> <id> <rot> - Places cell
- bg <x> <y> <bg> - Sets background
- wrap - Toggles wrap mode
- setinit - Sets initial state on the server

[Logic Management]
- edtype <type> - Is the editor type wanted by the server

[Hover Management]
- new-hover <uuid> <x> <y> <id> <rot> - Creates new hover
- set-hover <uuid> <x> <y> - Sets the new hover position
- drop-hover <uuid> - Removes the hover

[Cursor Management]
- set-cursor <uuid> <x> <y> - Sets cursor state
- remove-cursor <uuid> - Removes the cursor (client only)

*/

enum ServerType {
  sandbox,
  level,
}

var type = ServerType.sandbox;

late ArgResults config;

void main(List<String> arguments) async {
  final args = ArgParser();
  args.addOption('ip', defaultsTo: 'local');
  args.addOption('port', defaultsTo: '8080');
  args.addFlag('silent', negatable: false);

  config = args.parse(arguments);

  print("Welcome to The Puzzle Cell Server Handling System");

  print("Please input server type (sandbox / level)");
  final input = stdin.readLineSync();

  if (input != "sandbox" && input != "level") {
    print("Invalid server type");
    return;
  }

  if (input == "level") type = ServerType.level;

  if (type == ServerType.sandbox) {
    print("Please input grid width");
    final width = int.parse(stdin.readLineSync()!);
    print("Please input grid height");
    final height = int.parse(stdin.readLineSync()!);
    makeGrid(width, height);
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
    print(
      'Server should be online, at ws://${server.address.address}:${server.port}/',
    );
  }
}

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

void removeWebsocket(WebSocketChannel ws) {
  webSockets.remove(ws);
  String cursorID = "";

  cursors.forEach(
    (id, cursor) {
      if (cursor.author == ws) {
        cursorID = id;
      }
    },
  );

  if (cursorID != "") {
    cursors.remove(cursorID);
    for (var ws in webSockets) {
      ws.sink.add('remove-cursor $cursorID');
    }
  }
}

Future<HttpServer> createServer() async {
  final ws = webSocketHandler(
    (WebSocketChannel ws) {
      webSockets.add(ws);
      ws.stream.listen(
        (data) {
          if (data is String) {
            final args = data.split(' ');

            switch (args.first) {
              case "place":
                grid[int.parse(args[1])][int.parse(args[2])].id = args[3];
                grid[int.parse(args[1])][int.parse(args[2])].rot =
                    int.parse(args[4]);
                for (var ws in webSockets) {
                  ws.sink.add(data);
                }
                gridCache = null;
                break;
              case "bg":
                grid[int.parse(args[1])][int.parse(args[2])].bg = args[3];
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
                if (cursors[args[1]] == null) {
                  cursors[args[1]] = ClientCursor(
                    double.parse(args[2]),
                    double.parse(args[3]),
                    ws,
                  );
                } else {
                  cursors[args[1]]!.x = double.parse(args[2]);
                  cursors[args[1]]!.y = double.parse(args[3]);
                }
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
        ); // Send grid to client
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
