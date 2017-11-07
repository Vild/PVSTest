import std.stdio;
import gfm.math;
import std.conv;
import std.string;
import std.bitmanip;

import sdl;
import types;
import door;
import room;

class Engine {
public:
	this() {
		_sdl = new SDL;
		_loadData();
		_window = new Window(_mapSize.x, _mapSize.y);
	}

	~this() {
		_window.destroy;
		_sdl.destroy;
	}

	int run() {
		enum State {
			explore,
			visualize
		}

		State state = State.explore;
		roomsRange = _rooms.byValue;

		while (_sdl.doEvent(_window)) {
			final switch (state) {
			case State.explore:
				_explore();
				break;
			case State.visualize:
				break;
			}

			_window.reset();
			SDL_SetRenderDrawColor(_window.renderer, 0, 0, 0, 255);
			SDL_RenderClear(_window.renderer);

			final switch (state) {
			case State.explore:
				_exploreRender();
				break;
			case State.visualize:
				break;
			}

			SDL_RenderPresent(_window.renderer);
		}
		return 0;
	}

private:
	SDL _sdl;
	Window _window;

	enum _roomSize = vec2i(64);
	Tile[][] _map;
	Door[DoorIdx] _doors;
	Room[RoomIdx] _rooms;
	vec2i _mapSize;
	vec2i _roomCount;

	size_t roomIdx;
	vec2i explorePos;
	bool exploring = true;
	typeof(_rooms.byValue) roomsRange;

	void _explore() {
		const size_t step = 1;
		immutable uint old = SDL_GetTicks();
		Room* room = &roomsRange.front();
		while (SDL_GetTicks() - old < 1 /*msec*/ )
			do {
				if (exploring) {
					if (explorePos.x >= _roomSize.x) {
						explorePos.y += step;
						explorePos.x = 0;
					}

					if (explorePos.y >= _roomSize.y) {
						explorePos.y = 0;
						roomIdx++;
						roomsRange.popFront();
						room = roomsRange.empty ? null : &roomsRange.front();
					}

					import std.format : format;

					if (!roomsRange.empty) {
						room.explore(explorePos, _doors, _rooms, _map, _roomCount);
						explorePos.x += step;
					} else {
						exploring = false;
					}
				}
			}
		while (roomIdx < _rooms.length && !_rooms[RoomIdx(cast(int)(roomIdx % _roomCount.x), cast(int)(roomIdx / _roomCount.x))].doors.length);
	}

	void _exploreRender() {
		const size_t curPosIdx = explorePos.y * _roomSize.x + explorePos.x;
		foreach (int y, const ref Tile[] xRow; _map)
			foreach (int x, const ref Tile tile; xRow) {
				auto c = tile.toColor;
				if (tile == Tile.Air) {
					const vec2i myRoomPos = vec2i(x / _roomSize.x, y / _roomSize.y);
					const size_t myRoomIdx = myRoomPos.y * _roomCount.y + myRoomPos.x;
					if (myRoomIdx <= roomIdx) {
						const size_t myPosIdx = (y % _roomSize.y) * _roomSize.x + x % _roomSize.x;
						if (myRoomIdx == roomIdx && myPosIdx >= curPosIdx)
							c = Color(cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: TODO
						else
							c = Color(cast(ubyte)0x00, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: Done
					}
				}
				SDL_SetRenderDrawColor(_window.renderer, c.x, c.y, c.z, c.w);
				SDL_RenderDrawPoint(_window.renderer, x, y);
			}

		if (exploring) {
			Room* r = &_rooms[RoomIdx(cast(int)(roomIdx % _roomCount.x), cast(int)(roomIdx / _roomCount.x))];
			foreach (doorID; r.doors) {
				Door* d = &_doors[doorID];

				for (size_t y; y < d.id.w; y++)
					for (size_t x; x < d.id.z; x++) {
						SDL_SetRenderDrawColor(_window.renderer, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_window.renderer, cast(int)(d.id.x + x), cast(int)(d.id.y + y));
					}
			}

			string title = format("Exploring Room (%dx%d), Pixel (%dx%d)", roomIdx % _roomCount.x, roomIdx / _roomCount.x,
					explorePos.x, explorePos.y);
			SDL_SetWindowTitle(_window.window, title.toStringz);
		} else {
			exploring = false;
			SDL_SetWindowTitle(_window.window, "Exploring done!");
		}
	}

	void _loadData() {
		{ // Create tiles
			SDL_Surface* mapSurface = IMG_Load("map.png");
			assert(mapSurface, "map.png is missing");
			scope (exit)
				SDL_FreeSurface(mapSurface);
			_mapSize = vec2i(mapSurface.w, mapSurface.h);
			_roomCount = _mapSize / _roomSize;
			assert(mapSurface.format.format == SDL_PIXELFORMAT_RGBA32, "Wrong format");

			writeln("Map size: ", _mapSize);
			foreach (y; 0 .. _mapSize.y) {
				Tile[] xRow;
				foreach (x; 0 .. _mapSize.x)
					xRow ~= (cast(Color*)mapSurface.pixels)[y * mapSurface.w + x].toTile;

				_map ~= xRow;
			}
		}

		{ // Create rooms
			foreach (y; 0 .. _roomCount.y)
				foreach (x; 0 .. _roomCount.x) {
					auto r = Room(RoomIdx(x, y), vec2i(x * _roomSize.x, y * _roomSize.y));
					_rooms[r.id] = r;
				}
		}

		{ // Find doors
			foreach (ref Room r; _rooms) {
				r.findPotentialDoors(_doors, _rooms, _map, _mapSize);
				r.setupBits(_roomCount);
			}
			writeln();
		}
	}
}

int main(string[] args) {
	Engine e = new Engine();
	scope (exit)
		e.destroy;
	return e.run();
}
