import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:base_x/base_x.dart';
import 'package:quiver/collection.dart';

import 'main.dart';

class Cell {
  String id;
  int rot;
  String bg;
  int lifespan = 0;
  Map<String, dynamic> data;
  Set<String> tags;
  bool invisible;

  Cell(this.id, this.rot, this.bg, this.lifespan, this.data, this.tags, this.invisible);

  Cell get copy {
    return Cell(id, rot, bg, lifespan, Map<String, dynamic>.from(data), Set<String>.from(tags), invisible);
  }

  @override
  bool operator ==(Object other) {
    if (other is Cell) {
      return (id == other.id && rot == other.rot && bg == other.bg && invisible == other.invisible && setsEqual(tags, other.tags) && mapsEqual(data, other.data));
    } else {
      return false;
    }
  }

  @override
  int get hashCode => (rot * 4 + bg.hashCode + 20000 + rot.hashCode + 10000);
}

String cellDataStr(Map<String, dynamic> m) {
  final strs = [];

  m.forEach((key, value) {
    strs.add("$key=$value");
  });

  return strs.join(":");
}

Map<String, dynamic> parseCellDataStr(String str) {
  if (num.tryParse(str) != null) {
    return {"heat": num.parse(str)};
  }
  final pairs = str.split(':');
  final m = <String, dynamic>{};

  for (var pair in pairs) {
    final segs = pair.split('=');
    final key = segs[0];

    if (num.tryParse(segs[1]) != null) {
      m[key] = num.parse(segs[1]);
    } else if (segs[1] == "true" || segs[1] == "false") {
      m[key] = (segs[1] == "true");
    } else {
      m[key] = segs[1];
    }
  }

  return m;
}

late List<List<Cell>> grid;

bool wrap = false;
Map<int, Map<int, num>> memory = {};

void loopGrid(Function(Cell cell, int x, int y) callback) {
  for (var x = 0; x < grid.length; x++) {
    for (var y = 0; y < grid[x].length; y++) {
      callback(grid[x][y], x, y);
    }
  }
}

void loopGridPos(Function(Cell, int, int) callback) {
  for (var x = 0; x < grid.length; x++) {
    for (var y = 0; y < grid[x].length; y++) {
      callback(grid[x][y], x, y);
    }
  }
}

bool insideGrid(int x, int y) {
  return (x >= 0 && y >= 0 && x < grid.length && y < grid[x].length);
}

String placeChar(String place) {
  if (place == "place") return "+";
  if (place == "red_place") return "R+";
  if (place == "blue_place") return "B+";
  if (place == "yellow_place") return "Y+";
  if (place == "rotatable") return "RT";
  return "";
}

String decodePlaceChar(String char) {
  if (char == "+") return "place";
  if (char == "R+") return "red_place";
  if (char == "B+") return "blue_place";
  if (char == "Y+") return "yellow_place";
  if (char == "RT") return "rotatable";

  return "empty";
}

String encodeNum(int n, String valueString) {
  final cellNum = n;
  var cellBase = 0;

  while (cellNum >= pow(valueString.length, cellBase)) {
    //print('$cellBase');
    cellBase++;
  }

  if (cellNum == 0) {
    return valueString[0];
  } else {
    var cellString = '';
    for (var i = 0; i < cellBase; i++) {
      var iN = min(n ~/ pow(valueString.length, cellBase - 1 - i), valueString.length - 1);
      cellString += valueString[iN];
      n -= iN * pow(valueString.length, cellBase - 1 - i).toInt();
    }
    return cellString;
  }
}

void makeGrid(int width, int height) {
  grid = [];
  for (var x = 0; x < width; x++) {
    grid.add([]);
    for (var y = 0; y < height; y++) {
      grid.last.add(Cell("empty", 0, "empty", 0, {}, {}, false));
    }
  }
  wrap = false;
  memory = {};
}

int decodeNum(String n, String valueString) {
  var numb = 0;
  for (var i = 0; i < n.length; i++) {
    final char = n[i];
    numb += valueString.indexOf(char) * pow(valueString.length, n.length - 1 - i).toInt();
  }
  return numb;
}

