module door;

import gfm.math;

import room;

alias DoorIdx = vec4i;

size_t doorID(in DoorIdx id, ref const vec2i roomCount) {
	import std.stdio : writeln;

	immutable size_t x = id.x / Room.size.x;
	immutable size_t y = id.y / Room.size.y;
	immutable size_t horizontalDoor = (id.y % Room.size.y) == (Room.size.y - 1) ? 1 : 0;

	immutable size_t ret = 2*(y * roomCount.x + x) + horizontalDoor;
	//writeln("id: ", id.xy, " -> ", ret);
	return ret;
}

struct Door {
	DoorIdx id;
	RoomIdx[2] rooms; // Each door connects two rooms

	string toString() const {
		import std.format : format;

		return format("\x1b[1;34mDoor(\x1b[1;32mid: \x1b[1;33m%s\x1b[1;34m,\t\x1b[1;32mrooms: \x1b[1;33m%s\x1b[1;34m)\x1b[0m", id, rooms);
	}
}
