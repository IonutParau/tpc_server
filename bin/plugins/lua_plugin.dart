part of plugins;

class LuaPlugin {
  Directory dir;
  LuaState vm;

  LuaPlugin(this.dir) : vm = LuaState.newState();

  Set<String> termCmds = {};
  Set<String> packets = {};

  void onConnect(String id, String ver) {
    vm.getGlobal("TPC");
    vm.getField(-1, "onConnect");
    vm.pushString(ver);
    vm.pushString(id);
    vm.call(2, 0);
  }

  void onKick(String id) {
    vm.getGlobal("TPC");
    vm.getField(-1, "onKick");
    vm.pushString(id);
    vm.call(1, 0);
  }

  void onDisconnect(String id) {
    vm.getGlobal("TPC");
    vm.getField(-1, "onDisconnect");
    vm.pushString(id);
    vm.call(1, 0);
  }

  void onPacket(String? id, String packet) {
    vm.getGlobal("TPC");
    vm.getField(-1, "onPacket");
    vm.pushString(packet);
    vm.pushString(id);
    vm.call(1, 0);
  }

  void loadRelativeFile(String file) {
    if (!vm.doFile(path.joinAll([dir.path, ...file.split('/')]))) {
      print("Running a plugin failed!\nFailed to load relative file: $file");
      exit(0);
    }
  }

  bool runTermCmd(String termCmd, List<String> args) {
    if (termCmds.contains(termCmd)) {
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

      return true;
    }

    return false;
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

    vm.pushDartFunction(import);
    vm.setField(-2, "Import");

    // Register Terminal Command
    vm.pushDartFunction((ls) {
      final id = ls.toStr(-2);
      ls.pushValue(-1);

      if (id != null) {
        print("Registering Terminal Command: $id");
        termCmds.add(id);
        ls.setGlobal("TERM:$id");
      }

      return 0;
    });
    vm.setField(-2, "RegisterTerminalCommand");

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
      return 0;
    });
    vm.setField(-2, "Send");

    // WS table
    vm.setField(-2, "WS");

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