void loadStr(String str) {
  if (str.startsWith('P2;')) return P2.decodeGrid(str); // P2 importing
  if (str.startsWith('P3;')) return P3.decodeString(str); // P3 importing
  if (str.startsWith('P4;')) return P4.decodeString(str); // P4 importing
  if (str.startsWith('P5;')) return P5.decodeString(str); // P5 importing
  if (str.startsWith('P6;')) return P6.decodeString(str); // P5 importing
}

class P2 {
  static String valueString = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM[]{}()-_+=<>./?:'";

  static String encodeCell(Cell cell, Set<String> cellTable) {
    return encodeNum(
      cellTable.toList().indexOf(cell.id) * 4 + cell.rot,
      valueString,
    );
  }

  static Cell decodeCell(String cell, List<String> cellTable) {
    final n = decodeNum(cell, valueString);
    final c = Cell(cellTable[n ~/ 4], n % 4, "empty", 0, {}, {}, false);

    return c;
  }

  static String sig = "P2;";

  static String encodeGrid() {
    var str = sig;
    str += ";;"; // title and description
    str += (encodeNum(grid.length, valueString) + ';');
    str += (encodeNum(grid.first.length, valueString) + ';');

    final cellTable = <String>{};

    loopGrid(
      (cell, x, y) {
        cellTable.add(cell.id);
      },
    );

    str += "${cellTable.join(',')};";

    final cells = [];

    loopGrid(
      (cell, x, y) {
        cells.add("${encodeCell(cell, cellTable)}|${placeChar(cell.bg)}");
      },
    );

    final cellStr = base64.encode(zlib.encode(utf8.encode(cells.join(','))));

    str += (cellStr + ';');

    final props = [];

    if (wrap) props.add("WRAP");

    str += "${props.join(',')};";

    return str;
  }

  static void decodeGrid(String str) {
    final segs = str.split(';');
    makeGrid(decodeNum(segs[3], valueString), decodeNum(segs[4], valueString));

    final cellTable = segs[5].split(',');

    final cellData = utf8.decode(zlib.decode(base64.decode(segs[6])));

    final cells = cellData.split(',');

    var i = 0;
    loopGridPos(
      (cell, x, y) {
        final cell = cells[i];
        grid[x][y] = decodeCell(cell.split('|').first, cellTable);
        final placeChar = cell.split('|').length == 1 ? '' : cell.split('|')[1];
        grid[x][y].bg = decodePlaceChar(placeChar);
        i++;
      },
    );

    if (segs.length >= 7) {
      // Special border mode
      final props = segs[7].split(',');
      wrap = props.contains('WRAP');
    }
  }
}

class P3 {
  static String valueString = r"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&+-.=?^{}";

  static String signature = "P3;";

  static String encodeData(Map<String, dynamic> data) {
    var dataParts = [];
    data.forEach(
      (key, value) {
        dataParts.add("$key=$value");
      },
    );
    return dataParts.join('.');
  }

  static String encodeCell(int x, int y) {
    final c = grid[x][y];
    final bg = c.bg;

    final tagsStr = c.tags.join('.');

    final dataStr = encodeData(c.data);

    return "${c.id}:$x:$y:${c.rot}:$dataStr:$tagsStr:$bg:${c.lifespan}";
  }

  // P3 Compex Validation System
  static bool validate(int x, int y) {
    final c = grid[x][y];
    final bg = c.bg;

    return (c.id != "empty" || bg != "empty");
  }

  static String encodeGrid({String title = "", String description = ""}) {
    var str = signature;
    str += "$title;$description;"; // Title and description
    str += "${encodeNum(grid.length, valueString)};";
    str += "${encodeNum(grid.first.length, valueString)};";

    final cellDataList = [];

    loopGrid(
      (cell, x, y) {
        if (validate(x, y)) {
          cellDataList.add(encodeCell(x, y));
          //print(cellDataList.last);
        }
      },
    );

    final cellDataStr = base64.encode(
      zlib.encode(
        utf8.encode(
          cellDataList.join(','),
        ),
      ),
    );

    str += "$cellDataStr;";

    final props = [];

    if (wrap) props.add("W");

    str += "${props.join('')};";

    return str;
  }

  static Map<String, dynamic> getData(String str) {
    if (str == "") return <String, dynamic>{};
    final segs = str.split('.');
    final data = <String, dynamic>{};
    if (segs.isEmpty) return data;
    for (var part in segs) {
      final p = part.split('=');

      dynamic v = p[1];

      if (v == "true" || v == "false") v = (v == "true");
      if (int.tryParse(v) != null) v = int.parse(v);

      data[p[0]] = v;
    }
    return data;
  }

