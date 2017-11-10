module room;

import std.stdio;
import gfm.math;
import std.bitmanip;

import door;
import types;

alias RoomIdx = vec2i;

size_t roomID(in RoomIdx id, vec2i roomCount) {
	return id.y * roomCount.x + id.x;
}

struct Room {
	RoomIdx id;
	vec2i position;
	enum vec2i size = vec2i(64, 64);

	DoorIdx[] doors;

	void findPotentialDoors(ref Door[DoorIdx] globalDoors, ref Room[RoomIdx] rooms, const ref Tile[][] map, vec2i mapSize) {
		void walk(vec2i pos, vec2i dir, vec2i outwards) {
			enum State {
				LookingForDoor,
				BuildingDoor
			}

			State state = State.LookingForDoor;
			Door door;
			//write("\rWalking ", pos, " to ", pos + dir * (size - 1 /*aka 0-63*/ ), ". Dir: ", dir, " Outwards: ", outwards);

			void finishDoor() {
				// Expand door
				if (outwards.x < 0 || outwards.y < 0) {
					door.id.x += outwards.x;
					door.id.y += outwards.y;
					door.id.z -= outwards.x;
					door.id.w -= outwards.y;
				} else {
					door.id.z += outwards.x;
					door.id.w += outwards.y;
				}

				// Verify expansion
				for (size_t y; y < door.id.w; y++)
					for (size_t x; x < door.id.z; x++)
						if (map[y][x] == Tile.Door) {
							stderr.writeln("\x1b[93;41mMAP HAS A LEAK (Air instead of door) [", x, ", ", y, "]\x1b[0m");
							assert(0);
						}

				door.rooms[0] = (door.id.xy / size);
				door.rooms[1] = ((door.id.xy + outwards) / size);

				globalDoors[door.id] = door;
				rooms[door.rooms[0]].doors ~= door.id;
				rooms[door.rooms[1]].doors ~= door.id;

				writeln("\x1b[1;32mFinalized: ", door, "\x1b[0m");
				state = State.LookingForDoor;
				door = Door.init;
			}

			for (auto walker = pos; walker != pos + dir * size; walker += dir) {
				/*if (walker.x < 0 || walker.y < 0 || walker.x >= mapSize.x || walker.y >= mapSize.y)
					continue;*/
				switch (map[walker.y][walker.x]) {
				case Tile.Door:
					if (state == State.LookingForDoor) {
						//writeln("\tMaking a new door: ", walker);
						door.id = vec4i(walker, 1, 1);
						state = State.BuildingDoor;
					} else {
						door.id.z += dir.x;
						door.id.w += dir.y;
					}
					break;
				case Tile.Wall:
					if (state == State.BuildingDoor)
						finishDoor();
					break;
				default:
					stderr.writeln("\x1b[93;41mMAP HAS A LEAK (Air instead of door or wall) ", walker, "\x1b[0m");
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
}
