module room;

import std.stdio;
import gfm.math;
import std.bitmanip;

import portal;
import types;

alias RoomIdx = vec2i;

size_t roomID(in RoomIdx id, vec2i roomCount) {
	return id.y * roomCount.x + id.x;
}

size_t[vec4i] lookup;

struct Room {
	RoomIdx id;
	vec2i position;
	enum vec2i size = vec2i(64, 64);

	PortalIdx[] portals;

	void findPortals(ref Portal[PortalIdx] globalPortals, ref Room[RoomIdx] rooms, const ref Tile[][] map, const ref vec2i mapSize, const ref vec2i roomCount) {
		void walk(vec2i pos, vec2i dir, vec2i outwards) {
			enum State {
				LookingForPortal,
				BuildingPortal
			}

			State state = State.LookingForPortal;
			Portal portal;
			//write("\rWalking ", pos, " to ", pos + dir * (size - 1 /*aka 0-63*/ ), ". Dir: ", dir, " Outwards: ", outwards);

			void finishPortal() {
				// Expand portal
				if (outwards.x < 0 || outwards.y < 0) {
					portal.pos.x += outwards.x;
					portal.pos.y += outwards.y;
					portal.pos.z -= outwards.x;
					portal.pos.w -= outwards.y;
				} else {
					portal.pos.z += outwards.x;
					portal.pos.w += outwards.y;
				}

				if (portal.pos in lookup)
					return;

				// Verify expansion
				for (size_t y; y < portal.pos.w; y++)
					for (size_t x; x < portal.pos.z; x++)
						if (map[y][x] == Tile.Portal) {
							stderr.writeln("\x1b[93;41mMAP HAS A LEAK (Air instead of portal) [", x, ", ", y, "]\x1b[0m");
							assert(0);
						}

				portal.rooms[0] = (portal.pos.xy / size);
				portal.rooms[1] = ((portal.pos.xy + outwards) / size);

				portal.id = portalCounter++;
				lookup[portal.pos] = portal.id;
				globalPortals[portal.id] = portal;
				rooms[portal.rooms[0]].portals ~= portal.id;
				rooms[portal.rooms[1]].portals ~= portal.id;

				writeln("\x1b[1;32mFinalized: ", portal, "\x1b[0m");
				state = State.LookingForPortal;
				portal = Portal.init;
			}

			for (auto walker = pos; walker != pos + dir * size; walker += dir) {
				/*if (walker.x < 0 || walker.y < 0 || walker.x >= mapSize.x || walker.y >= mapSize.y)
					continue;*/
				switch (map[walker.y][walker.x]) {
				case Tile.Portal:
					if (state == State.LookingForPortal) {
						//writeln("\tMaking a new portal: ", walker);
						portal.pos = vec4i(walker, 1, 1);
						state = State.BuildingPortal;
					} else {
						portal.pos.z += dir.x;
						portal.pos.w += dir.y;
					}
					break;
				case Tile.Wall:
					if (state == State.BuildingPortal)
						finishPortal();
					break;
				default:
					stderr.writeln("\x1b[93;41mMAP HAS A LEAK (Air instead of portal or wall) ", walker, "\x1b[0m");
					assert(0);
				}
			}
			if (state == State.BuildingPortal)
				finishPortal();
		}

		//walk(position, vec2i(1, 0), vec2i(0, -1)); // Top
		walk(position + vec2i(0, size.y - 1), vec2i(1, 0), vec2i(0, 1)); // Bottom

		// walk(position, vec2i(0, 1), vec2i(-1, 0)); // Left
		walk(position + vec2i(size.x - 1, 0), vec2i(0, 1), vec2i(1, 0)); // Right
	}
}