  static P3Cell decodeCell(String str) {
    final segs = str.split(':');

    if (segs.length < 8) segs.add("0");

    return P3Cell(
      segs[0],
      int.parse(segs[1]),
      int.parse(segs[2]),
      int.parse(segs[3]),
      getData(segs[4]),
      segs[5].split('.').toSet(),
      segs[6],
      int.parse(segs[7]),
    );
  }

  static void decodeString(String str) {
    final segs = str.split(';');
    makeGrid(
      decodeNum(segs[3], valueString),
      decodeNum(segs[4], valueString),
    );

    final cellDataStr = segs[5] == "eJwDAAAAAAE=" ? "" : utf8.decode(zlib.decode(base64.decode(segs[5])));

    if (cellDataStr != "") {
      final cellDataList = cellDataStr.split(',');

      for (var cellData in cellDataList) {
        decodeCell(cellData).place();
      }
    }

    final props = segs[6].split('');
    if (props.contains("W")) wrap = true;
  }
}

class P3Cell {
  int x, y, rot;
  String id, bg;

  Map<String, dynamic> data;
  Set<String> tags;
  int lifespan;

  P3Cell(this.id, this.x, this.y, this.rot, this.data, this.tags, this.bg, this.lifespan);

  void place() {
    grid[x][y] = Cell(id, rot, bg, lifespan, data, tags, false);
  }
}

List<String> fancySplit(String thing, String sep) {
  final chars = thing.split("");

  var depth = 0;

  var things = [""];

  var instring = false;

  var alt = false;

  for (var c in chars) {
    if (c == "\\") {
      if (alt) {
        alt = false;
        things.last += c;
      } else {
        alt = true;
      }
      continue;
    }
    if (c == "\"") {
      if (alt) {
        things.last += c;
        continue;
      } else {
        instring = !instring;
        things.last += c;
        continue;
      }
    }
    if (!instring) {
      if (c == "(" && !alt) {
        depth++;
      } else if (c == ")" && !alt) {
        depth--;
      }
    }
    if (depth == 0 && (c == sep || sep == "") && !instring && !alt) {
      if (sep == "") {
        things.last += c;
      }
      things.add("");
    } else {
      things.last += c;
    }
  }

  return things;
}

bool stringContainsAtRoot(String thing, String char) {
  final chars = thing.split("");
  var depth = 0;

  for (var c in chars) {
    if (c == "(") {
      depth++;
    } else if (c == ")") {
      depth--;
    }
    if (depth == 0 && (c == char || char == "")) {
      return true;
    }
  }

  return false;
}

class P4 {
  static final String valueString = r"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&+-.=?^{}";

  static final String base = r"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~/?:@&=+$,#()[]{}%'|^";

  static final baseEncoder = BaseXCodec(base);

  static String header = "P4;";

  static String encodeCell(int x, int y) {
    final c = grid[x][y];
    final bg = c.bg;

    final m = {
      "id": c.id,
      "rot": c.rot,
      "data": c.data,
      "tags": c.tags,
      "bg": bg,
      "lifespan": c.lifespan,
      "invisible": c.invisible,
    };

    return encodeValue(m);
  }

  static void setCell(String str, int x, int y) {
    final m = decodeValue(str) as Map<String, dynamic>;

    final c = Cell("", 0, "", 0, {}, {}, false);
    c.rot = m['rot'];
    if (m['data'] is Map<String, dynamic>) c.data = m['data']; // If it was empty, it would default to list lmao
    c.tags = m['tags'];
    c.id = m['id'];
    c.lifespan = m['lifespan'];
    c.invisible = m['invisible'] ?? false;
    final bg = m['bg'];

    c.bg = bg;
    grid[x][y] = c;
  }

