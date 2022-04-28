import 'dart:convert';
import 'dart:io';
import 'dart:math';

class Cell {
  String id;
  int rot;
  String bg;

  Cell(this.id, this.rot, this.bg);

  Cell get copy {
    return Cell(id, rot, bg);
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

void loopGrid(Function(Cell) callback) {
  for (var x = 0; x < grid.length; x++) {
    for (var y = 0; y < grid[x].length; y++) {
      callback(grid[x][y]);
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
      grid.last.add(Cell("empty", 0, "empty"));
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
    final c = Cell(cellTable[n ~/ 4], n % 4, "empty");

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
      (cell) {
        cellTable.add(cell.id);
      },
    );

    str += "${cellTable.join(',')};";

    final cells = [];

    loopGrid(
      (cell) {
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
