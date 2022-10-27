part of mods;

class LuaMod {
  Directory dir;
  LuaState vm;

  LuaMod(this.dir) : vm = LuaState.newState();

  Set<String> termCmds = {};
  Map<String, DartFunction> packets = {};

  void loadRelativeFile(String file) {
    if (!vm.doFile(path.join(dir.path, "main.lua"))) {
      print("Running a plugin failed");
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
    vm.newTable();

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

    vm.setField(-2, "WS");

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