  static String encodeGrid({String title = "", String description = ""}) {
    var str = header + '$title;$description;'; // Header, title and description

    str += '${encodeNum(grid.length, valueString)};';
    str += '${encodeNum(grid.first.length, valueString)};';

    final cellDataList = [];

    loopGrid(
      (cell, x, y) {
        final cstr = encodeCell(x, y);
        if (cellDataList.isNotEmpty) {
          final m = decodeValue(cellDataList.last);
          final c = m['count'];

          if (encodeValue(m['cell']) == cstr) {
            m['count'] = c + 1;
            cellDataList.last = encodeValue(m);
            return;
          }
        }
        cellDataList.add(encodeValue({"cell": cstr, "count": 1}));
      },
    );

    final cellDataStr = baseEncoder.encode(
      Uint8List.fromList(zlib.encode(
        utf8.encode(
          cellDataList.join(''),
        ),
      )),
    );

    str += '$cellDataStr;';

    final props = {};

    if (wrap) props['W'] = true;

    str += '${encodeValue(props)};';

    return str;
  }

  static void decodeString(String str) {
    str.replaceAll('\n', '');
    final segs = str.split(';');

    final width = decodeNum(segs[3], valueString);
    final height = decodeNum(segs[4], valueString);
    makeGrid(width, height);

    final rawCellDataList = fancySplit(utf8.decode(zlib.decode(baseEncoder.decode(segs[5])).toList()), '');

    while (rawCellDataList.first == "") {
      rawCellDataList.removeAt(0);
    }
    while (rawCellDataList.last == "") {
      rawCellDataList.removeLast();
    }

    final cellDataList = [];

    for (var cellData in rawCellDataList) {
      final m = decodeValue(cellData);

      final c = m['count'] ?? 1;

      for (var i = 0; i < c; i++) {
        cellDataList.add(encodeValue(m['cell']));
      }
    }

    var i = 0;

    loopGrid(
      (cell, x, y) {
        if (cellDataList.length > i) {
          setCell(cellDataList[i], x, y);
        }
        i++;
      },
    );

    final props = decodeValue(segs[6]);
    if (props['W'] != null) {
      if (props['W'] != wrap) {
        wrap = !wrap;
        for (var ws in webSockets) {
          ws.sink.add('wrap');
        }
      }
    }
  }

  static String encodeValue(dynamic value) {
    if (value is Set) {
      value = value.toList();
    }
    if (value is List) {
      return '(' + value.map<String>((e) => encodeValue(e)).join(":") + ')';
    } else if (value is Map) {
      final keys = value.isEmpty ? ["="] : [];

      value.forEach((key, value) {
        keys.add('$key=${encodeValue(value)}');
      });

      return '(${keys.join(':')})';
    }

    return value.toString();
  }

  static dynamic decodeValue(String str) {
    if (str == '{}') return <String>{};
    if (str == '()') return <String>{};
    if (int.tryParse(str) != null) {
      return int.parse(str);
    } else if (double.tryParse(str) != null) {
      return double.parse(str);
    } else if (str == "true" || str == "false") {
      return str == "true";
    } else if (str.startsWith('(') && str.endsWith(')')) {
      final s = str.substring(1, str.length - 1);

      if (stringContainsAtRoot(s, '=')) {
        // It is a map, decode it as a map
        final map = <String, dynamic>{};

        final parts = fancySplit(s, ':');

        for (var part in parts) {
          final kv = fancySplit(part, '=');
          final k = kv[0];
          final v = decodeValue(kv[1]);

          map[k] = v;
        }
        return map;
      } else {
        // It is a list, decode it as a list
        return fancySplit(s, ':').map<dynamic>((e) => decodeValue(e)).toSet();
      }
    }

    return str;
  }
}

typedef SavingFormat = P6;

class P5 {
  static final String valueString = r"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-.={}";

  static final String base = r"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

  static final baseEncoder = BaseXCodec(base);

  static String header = "P5;";

  static String encodeCell(int x, int y) {
    final c = grid[x][y];
    final bg = c.bg;

    final m = {
      "id": c.id,
      "rot": c.rot,
      "bg": bg,
    };

    if (c.data.isNotEmpty) m['data'] = c.data;
    if (c.tags.isNotEmpty) m['tags'] = c.tags;
    if (c.lifespan != 0) m['lifespan'] = c.lifespan;
    if (c.invisible) m['invisible'] = true;

    return TPCML.encodeValue(m);
  }

  static void setCell(String str, int x, int y) {
    final m = TPCML.decodeValue(str);

    final c = Cell(m['id'] ?? "empty", (m['rot'] ?? 0).toInt(), m['bg'] ?? "empty", (m['lifespan'] ?? 0).toInt(), {}, {}, m['invisible'] ?? false);
    c.data = m['data'] ?? {};
    c.tags = {};
    (m['tags'] ?? []).forEach((v) => c.tags.add(v.toString()));

    grid[x][y] = c;
  }

