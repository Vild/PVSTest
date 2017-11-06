import std.stdio;
import gfm.math;
import std.conv;
import std.string;

import sdl;
import types;

alias DoorIdx = vec2i;
alias RoomIdx = vec2i;

struct Door {
	DoorIdx id;
	vec4i worldRect;
	vec2i[2] room; // Each door connects two rooms
}

struct Room {
	RoomIdx id;
	vec2i position;
	enum vec2i size = vec2i(64, 64);

	DoorIdx[] doors;
	size_t[] visibleRooms;
	vec2i[] canGoto;

	void findPotentialDoors(ref Door[DoorIdx] globalDoors, ref Room[RoomIdx] rooms, const ref Tile[][] map, vec2i mapSize) {
		void walk(vec2i pos, vec2i dir, vec2i outwards) {
			enum State {
				LookingForDoor,
				BuildingDoor
			}

			State state = State.LookingForDoor;
			Door door;
			writeln("Walking ", pos, " to ", pos + dir * (size - 1 /*aka 0-63*/ ), ". Dir: ", dir, " Outwards: ", outwards);

			void finishDoor() {
				// Expand door
				writeln("outwards.x < 0 || outwards.y < 0: ", outwards.x < 0, " || ", outwards.y < 0);
				if (outwards.x < 0 || outwards.y < 0) {
					door.id += outwards;
					door.worldRect.x += outwards.x;
					door.worldRect.y += outwards.y;
					door.worldRect.z -= outwards.x;
					door.worldRect.w -= outwards.y;
				} else {
					door.worldRect.z += outwards.x;
					door.worldRect.w += outwards.y;
				}

				// Verify
				for (size_t y; y < door.worldRect.w; y++)
					for (size_t x; x < door.worldRect.z; x++)
						if (map[y][x] == Tile.Door) {
							stderr.writeln("!!!!!MAP HAS A LEAK (Air instead of door)!!!!! (", x, ",", y);
							assert(0);
						}

				writeln("door.id: ", door.id);
				writeln("door.worldRect: ", door.worldRect);
				door.room[0] = (door.worldRect.xy / size);
				door.room[1] = ((door.worldRect.xy + door.worldRect.zw) / size);

				globalDoors[door.id] = door;
				rooms[door.room[0]].doors ~= door.id;
				rooms[door.room[1]].doors ~= door.id;

				writeln("**Finalized**: ", door);
				state = State.LookingForDoor;
				door = Door.init;
			}

			for (auto walker = pos; walker != pos + dir * size; walker += dir) {
				/*if (walker.x < 0 || walker.y < 0 || walker.x >= mapSize.x || walker.y >= mapSize.y)
					continue;*/
				switch (map[walker.y][walker.x]) {
				case Tile.Door:
					if (state == State.LookingForDoor) {
						writeln("Making a new door: ", walker);
						door.id = walker;
						door.worldRect = vec4i(walker, 1, 1);
						state = State.BuildingDoor;
					} else {
						writeln("\tAdding door block: ", walker);
						door.worldRect.z += dir.x;
						door.worldRect.w += dir.y;
					}
					break;
				case Tile.Wall:
					if (state == State.BuildingDoor)
						finishDoor();
					break;
				default:
					stderr.writeln("!!!!!MAP HAS A LEAK (Air instead of door or wall)!!!!! ", walker);
					assert(0);
				}
			}
			if (state == State.BuildingDoor)
				finishDoor();
		}

		walk(position, vec2i(1, 0), vec2i(0, -1)); // Top
		walk(position + vec2i(0, size.y - 1), vec2i(1, 0), vec2i(0, 1)); // Bottom

		walk(position, vec2i(0, 1), vec2i(-1, 0)); // Left
		walk(position + vec2i(size.x - 1, 0), vec2i(0, 1), vec2i(1, 0)); // Right
	}

	void explore(vec2i p, const ref Door[DoorIdx] globalDoors, const ref Tile[][] map) {
		import std.algorithm : filter, canFind;
		import std.range : chain;

		vec2i pos = position + p;

		DoorIdx[] toBeExplored;

		foreach (doorId; doors.chain(toBeExplored)) {
			auto door = globalDoors[doorId];
			/*if (validPath(pos, door.worldPos, map)) {
				writeln("Pos: ", p, " can reach ", door.worldPos);
				canGoto ~= door.worldPos;
			}*/
		}
	}
}

int main(string[] args) {
	SDL sdl = new SDL;
	scope (exit)
		sdl.destroy;

	enum roomSize = vec2i(64);
	Tile[][] map;
	Door[DoorIdx] doors;
	Room[RoomIdx] rooms;
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
			foreach (x; 0 .. roomCount.x) {
				auto r = Room(RoomIdx(x, y), vec2i(x * roomSize.x, y * roomSize.y));
				rooms[r.id] = r;
			}
	}

	{ // Find doors
		foreach (r; rooms)
			r.findPotentialDoors(doors, rooms, map, mapSize);
	}

	{ // Remove dups
		import std.algorithm;

		alias vecCmp = (a, b) pure{
			if (a.y < b.y)
				return false;
			else if (a.y == b.y)
				return b.x - a.x > 0;
			else
				return true;
		};

		foreach (RoomIdx idx, ref Room room; rooms)
			room.doors.sort!vecCmp.uniq.copy(room.doors);
	}

	Window w = new Window(mapSize.x, mapSize.y);
	scope (exit)
		w.destroy;

	size_t roomIdx;
	vec2i explorePos;
	bool exploring = true;
	bool first = true;
	auto roomsRange = rooms.byValue;
	Room* room = &roomsRange.front();
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
						roomsRange.popFront();
						room = roomsRange.empty ? null : &roomsRange.front();
					}

					import std.format : format;

					if (!roomsRange.empty) {
						room.explore(explorePos, doors, map);
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

		{
			Room* r = &rooms[RoomIdx(cast(int)(roomIdx % roomCount.x), cast(int)(roomIdx / roomCount.x))];
			foreach (doorID; r.doors) {
				Door* d = &doors[doorID];

				for (size_t y; y < d.worldRect.w; y++)
					for (size_t x; x < d.worldRect.z; x++) {
						SDL_SetRenderDrawColor(w.renderer, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(w.renderer, cast(int)(d.worldRect.x + x), cast(int)(d.worldRect.y + y));
					}
			}
		}

		SDL_RenderPresent(w.renderer);
	}

	{
		import core.stdc.stdlib : exit, EXIT_SUCCESS;

		exit(EXIT_SUCCESS);
	}
	return 0;
}
