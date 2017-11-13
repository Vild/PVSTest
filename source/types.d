module types;

import gfm.math;

alias Color = Vector!(ubyte, 4);

enum Tile {
	Air,
	Wall,
	Portal
}

Tile toTile(Color c) {
	if (c == Color(cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0xFF))
		return Tile.Air;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF))
		return Tile.Wall;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF))
		return Tile.Portal;
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
	case Tile.Portal:
		return Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF);

	default:
		import std.stdio : stderr;

		stderr.writeln("Tile: ", t, " is undefined!");
		assert(0);
	}
}

bool isSolid(Tile t) pure nothrow @nogc {
	return t != Tile.Air && t != Tile.Portal;
}

//Bresenham's line algorithm
bool validPath(vec2i start, vec2i end, const ref Tile[][] map) {
	import std.math : abs;

	immutable int dx = end.x - start.x;
	immutable int ix = (dx > 0) - (dx < 0);
	immutable size_t dx2 = abs(dx) * 2;
	immutable int dy = end.y - start.y;
	immutable int iy = (dy > 0) - (dy < 0);
	immutable size_t dy2 = abs(dy) * 2;

	vec2i pos = start;
	if (map[pos.y][pos.x].isSolid)
		return false;

	if (dx2 >= dy2) {
		long error = cast(long)(dy2 - (dx2 / 2));
		while (pos.x != end.x) {
			if (error >= 0 && (error || (ix > 0))) {
				error -= dx2;
				pos.y += iy;
			}

			error += dy2;
			pos.x += ix;
			if (map[pos.y][pos.x].isSolid)
				return false;
		}
	} else {
		long error = cast(long)(dx2 - (dy2 / 2));
		while (pos.y != end.y) {
			if (error >= 0 && (error || (iy > 0))) {
				error -= dy2;
				pos.x += ix;
			}

			error += dx2;
			pos.y += iy;
			if (map[pos.y][pos.x].isSolid)
				return false;
		}
	}
	return true;
}

import sdl;

bool validPathRender(vec2i start, vec2i end, const ref Tile[][] map, Window w) {
	import std.math : abs;

	immutable int dx = end.x - start.x;
	immutable int ix = (dx > 0) - (dx < 0);
	immutable size_t dx2 = abs(dx) * 2;
	int dy = end.y - start.y;
	immutable int iy = (dy > 0) - (dy < 0);
	immutable size_t dy2 = abs(dy) * 2;

	bool result = true;
	vec2i pos = start;
	SDL_SetRenderDrawColor(w.renderer, cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0x10);

	if (map[pos.y][pos.x].isSolid) {
		SDL_SetRenderDrawColor(w.renderer, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x10);
		result = false;
	}

	SDL_RenderDrawPoint(w.renderer, pos.x, pos.y);

	if (dx2 >= dy2) {
		long error = cast(long)(dy2 - (dx2 / 2));
		while (pos.x != end.x) {
			if (error >= 0 && (error || (ix > 0))) {
				error -= dx2;
				pos.y += iy;
			}

			error += dy2;
			pos.x += ix;
			if (map[pos.y][pos.x].isSolid && result) {
				SDL_SetRenderDrawColor(w.renderer, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x10);
				result = false;
			}
			SDL_RenderDrawPoint(w.renderer, pos.x, pos.y);
		}
	} else {
		long error = cast(long)(dx2 - (dy2 / 2));
		while (pos.y != end.y) {
			if (error >= 0 && (error || (iy > 0))) {
				error -= dy2;
				pos.x += ix;
			}

			error += dx2;
			pos.y += iy;
			if (map[pos.y][pos.x].isSolid && result) {
				SDL_SetRenderDrawColor(w.renderer, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x10);
				result = false;
			}
			SDL_RenderDrawPoint(w.renderer, pos.x, pos.y);
		}
	}
	return result;
}

enum Direction {
	posX,
	negX,
	posY,
	negY
}
