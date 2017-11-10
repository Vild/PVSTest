module door;

import gfm.math;
import std.bitmanip : BitArray;

import room;
import types;

alias DoorIdx = vec4i;

size_t doorID(in DoorIdx id, ref const vec2i roomCount) {
	import std.stdio : writeln;

	immutable size_t x = id.x / Room.size.x;
	immutable size_t y = id.y / Room.size.y;
	immutable size_t horizontalDoor = (id.y % Room.size.y) == (Room.size.y - 1) ? 1 : 0;

	immutable size_t ret = 2 * (y * roomCount.x + x) + horizontalDoor;
	//writeln("id: ", id.xy, " -> ", ret);
	return ret;
}

struct Door {
	DoorIdx id;
	RoomIdx[2] rooms; // Each door connects two rooms
	BitArray canSeeDoor;

	string toString() const {
		import std.format : format;

		return format("\x1b[1;34mDoor(\x1b[1;32mid: \x1b[1;33m%s\x1b[1;34m,\t\x1b[1;32mrooms: \x1b[1;33m%s\x1b[1;34m)\x1b[0m", id, rooms);
	}
}

void calculateDoorVisibilities(Door[DoorIdx] doors, const ref Tile[][] tiles, const ref vec2i roomCount) {
	import std.algorithm : map, each;
	import std.array : array;
	import roundRobin : roundRobin, Result;
	import std.parallelism : parallel;
	import std.algorithm : max;

	size_t maxIdx = 0;
	doors.each!((ref x) { maxIdx = max(maxIdx, x.id.doorID(roomCount)); });
	doors.each!((ref x) => x.canSeeDoor.length = maxIdx);

	DoorIdx[] doorIndices = doors.byValue.map!(x => x.id).array;
	scope (exit)
		doorIndices.destroy;
	if (doorIndices.length % 2 == 1)
		doorIndices ~= DoorIdx(int.max, int.max, int.max, int.max);
	Result!DoorIdx[] toCheck = roundRobin(doorIndices);
	scope (exit)
		toCheck.destroy;

	foreach (ref Result!DoorIdx r; toCheck) {
		if ((r.a.x == int.max && r.a.y == int.max && r.a.z == int.max && r.a.w == int.max) || (r.b.x == int.max
				&& r.b.y == int.max && r.b.z == int.max && r.b.w == int.max))
			continue;
		Door* a = &doors[r.a];
		Door* b = &doors[r.b];

		leave: foreach (aY; a.id.y .. a.id.y + a.id.w)
			foreach (aX; a.id.x .. a.id.x + a.id.z)
				foreach (bY; b.id.y .. b.id.y + b.id.w)
					foreach (bX; b.id.x .. b.id.x + b.id.z)
						if (validPath(vec2i(aX, aY), vec2i(bX, bY), tiles)) {
							a.canSeeDoor[b.id.doorID(roomCount)] = true;
							b.canSeeDoor[a.id.doorID(roomCount)] = true;
							break leave;
						}
	}
}
