import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Cell {
  String id;
  int rot;
  String bg;
  int lifespan = 0;
  Map<String, dynamic> data;
  List<String> tags;

  Cell(this.id, this.rot, this.bg, this.lifespan, this.data, this.tags);

  Cell get copy {
    return Cell(id, rot, bg, lifespan, Map.from(data), List.from(tags));
  }

  @override
  bool operator ==(Object other) {
    if (other is Cell) {
      return (id == other.id && rot == other.rot && bg == other.bg);
    } else {
      return false;
    }
  }

  @override
  int get hashCode => (rot * 4 + bg.hashCode + 20000 + rot.hashCode + 10000);
}

late List<List<Cell>> grid;

bool wrap = false;

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
      var iN = min(n ~/ pow(valueString.length, cellBase - 1 - i),
          valueString.length - 1);
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
      grid.last.add(Cell("empty", 0, "empty", 0, {}, []));
    }
  }
}

int decodeNum(String n, String valueString) {
  var numb = 0;
  for (var i = 0; i < n.length; i++) {
    final char = n[i];
    numb += valueString.indexOf(char) *
        pow(valueString.length, n.length - 1 - i).toInt();
  }
  return numb;
}

void loadStr(String str) {
  if (str.startsWith('P2;')) {
    return P2.decodeGrid(str);
  }
  if (str.startsWith('P3;')) {
    return P3.decodeString(str);
  }
}

class P2 {
  static String valueString =
      "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM[]{}()-_+=<>./?:'";

  static String encodeCell(Cell cell, Set<String> cellTable) {
    return encodeNum(
      cellTable.toList().indexOf(cell.id) * 4 + cell.rot,
      valueString,
    );
  }

  static Cell decodeCell(String cell, List<String> cellTable) {
    final n = decodeNum(cell, valueString);
    final c = Cell(cellTable[n ~/ 4], n % 4, "empty", 0, {}, []);

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
  static String valueString =
      r"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&+-.=?^{}";

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

    final cellDataStr = segs[5] == "eJwDAAAAAAE="
        ? ""
        : utf8.decode(zlib.decode(base64.decode(segs[5])));

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

  P3Cell(this.id, this.x, this.y, this.rot, this.data, this.tags, this.bg,
      this.lifespan);

  void place() {
    grid[x][y] = Cell(id, rot, bg, lifespan, data, tags.toList());
  }
}
