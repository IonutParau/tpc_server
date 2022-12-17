part of plugins;

enum PluginType {
  error,
  lua,
  arrow,
}

class PluginLoader {
  final luaPlugins = <LuaPlugin>[];

  final pluginDir = Directory('plugins');

  PluginType getPluginType(Directory directory) {
    if (directory.existsSync()) {
      final luaFile = File(path.join(directory.path, "main.lua"));

      if (luaFile.existsSync()) {
        return PluginType.lua;
      }

      final arrowFile = File(path.join(directory.path, "main.arrow"));

      if (arrowFile.existsSync()) {
        return PluginType.arrow;
      }
    }

    return PluginType.error;
  }

  void addPlugin(Directory directory) {
    final type = getPluginType(directory);
    if (type == PluginType.lua) {
      luaPlugins.add(LuaPlugin(directory));
    }
  }

  List<Directory> getPluginDirs() {
    return (pluginDir.listSync()..removeWhere((entity) => entity is! Directory)).map<Directory>((e) => e as Directory).toList();
  }
}
