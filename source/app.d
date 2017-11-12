import std.stdio;
import gfm.math;
import std.conv;
import std.string;
import std.bitmanip;

import sdl;
import types;
import portal;
import room;

interface IState {
	void update();
	void render();
	@property bool isDone();
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
			/*foreach (roomID; _currentRoom.visibleRooms) {
				Room* d = &_engine._rooms[roomID];

				// Skip walls
				for (size_t y = 1; y < Room.size.y - 1; y++)
					for (size_t x = 1; x < Room.size.x - 1; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.position.x + x), cast(int)(d.position.y + y));
					}
			}*/

			/*foreach (portalID; _currentRoom.visiblePortals) {
				Portal* d = &_engine._portals[portalID];

				for (size_t y; y < d.id.w; y++)
					for (size_t x; x < d.id.z; x++) {
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF);
						SDL_RenderDrawPoint(_engine._window.renderer, cast(int)(d.id.x + x), cast(int)(d.id.y + y));
					}
			}*/

			writeln("room: ", _currentRoom.id);
			foreach (portalID; _currentRoom.portals) {
				import std.algorithm : countUntil;

				Portal* d = &_engine._portals[portalID];
				writeln("\tportal: ", portalID);

				foreach (i, b; d.canSeePortal)
					if (b && _currentRoom.portals.countUntil(i) == -1) {
						Portal* dOther = &_engine._portals[i];
						writeln("\t\tcan see: ", dOther.id, " #### ", dOther.id == i);
						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF);
						for (int y = dOther.pos.y; y < dOther.pos.y + dOther.pos.w; y++)
							for (int x = dOther.pos.x; x < dOther.pos.x + dOther.pos.z; x++)
								SDL_RenderDrawPoint(_engine._window.renderer, x, y);

						SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
						done: foreach (aY; d.pos.y .. d.pos.y + d.pos.w)
							foreach (aX; d.pos.x .. d.pos.x + d.pos.z)
								foreach (bY; dOther.pos.y .. dOther.pos.y + dOther.pos.w)
									foreach (bX; dOther.pos.x .. dOther.pos.x + dOther.pos.z)
										if (validPath(vec2i(aX, aY), vec2i(bX, bY), _engine._map)) {
											SDL_RenderDrawLine(_engine._window.renderer, aX, aY, bX, bY);
											break done;
										}
					}

				SDL_SetRenderDrawColor(_engine._window.renderer, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0x00, cast(ubyte)0xFF);
				for (int y = d.pos.y; y < d.pos.y + d.pos.w; y++)
					for (int x = d.pos.x; x < d.pos.x + d.pos.z; x++) {
						SDL_RenderDrawPoint(_engine._window.renderer, x, y);
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

		State state = State.visualize; //State.explore;
		IState[State] states = [ //State.explore : cast(IState)new ExploreState(this),//
		State.visualize : cast(IState)new VisualizeState(this), //
			State.end : cast(IState)null];

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
	Portal[size_t] _portals;
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

		{ // Find portals
			foreach (ref Room r; _rooms)
				r.findPortals(_portals, _rooms, _map, _mapSize, _roomCount);
		}

		calculatePortalVisibilities(_portals, _map, _roomCount);
	}
}

int main(string[] args) {
	Engine e = new Engine();
	scope (exit)
		e.destroy;
	return e.run();
}
