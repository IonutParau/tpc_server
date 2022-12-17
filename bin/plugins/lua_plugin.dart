part of plugins;

class LuaPlugin {
  Directory dir;
  LuaState vm;

  LuaPlugin(this.dir) : vm = LuaState();

  Set<String> termCmds = {};
  Set<String> packets = {};
  Set<String> chatCmds = {};

  // Collects everything but the top X elements
  void collect(LuaState state, [int off = 0]) {
    while (state.top > off) {
      state.remove(state.top - off);
    }
  }

  // Automatic memory management
  void collected(LuaState state, void Function() toRun, [int returns = 0]) {
    final start = state.top;

    toRun();

    while (state.top - returns > start) {
      state.remove(state.top - returns);
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
      vm.pushString(id ?? "");
      vm.pushString(packet);
      vm.call(2, 0);
    });
  }

  void loadRelativeFile(String file, [int returns = 0]) {
    final status = vm.loadFile(path.joinAll([dir.path, ...file.split('/')]));
    if (status != LuaThreadStatus.ok) {
      print("Running a plugin failed!\nFailed to load relative file: $file\nError Type: $status\nError: ${vm.toStr(-1)}");
      exit(0);
    } else {
      vm.call(0, returns);
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
        vm.pushString(key);
        vm.pushString(value);
        vm.setTable(-3);
      });
      vm.pushString(ip ?? "");
      vm.call(2, 1);
    }, 1);
    if (notfunc) return null;
    if (vm.isStr(-1)) {
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

    final api = <String, dynamic>{
      "onConnect": (LuaState ls) => 0,
      "onDisconnect": (LuaState ls) => 0,
      "onKick": (LuaState ls) => 0,
      "onPacket": (LuaState ls) => 0,
      "FilterMessage": (LuaState ls) {
        ls.pushBoolean(false);
        return 1;
      },
      "Import": import,
      "Module": loadModule,
      "TimeSinceEpoch": (LuaState ls) {
        final s = ls.toStr(-1);

        if (s == null) {
          ls.pushNil();
          return 1;
        }

        ls.pushNumber(getTimeSinceEpoch(s).toDouble());
        return 1;
      },
      "RegisterTerminalCommand": (LuaState ls) {
        print([ls.type(-2), ls.type(-1)]);

        final id = ls.toStr(-2);

        print(id);

        if (id != null) {
          print("Registering Terminal Command: $id");
          termCmds.add(id);
          ls.setGlobal("TERM:$id");
        }

        return 0;
      },
      "RegisterChatCommand": (LuaState ls) {
        final id = ls.toStr(-2);

        if (id != null) {
          print("Registering Chat Command: $id");
          termCmds.add(id);
          ls.setGlobal("CHATCMD:$id");
        }

        return 0;
      },
      "RegisterPacket": (LuaState ls) {
        final id = ls.toStr(-2);
        ls.pushNil();
        ls.copy(-2, -1);

        if (id != null) {
          print("Registering Packet: $id");
          packets.add(id);
          ls.setGlobal("PACKET:$id");
        }

        return 0;
      },
      "GetConnections": (LuaState ls) {
        ls.createTable(clientIDList.length, clientIDList.length);
        var i = 0;
        for (var clientID in clientIDList) {
          i++;
          ls.pushInteger(i);
          ls.pushString(clientID);
          ls.setTable(-3);
        }

        return 1;
      },
      "GetCursors": (LuaState ls) {
        ls.newTable();
        cursors.forEach((id, cursor) {
          ls.newTable();

          ls.pushNumber(cursor.x);
          ls.setField(-2, "x", -1);
          ls.pop();

          ls.pushNumber(cursor.y);
          ls.setField(-2, "y", -1);
          ls.pop();

          ls.pushString(cursor.selection);
          ls.setField(-2, "selection", -1);
          ls.pop();

          ls.pushInteger(cursor.rotation);
          ls.setField(-2, "rotation", -1);
          ls.pop();

          ls.pushString(cursor.texture);
          ls.setField(-2, "texture", -1);
          ls.pop();

          ls.setField(-2, id, -1);
          ls.pop();
        });
        return 1;
      },
      "GetStreams": (LuaState ls) {
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
      },
      "GetServerVersion": (LuaState ls) {
        ls.pushString(v);
        return 1;
      }
    };

    final wsAPI = <String, dynamic>{
      "GetRole": (LuaState ls) {
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
      },
      "Kick": (LuaState ls) {
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
      },
      "Send": (LuaState ls) {
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
      },
      "GetClientVer": (LuaState ls) {
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
            ls.pushString(versionMap[ws] ?? "");
          } else {
            ls.pushNil();
          }
        }

        return 1;
      },
      "SetCursor": (LuaState ls) {
        final id = ls.toStr(-2);

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

        return 0;
      },
      "GetCursor": (LuaState ls) {
        final id = ls.toStr(-1);

        if (id != null) {
          final cursor = cursors[id];
          if (cursor != null) {
            ls.newTable();

            ls.pushNumber(cursor.x);
            ls.setField(-2, "x", -1);
            ls.pop(1);

            ls.pushNumber(cursor.y);
            ls.setField(-2, "y", -1);
            ls.pop();

            ls.pushString(cursor.selection);
            ls.setField(-2, "selection", -1);
            ls.pop();

            ls.pushInteger(cursor.rotation);
            ls.setField(-2, "rotation", -1);
            ls.pop();

            ls.pushString(cursor.texture);
            ls.setField(-2, "texture", -1);
            ls.pop();

            return 1;
          }
        }

        ls.pushNil();
        return 1;
      },
    };

    api["WS"] = wsAPI;

    api["Grid"] = <String, dynamic>{
      "Code": (LuaState ls) {
        gridCache ??= SavingFormat.encodeGrid();

        ls.pushString(gridCache!);

        return 1;
      },
    };

    final pluginsAPI = <String, dynamic>{
      "Count": (LuaState ls) {
        ls.pushInteger(pluginLoader.luaPlugins.length);
        return 1;
      },
      "Names": (LuaState ls) {
        ls.createTable(pluginLoader.luaPlugins.length, pluginLoader.luaPlugins.length);

        int i = 0;
        for (var luaPlugin in pluginLoader.luaPlugins) {
          i++;
          ls.pushInteger(i);
          ls.pushString(path.split(luaPlugin.dir.path).last);
          ls.setTable(-3);
        }

        return 1;
      },
    };

    api["Plugins"] = pluginsAPI;

    vm.makeLib("TPC", api);

    final modulesF = File(path.join(dir.path, 'modules.json'));
    if (modulesF.existsSync()) {
      List modules = jsonDecode(modulesF.readAsStringSync());

      for (var module in modules) {
        if (module is String) {
          loadModuleIntoVM(module);
        }
      }
    }
  }

  void load() {
    loadRelativeFile("main.lua");
  }

  int import(LuaState ls) {
    final p = ls.toStr(-1);
    if (p == null) return 0;
    final f = File(path.join(dir.path, p));
    if (f.existsSync()) {
      loadRelativeFile(p);
    }

    return 0;
  }

  int loadModule(LuaState ls) {
    final m = ls.toStr(-1);
    if (m == null) return 0;
    loadModuleIntoVM(m);
    return 1;
  }

  void loadModuleIntoVM(String module) {
    loadRelativeFile("../../modules/$module.lua", 1);
    vm.setGlobal(module);
  }
}
