part of plugins;

class ArrowPlugin {
  Directory dir;
  ArrowVM vm = ArrowVM();

  ArrowPlugin(this.dir);

  Map<String, ArrowResource> termCmds = {};
  Map<String, ArrowResource> chatCmds = {};
  Map<String, ArrowResource> packets = {};

  void onConnect(String id, String ver) {
    vm.globals.get("TPC").getField("onConnect", vm.stackTrace, "tpc:onConnect", 0).call([ArrowString(id), ArrowString(ver)], vm.stackTrace, "tpc:onConnect", 0);
  }

  void onKick(String id) {
    vm.globals.get("TPC").getField("onKick", vm.stackTrace, "tpc:onKick", 0).call([ArrowString(id)], vm.stackTrace, "tpc:onKick", 0);
  }

  void onDisconnect(String id) {
    vm.globals.get("TPC").getField("onDisconnect", vm.stackTrace, "tpc:onDisconnect", 0).call([ArrowString(id)], vm.stackTrace, "tpc:onDisconnect", 0);
  }

  void onPacket(String? id, String packet) {
    vm.globals.get("TPC").getField("onPacket", vm.stackTrace, "tpc:onPacket", 0).call([id == null ? ArrowNull() : ArrowString(id), ArrowString(packet)], vm.stackTrace, "tpc:onPacket", 0);
  }

  bool runTermCmd(String cmd, List<String> args) {
    if (termCmds[cmd] == null) return false;

    termCmds[cmd]!.call(args.map<ArrowResource>((e) => ArrowString(e)).toList(), vm.stackTrace, "tpc:runTermCmd", 0);

    return true;
  }

  bool runChatCmd(String author, String cmd, List<String> args) {
    if (chatCmds[cmd] == null) return false;

    chatCmds[cmd]!.call([ArrowString(author), ArrowList(args.map<ArrowResource>((e) => ArrowString(e)).toList())], vm.stackTrace, "tpc:runChatCmd", 0);

    return true;
  }

  bool runPacket(String packet, List<String> args) {
    if (packets[packet] == null) return false;

    packets[packet]!.call(args.map<ArrowResource>((e) => ArrowString(e)).toList(), vm.stackTrace, "tpc:runPacket", 0);

    return true;
  }

  String? onPing(Map<String, String> headers, String? ip) {
    final params = <ArrowResource>[];

    final hm = <String, ArrowResource>{};
    headers.forEach((key, value) {
      hm[key] = ArrowString(value);
    });
    params.add(ArrowMap(hm));

    params.add(ip == null ? ArrowNull() : ArrowString(ip));

    vm.stackTrace.push(ArrowStackTraceElement("On Ping", "tpc:onPing", 0));
    try {
      final tpc = vm.globals.get("TPC");
      if (tpc is ArrowMap) {
        vm.stackTrace.push(ArrowStackTraceElement("Read TPC.onPing", "tpc:onPing", 0));
        final ping = tpc.getField("onPing", vm.stackTrace, "tpc:onPacket", 0);
        vm.stackTrace.pop();
        vm.stackTrace.push(ArrowStackTraceElement("Call TPC.onPing", "tpc:onPing", 0));
        final result = ping.call(params, vm.stackTrace, "tpc:onPing", 0);
        vm.stackTrace.pop();

        if (result is ArrowString) {
          return result.str;
        }
      }
    } catch (e) {
      print(e);
      vm.stackTrace.show();
    }
    vm.stackTrace.pop();
    return null;
  }

  bool filterMessage(String author, String content) {
    final tpc = vm.globals.get("TPC");

    final func = tpc.getField("FilterMessage", vm.stackTrace, "tpc:filterMessage", 0);

    return func.call([ArrowString(author), ArrowString(content)], vm.stackTrace, "tpc:filterMessage", 0).truthy;
  }

  ArrowResource loadRelativeFile(String file) {
    final f = File(path.joinAll([dir.path, ...file.split('/')]));
    if (f.existsSync()) {
      vm.run(f.readAsStringSync(), file);
    } else {
      print("Running a plugin failed!\nFailed to run relative file: $file");
      print("Stack Trace:");
      vm.stackTrace.show();
      exit(0);
    }

    return ArrowNull();
  }

  void prepare() {
    vm.loadLibs();

    final tpc = <String, ArrowResource>{};

    final emptyFunc = ArrowExternalFunction((params, stackTrace) => ArrowNull(), 0);

    tpc["onConnect"] = emptyFunc;
    tpc["onKick"] = emptyFunc;
    tpc["onDisconnect"] = emptyFunc;
    tpc["onPacket"] = emptyFunc;

    tpc["Import"] = ArrowExternalFunction(import, 1);

    tpc["RegisterTerminalCommand"] = ArrowExternalFunction((params, stackTrace) {
      final cmd = params[0];
      final func = params[1];

      if (func.type == "function") {
        print("Registering Terminal Command: $cmd");
        termCmds[cmd.string] = func;
      }

      return ArrowNull();
    }, 2);

    tpc["TimeSinceEpoch"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowNumber(getTimeSinceEpoch(params.first.string));
    }, 1);

    tpc["RegisterChatCommand"] = ArrowExternalFunction((params, stackTrace) {
      final cmd = params[0];
      final func = params[1];

      if (func.type == "function") {
        print("Registering Chat Command: $cmd");
        chatCmds[cmd.string] = func;
      }

      return ArrowNull();
    }, 2);

    tpc["RegisterPacket"] = ArrowExternalFunction((params, stackTrace) {
      final packet = params[0];
      final func = params[1];

      if (func.type == "function") {
        print("Registering Packet: $packet");
        packets[packet.string] = func;
      }

      return ArrowNull();
    }, 2);

