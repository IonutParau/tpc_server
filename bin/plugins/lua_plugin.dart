part of plugins;

class LuaPlugin {
  Directory dir;
  LuaState vm;

  LuaPlugin(this.dir) : vm = LuaState.newState();

  Set<String> termCmds = {};
  Set<String> packets = {};
  Set<String> chatCmds = {};

  // Collects everything but the top X elements
  void collect(LuaState state, [int off = 0]) {
    while (state.getTop() > off) {
      state.remove(state.getTop() - off);
    }
  }

  // Automatic memory management
  void collected(LuaState state, void Function() toRun, [int returns = 0]) {
    final start = state.getTop();

    toRun();

    while (state.getTop() - returns > start) {
      state.remove(state.getTop() - returns);
    }
  }

  void onConnect(String id, String ver) {
    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "onConnect");
      vm.pushString(id);
      vm.pushString(ver);
      vm.call(2, 0);
    });
  }

  void onKick(String id) {
    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "onKick");
      vm.pushString(id);
      vm.call(1, 0);
    });
  }

  void onDisconnect(String id) {
    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "onDisconnect");
      vm.pushString(id);
      vm.call(1, 0);
    });
  }

  void onPacket(String? id, String packet) {
    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "onPacket");
      vm.pushString(id);
      vm.pushString(packet);
      vm.call(2, 0);
    });
  }

  void loadRelativeFile(String file) {
    if (!vm.doFile(path.joinAll([dir.path, ...file.split('/')]))) {
      print("Running a plugin failed!\nFailed to load relative file: $file");
      exit(0);
    }
  }

  bool runTermCmd(String termCmd, List<String> args) {
    if (termCmds.contains(termCmd)) {
      collected(vm, () {
        vm.getGlobal("TERM:$termCmd");
        vm.newTable();
        var i = 0;
        for (var arg in args) {
          i++;
          vm.pushInteger(i);
          vm.pushString(arg);
          vm.setTable(-3);
        }
        vm.call(1, 0);
      });

      return true;
    }

    return false;
  }

  bool runPacket(String packet, List<String> args) {
    if (packets.contains(packet)) {
      collected(vm, () {
        vm.getGlobal("PACKET:$packet");
        vm.newTable();
        var i = 0;
        for (var arg in args) {
          i++;
          vm.pushInteger(i);
          vm.pushString(arg);
          vm.setTable(-3);
        }
        vm.call(1, 0);
      });
      return true;
    }

    return false;
  }

  bool runChatCmd(String author, String cmd, List<String> args) {
    if (chatCmds.contains(cmd)) {
      collected(vm, () {
        vm.getGlobal("CHATCMD:$cmd");
        vm.pushString(author);
        vm.pushString(cmd);
        vm.newTable();
        var i = 0;
        for (var arg in args) {
          i++;
          vm.pushInteger(i);
          vm.pushString(arg);
          vm.setTable(-3);
        }
        vm.call(3, 0);
      });

      return true;
    }
    return false;
  }

  String? onPing(Map<String, String> headers, String? ip) {
    bool notfunc = false;

    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "onPing");
      if (!vm.isFunction(-1)) {
        notfunc = true;
        return;
      }
      vm.newTable();
      headers.forEach((key, value) {
        vm.pushString(value);
        vm.setField(-2, key);
      });
      vm.pushString(ip);
      vm.call(2, 1);
    }, 1);
    if (notfunc) return null;
    if (vm.isString(-1)) {
      final s = vm.toStr(-1)!;
      return s;
    }

    return null;
  }

  bool filterMessage(String author, String content) {
    bool notfunc = false;
    collected(vm, () {
      vm.getGlobal("TPC");
      vm.getField(-1, "FilterMessage");
      if (!vm.isFunction(-1)) {
        notfunc = true;
      }
      vm.pushString(author);
      vm.pushString(content);
      vm.call(2, 1);
    }, 1);

    if (notfunc) {
      return false;
    }
    return vm.toBoolean(-1);
  }

  void prepare() {
    vm.openLibs();
    // TPC table
    vm.newTable();

    vm.pushDartFunction((ls) => 0);
    vm.setField(-2, "onConnect");

    vm.pushDartFunction((ls) => 0);
    vm.setField(-2, "onDisconnect");

    vm.pushDartFunction((ls) => 0);
    vm.setField(-2, "onKick");

    vm.pushDartFunction((ls) => 0);
    vm.setField(-2, "onPacket");

    vm.pushDartFunction((ls) {
      ls.pushBoolean(false);
      return 1;
    });
    vm.setField(-2, "FilterMessage");

    vm.pushDartFunction(import);
    vm.setField(-2, "Import");

    // TimeSinceEpoch
    vm.pushDartFunction((ls) {
      final s = ls.checkString(1);

      if (s == null) {
        ls.pushNil();
        return 1;
      }

      ls.pushNumber(getTimeSinceEpoch(s).toDouble());
      return 1;
    });
    vm.setField(-2, "TimeSinceEpoch");

    // Register Terminal Command
    vm.pushDartFunction((ls) {
      final id = ls.toStr(-2);
      ls.pushValue(-1);

      if (id != null) {
        print("Registering Terminal Command: $id");
        termCmds.add(id);
        ls.setGlobal("TERM:$id");
      }
      ls.pop(ls.getTop());

      return 0;
    });
    vm.setField(-2, "RegisterTerminalCommand");

    // Register Chat Command
    vm.pushDartFunction((ls) {
      final id = ls.toStr(-2);
      ls.pushValue(-1);

      if (id != null) {
        print("Registering Chat Command: $id");
        termCmds.add(id);
        ls.setGlobal("CHATCMD:$id");
      }
      ls.pop(ls.getTop());

      return 0;
    });
    vm.setField(-2, "RegisterChatCommand");

    // Register Packet
    vm.pushDartFunction((ls) {
      final id = ls.toStr(-2);
      ls.pushValue(-1);

      if (id != null) {
        print("Registering Packet: $id");
        packets.add(id);
        ls.setGlobal("PACKET:$id");
      }
      ls.pop(ls.getTop());

      return 0;
    });
    vm.setField(-2, "RegisterPacket");

    // Get Current Connections
    vm.pushDartFunction((ls) {
      ls.newTable();
      var i = 0;
      for (var clientID in clientIDList) {
        i++;
        ls.pushInteger(i);
        ls.pushString(clientID);
        ls.setTable(-3);
      }

      return 1;
    });
    vm.setField(-2, "GetConnections");

    // WS table
    vm.newTable();

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-1);
      if (id != null) {
        final role = roles[id];
        if (role != null) {
          ls.pushString(role.toString().replaceAll('UserRole.', ''));
        }
        ls.pushNil();
      } else {
        ls.pushNil();
      }

      return 1;
    });
    vm.setField(-2, "GetRole");

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-1);
      if (id != null) {
        WebSocketChannel? user;
        for (var ws in webSockets) {
          if (clientIDs[ws] == id) {
            user = ws;
          }
        }
        if (user != null) {
          kickWS(user);
        }
      }
      ls.pop(ls.getTop());
      return 0;
    });
    vm.setField(-2, "Kick");

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-2);
      final packet = ls.toStr(-1);
      if (id != null && packet != null) {
        WebSocketChannel? user;
        for (var ws in webSockets) {
          if (clientIDs[ws] == id) {
            user = ws;
          }
        }
        if (user != null) {
          user.sink.add(packet);
        }
      }
      ls.pop(ls.getTop());
      return 0;
    });
    vm.setField(-2, "Send");

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-1);

      if (id == null) {
        ls.pushNil();
      } else {
        WebSocketChannel? ws;
        for (var webSocket in webSockets) {
          if (clientIDs[webSocket] == id) {
            ws = webSocket;
          }
        }
        if (ws != null) {
          ls.pushString(versionMap[ws]);
        } else {
          ls.pushNil();
        }
      }

      return 1;
    });
    vm.setField(-2, "GetClientVer");

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-1);
      ls.pushValue(-2);

      if (id != null) {
        WebSocketChannel? ws;
        for (var webSocket in webSockets) {
          if (clientIDs[webSocket] == id) {
            ws = webSocket;
          }
        }
        if (ws != null) {
          ls.getField(-2, "x");
          final x = ls.toNumber(-1);
          ls.getField(-2, "y");
          final y = ls.toNumber(-1);
          ls.getField(-2, "selection");
          final selection = ls.toStr(-1)!;
          ls.getField(-2, "rotation");
          final rotation = ls.toInteger(-1) % 4;
          ls.getField(-2, "texture");
          final texture = ls.toStr(-1)!;
          var cursor = ClientCursor(x, y, selection, rotation, texture, {}, ws);
          cursors[id] = cursor;

          for (var webSocket in webSockets) {
            webSocket.sink.add(cursor.toPacket(id));
          }
        }
      }
      ls.pop(ls.getTop());

      return 0;
    });
    vm.setField(-2, "SetCursor");

    vm.pushDartFunction((ls) {
      final id = ls.toStr(-1);

      if (id != null) {
        final cursor = cursors[id];
        if (cursor != null) {
          ls.newTable();

          ls.pushNumber(cursor.x);
          ls.setField(-2, "x");

          ls.pushNumber(cursor.y);
          ls.setField(-2, "y");

          ls.pushString(cursor.selection);
          ls.setField(-2, "selection");

          ls.pushInteger(cursor.rotation);
          ls.setField(-2, "rotation");

          ls.pushString(cursor.texture);
          ls.setField(-2, "texture");

          return 1;
        }
      }

      ls.pushNil();
      return 1;
    });
    vm.setField(-2, "GetCursor");

    // WS table
    vm.setField(-2, "WS");

    vm.pushDartFunction((ls) {
      ls.newTable();
      cursors.forEach((id, cursor) {
        ls.newTable();

        ls.pushNumber(cursor.x);
        ls.setField(-2, "x");

        ls.pushNumber(cursor.y);
        ls.setField(-2, "y");

        ls.pushString(cursor.selection);
        ls.setField(-2, "selection");

        ls.pushInteger(cursor.rotation);
        ls.setField(-2, "rotation");

        ls.pushString(cursor.texture);
        ls.setField(-2, "texture");

        ls.setField(-2, id);
      });
      return 1;
    });
    vm.setField(-2, "GetCursors");

    vm.pushDartFunction((ls) {
      final def = ls.toStr(-1);
      if (def != null) {
        ls.newTable();
        var i = 0;
        for (var webSocket in webSockets) {
          final id = clientIDs[webSocket] ?? def;
          i++;
          ls.pushInteger(i);
          ls.pushString(id);
          ls.setTable(-3);
        }
        return 1;
      }
      ls.pushNil();
      return 1;
    });
    vm.setField(-2, "GetStreams");

    vm.pushDartFunction((ls) {
      ls.pushString(v);
      return 1;
    });
    vm.setField(-2, "GetServerVersion");

    // Grid table
    vm.newTable();

    vm.pushDartFunction((ls) {
      gridCache ??= SavingFormat.encodeGrid();

      ls.pushString(gridCache);

      return 1;
    });

    vm.setField(-2, "Code");

    // Grid table
    vm.setField(-2, "Grid");

    // Plugins table
    vm.newTable();

    // Amount table
    vm.newTable();

    vm.pushDartFunction((ls) {
      vm.pushInteger(pluginLoader.arrowPlugins.length);
      return 1;
    });
    vm.setField(-2, "Arrow");

    vm.pushDartFunction((ls) {
      vm.pushInteger(pluginLoader.luaPlugins.length);
      return 1;
    });
    vm.setField(-2, "Lua");

    // Amount table
    vm.setField(-2, "Amount");

    // ByName table
    vm.newTable();

    vm.pushDartFunction((ls) {
      var i = 0;
      ls.newTable();
      for (var plugin in pluginLoader.arrowPlugins) {
        i++;
        ls.pushInteger(i);
        ls.pushString(path.split(plugin.dir.path).last);
        ls.setTable(-3);
      }
      return 1;
    });
    vm.setField(-2, "Arrow");

    vm.pushDartFunction((ls) {
      var i = 0;
      ls.newTable();
      for (var plugin in pluginLoader.luaPlugins) {
        i++;
        ls.pushInteger(i);
        ls.pushString(path.split(plugin.dir.path).last);
        ls.setTable(-3);
      }
      return 1;
    });
    vm.setField(-2, "Lua");

    // ByName table
    vm.setField(-2, "ByName");

    // Plugins table
    vm.setField(-2, "Plugins");

    // TPC table
    vm.setGlobal("TPC");
  }

  void load() {
    loadRelativeFile("main.lua");
  }

  int import(LuaState ls) {
    final p = ls.toString2(1);
    if (p == null) return 0;
    final f = File(path.join(dir.path, p));
    if (f.existsSync()) {
      loadRelativeFile(p);
    }

    return 0;
  }
}
