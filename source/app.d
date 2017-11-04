import std.stdio;
import gfm.math;
import std.conv;
import std.string;

import sdl;
import types;

struct Door {
	vec2i[2] room; // Each door connects two rooms
	vec2i worldPos;
}

struct Room {
	vec2i id;
	vec2i position;
	enum vec2i size = vec2i(64, 64);

	Door[] doors;
	size_t[] visibleRooms;
	vec2i[] canGoto;

	void findPotentialDoors() {

	}

	void explore(vec2i p, const ref Tile[][] map, const ref vec2i mapSize) {
		import std.algorithm : filter, canFind;
		import std.range : chain;

		vec2i pos = position + p;

		Door[] toBeExplored;

		foreach (door; doors.chain(toBeExplored)) {
			if (validPath(pos, door.worldPos, map)) {
				writeln("Pos: ", p, " can reach ", door.worldPos);
				canGoto ~= door.worldPos;
			}
		}
	}
}

int main(string[] args) {
	SDL sdl = new SDL;
	scope (exit)
		sdl.destroy;

	enum roomSize = vec2i(64);
	Tile[][] map;
	Room[] rooms;
	vec2i mapSize;
	vec2i roomCount;

	{ // Create tiles
		SDL_Surface* mapSurface = IMG_Load("map.png");
		assert(mapSurface, "map.png is missing");
		scope (exit)
			SDL_FreeSurface(mapSurface);
		mapSize = vec2i(mapSurface.w, mapSurface.h);
		roomCount = vec2i(mapSize.x / roomSize.x, mapSize.y / roomSize.y);
		assert(mapSurface.format.format == SDL_PIXELFORMAT_RGBA32, "Wrong format");

		writeln("Map size: ", mapSize.x, "x", mapSize.y);
		foreach (y; 0 .. mapSize.y) {
			Tile[] xRow;
			foreach (x; 0 .. mapSize.x)
				xRow ~= (cast(Color*)mapSurface.pixels)[y * mapSurface.w + x].toTile;

			map ~= xRow;
		}
	}

	{ // Create rooms
		foreach (y; 0 .. roomCount.y)
			foreach (x; 0 .. roomCount.x)
				rooms ~= Room(vec2i(x, y), vec2i(x * roomSize.x, y * roomSize.y));
	}
	Window w = new Window(mapSize.x, mapSize.y);
	scope (exit)
		w.destroy;

	size_t roomIdx;
	vec2i explorePos;
	bool exploring = true;
	bool first = true;
	while (sdl.doEvent(w)) {
		const size_t step = 2;
		if (!first) {
			const auto start = SDL_GetPerformanceCounter();
			while (((SDL_GetPerformanceCounter() - start) * 100) / SDL_GetPerformanceFrequency() < 1)
				if (exploring) {
					if (explorePos.x >= roomSize.x) {
						explorePos.y += step;
						explorePos.x = 0;
					}

					if (explorePos.y >= roomSize.y) {
						explorePos.y = 0;
						roomIdx++;
					}

					import std.format : format;

					if (roomIdx < rooms.length) {
						rooms[roomIdx].explore(explorePos, map, mapSize);
						explorePos.x += step;

						string title = format("Exploring Room (%dx%d), Pixel (%dx%d)", roomIdx % roomCount.x, roomIdx / roomCount.x,
								explorePos.x, explorePos.y);
						SDL_SetWindowTitle(w.window, title.toStringz);
					} else {
						exploring = false;
						SDL_SetWindowTitle(w.window, "Exploring done!");
					}
				}
		} else
			first = false;

		w.reset();
		SDL_SetRenderDrawColor(w.renderer, 0, 0, 0, 255);
		SDL_RenderClear(w.renderer);

		const size_t curPosIdx = explorePos.y * roomSize.x + explorePos.x;
		foreach (int y, const ref Tile[] xRow; map)
			foreach (int x, const ref Tile tile; xRow) {
				auto c = tile.toColor;
				if (tile == Tile.Air) {
					const vec2i myRoomPos = vec2i(x / roomSize.x, y / roomSize.y);
					const size_t myRoomIdx = myRoomPos.y * roomCount.y + myRoomPos.x;
					if (myRoomIdx <= roomIdx) {
						const size_t myPosIdx = (y % roomSize.y) * roomSize.x + x % roomSize.x;
						if (myRoomIdx == roomIdx && myPosIdx >= curPosIdx)
							c = Color(cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: TODO
						else
							c = Color(cast(ubyte)0x00, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: Done
					}
				}
				SDL_SetRenderDrawColor(w.renderer, c.x, c.y, c.z, c.w);
				SDL_RenderDrawPoint(w.renderer, x, y);
			}

		SDL_RenderPresent(w.renderer);
	}

	return 0;
}
