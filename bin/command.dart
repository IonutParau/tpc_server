import 'dart:io';

import 'grid.dart';
import 'main.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:isolate'; // Pain

void commandProcessorIsolate(SendPort commandPort) {
  while (true) {
    final cmd = stdin.readLineSync();
    commandPort.send(cmd);
  }
}

// Launch command reader on seperate thread
void setupCommandIso() {
  final commandPort = ReceivePort();

  Isolate.spawn(
    commandProcessorIsolate,
    commandPort.sendPort,
    debugName: 'Command Processor Isolate',
  );

  commandPort.listen(
    (message) {
      if (message is String) {
        final cmd = message.split(' ').first;
        final args = message.split(' ').sublist(1);
        execCmd(cmd, args);
      }
    },
  );
}

// Run a command on main thread
void execCmd(String cmd, List<String> args) {
  if (cmd == "set-cell") {
    final x = int.parse(args[0]);
    final y = int.parse(args[1]);
    final id = args[2];
    final rot = int.parse(args[3]);
    final heat = int.tryParse(args[4]) ?? 0;

    print("Placed cell at $x,$y to ID: $id ROT: $rot HEAT: $heat");

    grid[x][y].id = id;
    grid[x][y].rot = rot;
    for (var ws in webSockets) {
      ws.sink.add('place $x $y $id $rot $heat');
    }
    gridCache = null;
  } else if (cmd == "set-bg") {
    final x = int.parse(args[0]);
    final y = int.parse(args[1]);
    final id = args[2];

    print("Placed background at $x,$y to ID: $id");

    grid[x][y].bg = id;
    for (var ws in webSockets) {
      ws.sink.add('bg $x $y $id');
    }
    gridCache = null;
  } else if (cmd == "toggle-wrap") {
    wrap = !wrap;
    for (var ws in webSockets) {
      ws.sink.add("wrap");
    }
    print("Toogled wrap mode (${wrap ? "ON" : "OFF"})");
    gridCache = null;
  } else if (cmd == "set-grid") {
    if (gridCache != args.join(" ")) {
      P2.decodeGrid(args.join(" "));
      for (var ws in webSockets) {
        ws.sink.add(args.join(" "));
      }
      gridCache = args.join(" ");
    }
    print("Sucessfully changed grid");
  } else if (cmd == "kick-user") {
    WebSocketChannel? user;
    for (var ws in webSockets) {
      if (clientIDs[ws] == args[0]) {
        user = ws;
      }
    }
    if (user != null) {
      kickWS(user);
    } else {
      print("User ${args[0]} does not exist.");
    }
  } else if (cmd == "list-users") {
    if (webSockets.isEmpty) {
      return print("No users are connected");
    }
    for (var ws in webSockets) {
      print(clientIDs[ws] ?? "Pending User");
    }
  } else if (cmd == "list-cursors") {
    if (cursors.isEmpty) {
      return print("No cursors exist");
    }
    cursors.forEach(
      (id, cursor) {
        print("OWNER: $id X: ${cursor.x} Y: ${cursor.y}");
      },
    );
  } else if (cmd == "list-hovers") {
    if (hovers.isEmpty) {
      return print("No hovers exist");
    }
    hovers.forEach(
      (id, hover) {
        print(
          "OWNER: $id X: ${hover.x} Y: ${hover.y} CARRIED ID: ${hover.id} CARRIED ROT: ${hover.rot}",
        );
      },
    );
  } else if (cmd == "direct-send") {
    final packet = args.join(" ");

    for (var ws in webSockets) {
      ws.sink.add(packet);
    }
  } else if (cmd == "exit") {
    exit(0);
  }
}
