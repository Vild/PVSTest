import std.stdio;
import gfm.math;
import std.conv;
import std.string;
import std.bitmanip;

import sdl;
import types;
import door;
import room;

interface IState {
	void update();
	void render();
	@property bool isDone();
}

final class ExploreState : IState {
public:
	this(Engine engine) {
		_engine = engine;
	}

	void update() {
		const size_t step = 1;
		immutable uint old = SDL_GetTicks();

		do {
			_explorePos.x += step;
			if (_explorePos.x >= _engine._roomSize.x) {
				_explorePos.y += step;
				_explorePos.x = 0;
			}

			if (_explorePos.y >= _engine._roomSize.y) {
				_explorePos.y = 0;
				_currentRoom.finalize();
				_roomIdx++;
			}

			_currentRoom = RoomIdx(cast(int)(_roomIdx % _engine._roomCount.x), cast(int)(_roomIdx / _engine._roomCount.x)) in _engine._rooms;
			if (_currentRoom && _currentRoom.doors.length)
				_currentRoom.explore(_explorePos, _engine._doors, _engine._rooms, _engine._map, _engine._roomCount);
		}
		while (_currentRoom && SDL_GetTicks() - old < 100 /*msec*/ );
	}

	void render() {
		const size_t curPosIdx = _explorePos.y * _engine._roomSize.x + _explorePos.x;
		foreach (int y, const ref Tile[] xRow; _engine._map)
			foreach (int x, const ref Tile tile; xRow) {
				auto c = tile.toColor;
				if (tile == Tile.Air) {
					const vec2i myRoomPos = vec2i(x / _engine._roomSize.x, y / _engine._roomSize.y);
					const size_t myRoomIdx = myRoomPos.y * _engine._roomCount.y + myRoomPos.x;
					if (myRoomIdx <= _roomIdx) {
						const size_t myPosIdx = (y % _engine._roomSize.y) * _engine._roomSize.x + x % _engine._roomSize.x;
						if (myRoomIdx == _roomIdx && myPosIdx >= curPosIdx)
							c = Color(cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: TODO
						else
							c = Color(cast(ubyte)0x00, cast(ubyte)0x7F, cast(ubyte)0x00, cast(ubyte)0xFF); // Status: Done
					}
				}
				SDL_SetRenderDrawColor(_engine._window.renderer, c.x, c.y, c.z, c.w);
				SDL_RenderDrawPoint(_engine._window.renderer, x, y);
			}

		if (_currentRoom) {
			foreach (doorID; _currentRoom.doors) {
				Door* d = &_engine._doors[doorID];

				for (size_t y; y < d.id.w; y++)
					for (size_t x; x < d.id.z; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.id.x + x), cast(int)(d.id.y + y));
					}
			}

			string title = format("Exploring Room (%dx%d), Pixel (%dx%d)", _roomIdx % _engine._roomCount.x,
					_roomIdx / _engine._roomCount.x, _explorePos.x, _explorePos.y);
			SDL_SetWindowTitle(_engine._window.window, title.toStringz);
		} else
			SDL_SetWindowTitle(_engine._window.window, "Exploring done!");
	}

	@property bool isDone() {
		return !_currentRoom;
	}

private:
	Engine _engine;
	size_t _roomIdx;
	vec2i _explorePos = vec2i(-1, 0);
	Room* _currentRoom;
}

final class VisualizeState : IState {
public:
	this(Engine engine) {
		_engine = engine;
	}

	void update() {
		vec2i pos;
		immutable int s = SDL_GetMouseState(&pos.x, &pos.y);
		pos = vec2i(cast(int)(pos.x / _engine._window.scale), cast(int)(pos.y / _engine._window.scale));

		pos /= Room.size;
		_currentRoom = pos in _engine._rooms;
	}

	void render() {
		foreach (int y, const ref Tile[] xRow; _engine._map)
			foreach (int x, const ref Tile tile; xRow) {
				auto c = tile.toColor;
				SDL_SetRenderDrawColor(_engine._window.renderer, c.x, c.y, c.z, c.w);
				SDL_RenderDrawPoint(_engine._window.renderer, x, y);
			}

		if (_currentRoom) {
			foreach (roomID; _currentRoom.visibleRooms) {
				Room* d = &_engine._rooms[roomID];

				// Skip walls
				for (size_t y = 1; y < Room.size.y - 1; y++)
					for (size_t x = 1; x < Room.size.x - 1; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.position.x + x), cast(int)(d.position.y + y));
					}
			}

			foreach (doorID; _currentRoom.visibleDoors) {
				Door* d = &_engine._doors[doorID];

				for (size_t y; y < d.id.w; y++)
					for (size_t x; x < d.id.z; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.id.x + x), cast(int)(d.id.y + y));
					}
			}

			foreach (doorID; _currentRoom.doors) {
				Door* d = &_engine._doors[doorID];

				for (size_t y; y < d.id.w; y++)
					for (size_t x; x < d.id.z; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.id.x + x), cast(int)(d.id.y + y));
					}
			}
		}
	}

	@property bool isDone() {
		return false;
	}

private:
	Engine _engine;
	Room* _currentRoom;
}

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
			explore = 0,
			visualize,

			end
		}

		State state = State.explore;
		IState[State] states = [
			State.explore : cast(IState)new ExploreState(this), State.visualize : cast(IState)new VisualizeState(this),
			State.end : cast(IState)null
		];

		while (states[state] && _sdl.doEvent(_window)) {
			states[state].update();

			_window.reset();
			SDL_SetRenderDrawColor(_window.renderer, 0, 0, 0, 255);
			SDL_RenderClear(_window.renderer);

			states[state].render();

			SDL_RenderPresent(_window.renderer);

			if (states[state].isDone())
				state++;
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
