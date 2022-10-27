part of mods;

enum ModType {
  error,
  lua,
  arrow,
}

class ModLoader {
  final luaMods = <LuaMod>[];
  final arrowMods = <ArrowMod>[];

  final modDir = Directory('plugins');

  ModType getModType(Directory directory) {
    if (directory.existsSync()) {
      final luaFile = File(path.join(directory.path, "main.lua"));

      if (luaFile.existsSync()) {
        return ModType.lua;
      }

      final arrowFile = File(path.join(directory.path, "main.arw"));

      if (arrowFile.existsSync()) {
        return ModType.arrow;
      }
    }

    return ModType.error;
  }

  void addMod(Directory directory) {
    final type = getModType(directory);
    if (type == ModType.lua) {
      luaMods.add(LuaMod(directory));
    }
    if (type == ModType.arrow) {
      arrowMods.add(ArrowMod(directory));
    }
  }

  List<Directory> getModDirs() {
    return (modDir.listSync()..removeWhere((entity) => entity is! Directory)).map<Directory>((e) => e as Directory).toList();
  }
}
