module door;

import gfm.math;

import room;

alias DoorIdx = vec4i;

size_t doorID(in DoorIdx id, vec2i doorCount) {
	return id.y * doorCount.x + id.x;
}

struct Door {
	DoorIdx id;
	RoomIdx[2] rooms; // Each door connects two rooms

	string toString() const {
		import std.format : format;

		return format("\x1b[1;34mDoor(\x1b[1;32mid: \x1b[1;33m%s\x1b[1;34m,\t\x1b[1;32mrooms: \x1b[1;33m%s\x1b[1;34m)\x1b[0m", id, rooms);
	}
}
