module types;

import gfm.math;

alias Color = Vector!(ubyte, 4);

enum Tile {
	Air,
	Wall,
	Door
}

Tile toTile(Color c) {
	if (c == Color(cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0xFF))
		return Tile.Air;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF))
		return Tile.Wall;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF))
		return Tile.Door;
	else {
		import std.stdio : stderr;

		stderr.writeln("Color: ", c, " is undefined!");
		assert(0);
	}
}

Color toColor(Tile t) {
	switch (t) {
	case Tile.Air:
		return Color(cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0xFF);
	case Tile.Wall:
		return Color(cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF);
	case Tile.Door:
		return Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF);

	default:
		import std.stdio : stderr;

		stderr.writeln("Tile: ", t, " is undefined!");
		assert(0);
	}
}

bool isSolid(Tile t) {
	return t == Tile.Wall;
}

//Bresenham's line algorithm
bool validPath(vec2i start, vec2i end, const ref Tile[][] map) {
	import std.math : fabs, signbit;

	if (start == end)
		return true;

	int dX = end.x - start.x;
	int dY = end.y - start.y;

	int sign = dY < 0 ? -1 : 1;

	float deltaErr = dX ? fabs(dY / (1.0f * dX)) : 0;
	float err = 0;

	int y = start.y;
	foreach (int x; start.x .. end.x) {
		if (map[y][x].isSolid)
			return false;
		err += deltaErr;
		while (err >= 0.5) {
			y += sign;
			err -= 1;
		}
	}
	return true;
}

enum Direction {
	posX,
	negX,
	posY,
	negY
}