  static String encodeGrid() {
    var str = header + ';;'; // Header, title and description

    str += '${encodeNum(grid.length, valueString)};';
    str += '${encodeNum(grid.first.length, valueString)};';

    final cellDataList = [];

    loopGrid(
      (cell, x, y) {
        final cstr = encodeCell(x, y);
        if (cellDataList.isNotEmpty) {
          final m = TPCML.decodeValue(cellDataList.last);
          final c = m['count'];

          if (TPCML.encodeValue(m['cell']) == cstr) {
            m['count'] = c + 1;
            cellDataList.last = TPCML.encodeValue(m);
            return;
          }
        }
        cellDataList.add(TPCML.encodeValue({"cell": cstr, "count": 1}));
      },
    );

    final cellDataStr = baseEncoder.encode(
      Uint8List.fromList(zlib.encode(
        utf8.encode(
          cellDataList.join(''),
        ),
      )),
    );

    str += '$cellDataStr;';

    final props = {};

    if (wrap) props['W'] = true;

    final memoryStr = <String, dynamic>{};

    memory.forEach((channelID, channel) {
      memoryStr[channelID.toString()] = <String, dynamic>{};

      channel.forEach((idx, value) {
        memoryStr[idx.toString()] = value;
      });
    });

    if (memoryStr.isNotEmpty) {
      props['memory'] = memoryStr;
    }

    str += '${TPCML.encodeValue(props)};';

    return str;
  }

  static void decodeString(String str, [bool handleCustomProps = true]) {
    final segs = str.split(';');

    final width = decodeNum(segs[3], valueString);
    final height = decodeNum(segs[4], valueString);

    makeGrid(width, height);

    final rawCellDataList = fancySplit(utf8.decode(zlib.decode(baseEncoder.decode(segs[5])).toList()), '');

    while (rawCellDataList.first == "") {
      rawCellDataList.removeAt(0);
    }
    while (rawCellDataList.last == "") {
      rawCellDataList.removeLast();
    }

    final cellDataList = [];

    for (var cellData in rawCellDataList) {
      final m = TPCML.decodeValue(cellData);

      final c = m['count'] ?? 1;

      for (var i = 0; i < c; i++) {
        cellDataList.add(TPCML.encodeValue(m['cell']));
      }
    }

    var i = 0;

    loopGrid(
      (cell, x, y) {
        if (cellDataList.length > i) {
          setCell(cellDataList[i], x, y);
        }
        i++;
      },
    );

    final props = TPCML.decodeValue(segs[6]);
    wrap = props['W'] ?? false;

    if (handleCustomProps) {
      // We gotta decode le' RAM stick
      if (props['memory'] != null) {
        final m = props['memory'] as Map;
        m.forEach((key, value) {
          final c = <int, num>{};

          value.forEach((key, value) {
            c[int.parse(key)] = TPCML.decodeValue(value);
          });

          memory[int.parse(key)] = c;
        });
      }
    }
  }
}

class TPCML {
  static String encodeValue(dynamic value) {
    if (value is Set) {
      return 's(' + value.map<String>((e) => encodeValue(e)).join(":") + ')';
    }
    if (value is List) {
      return 'l(' + value.map<String>((e) => encodeValue(e)).join(":") + ')';
    } else if (value is Map) {
      final keys = value.isEmpty ? ["="] : [];

      value.forEach((key, value) {
        keys.add('"$key"=${encodeValue(value)}');
      });

      return 'm(${keys.join(':')})';
    }

    if (value == double.infinity) {
      return "inf";
    }
    if (value == double.nan) {
      return "nan";
    }
    if (value == double.negativeInfinity) {
      return "-inf";
    }

    if (value is int) {
      return "ni$value";
    }
    if (value is double) {
      return "nd$value";
    }
    if (value is String) {
      var v = "";
      var chars = value.split('');

      for (var char in chars) {
        if (char == "\\") {
          v += "\\";
        } else if (char == "\"") {
          v += "\"";
        } else {
          v += char;
        }
      }
      return '"$v"';
    }

    return value.toString();
  }

