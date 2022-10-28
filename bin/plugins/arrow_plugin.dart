part of plugins;

class ArrowPlugin {
  Directory dir;
  ArrowVM vm = ArrowVM();

  ArrowPlugin(this.dir);

  Map<String, ArrowResource> termCmds = {};
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

    tpc["WS"] = ArrowMap(tpcWS);

    vm.globals.set("TPC", ArrowMap(tpc));
  }

  void load() {
    loadRelativeFile("main.arw");
  }

  ArrowResource import(List<ArrowResource> args, ArrowStackTrace stackTrace) {
    final path = args[0];

    if (path is ArrowString) {
      return loadRelativeFile(path.str);
    }
    return ArrowNull();
  }
}