    final grid = <String, ArrowResource>{};

    grid["Code"] = ArrowExternalFunction((params, stackTrace) {
      gridCache ??= SavingFormat.encodeGrid();
      return ArrowString(gridCache!);
    });

    tpc["Grid"] = ArrowMap(grid);

    final pluginAmount = <String, ArrowResource>{};
    final pluginByName = <String, ArrowResource>{};

    pluginAmount["Lua"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowNumber(pluginLoader.luaPlugins.length);
    });

    pluginAmount["Arrow"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowNumber(pluginLoader.arrowPlugins.length);
    });

    pluginByName["Lua"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowList(pluginLoader.luaPlugins.map((e) => ArrowString(path.split(e.dir.path).last)).toList());
    });

    pluginByName["Arrow"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowList(pluginLoader.arrowPlugins.map((e) => ArrowString(path.split(e.dir.path).last)).toList());
    });

    tpc["Plugins"] = ArrowMap({"Amount": ArrowMap(pluginAmount), "ByName": ArrowMap(pluginByName)});

    tpc["GetConnections"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowList(clientIDList.map((e) => ArrowString(e)).toList());
    });

    final tpcWS = <String, ArrowResource>{};

    tpcWS["GetRole"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;

      final role = roles[id];
      if (role != null) {
        return ArrowString(role.toString().replaceAll('UserRole.', ''));
      }

      return ArrowNull();
    }, 1);

    tpcWS["Kick"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;

      WebSocketChannel? user;
      for (var ws in webSockets) {
        if (clientIDs[ws] == id) {
          user = ws;
        }
      }
      if (user != null) {
        kickWS(user);
      }

      return ArrowNull();
    }, 1);

    tpcWS["Send"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;
      final packet = params[1].string;

      WebSocketChannel? user;
      for (var ws in webSockets) {
        if (clientIDs[ws] == id) {
          user = ws;
        }
      }
      if (user != null) {
        user.sink.add(packet);
      }

      return ArrowNull();
    }, 2);

    tpcWS["GetClientVer"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;

      WebSocketChannel? user;
      for (var ws in webSockets) {
        if (clientIDs[ws] == id) {
          user = ws;
        }
      }
      if (user != null) {
        final ver = versionMap[user];
        if (ver == null) return ArrowNull();
        return ArrowString(ver);
      }

      return ArrowNull();
    }, 1);

    tpcWS["SetCursor"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;
      final cursor = params[1];

      WebSocketChannel? user;
      for (var ws in webSockets) {
        if (clientIDs[ws] == id) {
          user = ws;
        }
      }

      if (cursor is ArrowMap && user != null) {
        stackTrace.push(ArrowStackTraceElement("TPC.WS.SetCursor", "tpc:SetCurosr", 0));
        try {
          final clientCursor = ClientCursor(
            (cursor.map['x'] as ArrowNumber).number,
            (cursor.map['y'] as ArrowNumber).number,
            (cursor.map['selection'] as ArrowString).str,
            (cursor.map['rotation'] as ArrowNumber).number.toInt(),
            (cursor.map['texture'] as ArrowString).str,
            {},
            user,
          );

          for (var webSocket in webSockets) {
            webSocket.sink.add(clientCursor.toPacket(id));
          }
        } catch (e) {
          print(e);
          print("Stack Trace:");
          stackTrace.show();
        }
        stackTrace.pop();
      }

      return ArrowNull();
    }, 2);

    tpcWS["GetCursor"] = ArrowExternalFunction((params, stackTrace) {
      final id = params.first.string;

      final cursor = cursors[id];

      if (cursor != null) {
        final m = <String, ArrowResource>{};

        m['x'] = ArrowNumber(cursor.x);
        m['y'] = ArrowNumber(cursor.y);
        m['selection'] = ArrowString(cursor.selection);
        m['rotation'] = ArrowNumber(cursor.rotation);
        m['texture'] = ArrowString(cursor.texture);

        return ArrowMap(m);
      }

      return ArrowNull();
    }, 1);

    tpc["WS"] = ArrowMap(tpcWS);

    tpc["GetCursors"] = ArrowExternalFunction((params, stackTrace) {
      final cursorsMap = ArrowMap({});

      cursors.forEach(
        (id, cursor) {
          final m = <String, ArrowResource>{};

          m['x'] = ArrowNumber(cursor.x);
          m['y'] = ArrowNumber(cursor.y);
          m['selection'] = ArrowString(cursor.selection);
          m['rotation'] = ArrowNumber(cursor.rotation);
          m['texture'] = ArrowString(cursor.texture);

          cursorsMap.map[id] = ArrowMap(m);
        },
      );

      return cursorsMap;
    });

    tpc["GetStreams"] = ArrowExternalFunction((params, stackTrace) {
      final def = params[0].string;
      final streams = <ArrowResource>[];

      for (var ws in webSockets) {
        streams.add(ArrowString(clientIDs[ws] ?? def));
      }

      return ArrowList(streams);
    }, 1);

    tpc["GetServerVersion"] = ArrowExternalFunction((params, stackTrace) {
      return ArrowString(v);
    });

    vm.globals.set("TPC", ArrowMap(tpc));
  }

  void load() {
    loadRelativeFile("main.arrow");
  }

  ArrowResource import(List<ArrowResource> args, ArrowStackTrace stackTrace) {
    final path = args[0];

    if (path is ArrowString) {
      return loadRelativeFile(path.str);
    }
    return ArrowNull();
  }
}