  static dynamic decodeValue(String str) {
    if (str == '{}') return <String>{};
    if (str == '()') return <String>{};
    if (str == 's()') return <String>{};
    if (str == 'l()') return <String>[];
    if (str == 'm()') return <String, dynamic>{};
    if (str == "inf") return double.infinity;
    if (str == "nan") return double.nan;
    if (str == "-inf") return double.negativeInfinity;
    if (int.tryParse(str) != null) {
      return int.parse(str);
    } else if (double.tryParse(str) != null) {
      return double.parse(str);
    } else if (str == "true" || str == "false") {
      return str == "true";
    } else if (str.startsWith('l(') && str.endsWith(')')) {
      final s = str.substring(2, str.length - 1);
      return fancySplit(s, ':').map<dynamic>((e) => decodeValue(e)).toList();
    } else if (str.startsWith('s(') && str.endsWith(')')) {
      final s = str.substring(2, str.length - 1);
      return fancySplit(s, ':').map<dynamic>((e) => decodeValue(e)).toSet();
    } else if (str.startsWith('m(') && str.endsWith(')')) {
      final s = str.substring(2, str.length - 1);
      // It is a map, decode it as a map
      final map = <String, dynamic>{};

      final parts = fancySplit(s, ':');

      for (var part in parts) {
        final kv = fancySplit(part, '=');
        final k = kv[0].startsWith('"') && kv[0].endsWith('"') ? kv[0].substring(1, kv[0].length - 1) : kv[0];
        final v = decodeValue(kv[1]);

        map[k] = v;
      }
      return map;
    } else if (str.startsWith('(') && str.endsWith(')')) {
      final s = str.substring(1, str.length - 1);

      if (stringContainsAtRoot(s, '=')) {
        // It is a map, decode it as a map
        final map = <String, dynamic>{};

        final parts = fancySplit(s, ':');

        for (var part in parts) {
          final kv = fancySplit(part, '=');
          final k = kv[0];
          final v = decodeValue(kv[1]);

          map[k] = v;
        }
        return map;
      } else {
        // It is a list, decode it as a list
        return fancySplit(s, ':').map<dynamic>((e) => decodeValue(e)).toSet();
      }
    } else if (str.startsWith('"') && str.endsWith('"')) {
      final chars = str.substring(1, str.length - 1).split('');

      var s = "";
      var alt = false;

      for (var char in chars) {
        if (char == "\\") {
          if (alt) {
            s += "\\";
            alt = false;
          } else {
            alt = true;
          }
        } else {
          if (alt) {
            if (char == "\"") {
              s += "\"";
            }
          } else {
            s += char;
          }
        }
      }

      if (alt) s += "\\";

      return s;
    } else if (str.startsWith('ni') && int.tryParse(str.substring(2)) != null) {
      return int.parse(str.substring(2));
    } else if (str.startsWith('nd') && double.tryParse(str.substring(2)) != null) {
      return double.parse(str.substring(2));
    }

    return str;
  }
}

class P6 {
  static String header = "P6;";

  static final String base = r"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

  static dynamic encodeCell(Cell cell, String bg, int count) {
    var isSimple = true;

    if (cell.data.isNotEmpty) isSimple = false;
    if (cell.invisible) isSimple = false;

    if (isSimple) {
      if (cell.id == "empty" && bg == "empty") {
        return count;
      }

      return "${cell.id}|${cell.rot}|$bg|${encodeNum(cell.lifespan, base)}|${encodeNum(count, base)}";
    } else {
      return [cell.id, cell.rot, bg, encodeNum(cell.lifespan, base), cell.data.isEmpty ? 0 : cell.data, cell.invisible ? 1 : 0, encodeNum(count, base)];
    }
  }

  static List decodeCell(dynamic value) {
    if (value is String) {
      final segs = value.split("|");

      final id = segs[0];
      final rot = int.parse(segs[1]);
      final bg = segs[2];
      final lifespan = decodeNum(segs[3], base);
      final count = decodeNum(segs[4], base);

      final cell = Cell(id, rot, bg, lifespan, {}, {}, false);

      return [cell, bg, count];
    } else if (value is num) {
      final count = value.toInt();

      return [Cell("empty", 0, "empty", 0, {}, {}, false), "empty", count];
    } else if (value is List) {
      final id = value[0];
      final rot = value[1];
      final bg = value[2];
      final lifespan = decodeNum(value[3], base);
      final Map<String, dynamic> data = value[4] is Map ? value[4] : <String, dynamic>{};
      final invisible = value[5] == 1;
      final count = decodeNum(value[6], base);

      final cell = Cell(id, rot, bg, lifespan, data, {}, invisible);

      return [cell, bg, count];
    }

    throw "P6 Error: No parser specified for $value";
  }

  static String encodeGrid() {
    var str = header + ";;";

    str += "${encodeNum(grid.length, base)};";
    str += grid.length == grid.first.length ? "<;" : "${encodeNum(grid.first.length, base)};";

    final rawCellList = [];
    final gridData = <String, dynamic>{};

    loopGrid(
      (cell, x, y) {
        rawCellList.add([cell, cell.bg, 1]);
      },
    );

    final cellList = [];

    // Basic row compression algorithm
    for (var rawCellData in rawCellList) {
      if (cellList.isEmpty) {
        cellList.add(rawCellData);
      } else {
        final old = cellList.last;

        if (old[0] == rawCellData[0] && old[1] == rawCellData[1]) {
          old[2]++;
        } else {
          cellList.add(rawCellData);
        }
      }
    }

    final encodedList = [];

    for (var compressedCellList in cellList) {
      encodedList.add(
        encodeCell(
          compressedCellList[0] as Cell,
          compressedCellList[1] as String,
          (compressedCellList[2] as num).toInt(),
        ),
      );
    }

    if (encodedList.isNotEmpty) {
      if (encodedList.last is num) {
        encodedList.removeLast(); // If last thing is just a bunch of empty cells, we don't care
      }
    }

    var encodedStr = jsonEncode(encodedList);
    encodedStr = encodedStr.substring(1, encodedStr.length - 1);

    encodedStr = base64.encode(
      Uint8List.fromList(
        zlib.encode(
          utf8.encode(encodedStr),
        ),
      ),
    );

    if (encodedList.isEmpty) encodedStr = "";

    str += "$encodedStr;";

    if (wrap) gridData["W"] = true;

    final memMap = <String, dynamic>{};

    memory.forEach((channel, memRow) {
      final mem = <int, num>{};

      memRow.forEach((id, val) {
        mem[id] = val;
      });

      memMap[channel.toString()] = mem;
    });

    if (memMap.isNotEmpty) gridData["M"] = memMap;

    str += "${gridData.isEmpty ? "" : base64.encode(
        Uint8List.fromList(
          zlib.encode(
            utf8.encode(
              jsonEncode(gridData),
            ),
          ),
        ),
      )};";

    while (str.endsWith(';;')) {
      str = str.substring(0, str.length - 1);
    }
    return str;
  }

  static void decodeString(String str, [bool handleCustomProps = true]) {
    try {
      final segs = str.split(';');

      while (segs.length < 7) {
        segs.add("");
      }

      final width = decodeNum(segs[3], base);
      final height = segs[4] == "<" ? width : decodeNum(segs[4], base);

      makeGrid(width, height);

      final cellList = segs[5] == ""
          ? []
          : jsonDecode(
              "[" +
                  utf8
                      .decode(
                        zlib.decode(
                          base64.decode(segs[5]),
                        ),
                      )
                      .trim() +
                  "]",
            ) as List;

      var i = 0;

      for (var cellData in cellList) {
        final cellInfo = decodeCell(cellData);

        final cell = cellInfo[0] as Cell;
        final bg = cellInfo[1] as String;
        final count = (cellInfo[2] as num).toInt();

        for (var c = 0; c < count; c++) {
          final x = i ~/ grid.first.length;
          final y = i % grid.length;

          grid[x][y] = cell.copy;
          grid[x][y].bg = bg;

          i++;
        }
      }

      final gridData = segs[6] == ""
          ? <String, dynamic>{}
          : jsonDecode(
              utf8.decode(
                zlib.decode(
                  base64.decode(segs[6]),
                ),
              ),
            ) as Map<String, dynamic>;

      wrap = gridData["W"] == 1;
      if (gridData["M"] != null) {
        final memMap = gridData["M"] as Map<String, dynamic>;

        memMap.forEach((channel, memRow) {
          memory[int.parse(channel)] = HashMap<int, num>();

          memRow.forEach((id, val) {
            memory[int.parse(channel)]![int.parse(id)] = val;
          });
        });
      }
    } catch (e, st) {
      print(e);
      print(st);
    }
  }
}
