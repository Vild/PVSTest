import std.stdio;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import gl3n.linalg;
import std.conv;
import std.string;

shared static this() {
	DerelictSDL2.load();
	DerelictSDL2Image.load();
}

alias Color = Vector!(ubyte, 4);

enum Tile {
	Air,
	Wall,
	Door
}

Tile toTile(Color c) {
	if (c == Color(cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0xFF))
		return Tile.Air;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF))
		return Tile.Wall;
	else if (c == Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF))
		return Tile.Door;
	else {
		stderr.writeln("Color: ", c, " is undefined!");
		assert(0);
	}
}

Color toColor(Tile t) {
	switch (t) {
	case Tile.Air:
		return Color(cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0x3F, cast(ubyte)0xFF);
	case Tile.Wall:
		return Color(cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0x00, cast(ubyte)0xFF);
	case Tile.Door:
		return Color(cast(ubyte)0x00, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF);

	default:
		assert(0);
	}
}

bool isSolid(Tile t) {
	return t == Tile.Wall;
}

void sdlAssert(T, Args...)(T cond, Args args) {
	if (!!cond)
		return;
	stderr.writeln(args);
	stderr.writeln("SDL_ERROR: ", SDL_GetError().fromStringz);
	assert(0);
}

class SDL {
	this() {
		sdlAssert(!SDL_Init(SDL_INIT_EVERYTHING), "SDL could not initialize!");
		sdlAssert(IMG_Init(IMG_INIT_PNG), "SDL_image could not initialize!");
	}

	~this() {
		IMG_Quit();
		SDL_Quit();
	}
}

class Window {
public:
	SDL_Window* window;
	SDL_Renderer* renderer;
	int w;
	int h;
	float scale = 1;

	this(int w, int h) {
		this.w = w;
		this.h = h;
		sdlAssert(!SDL_CreateWindowAndRenderer(cast(int)(w * scale), cast(int)(h * scale), 0, &window, &renderer),
				"Failed to create window and renderer");
	}

	~this() {
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
	}

	void reset() {
		SDL_SetRenderTarget(renderer, null);
		SDL_SetWindowSize(window, cast(int)(w * scale), cast(int)(h * scale));
		SDL_RenderSetScale(renderer, scale, scale);
		SDL_RenderSetIntegerScale(renderer, SDL_TRUE);
		SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
	}
}

//Bresenham's line algorithm
bool validPath(vec2i start, vec2i end, const ref Tile[][] map) {
	import std.math : fabs, signbit;

	if (start == end)
		return true;

	int dX = end.x - start.x;
	int dY = end.y - start.y;

	int sign = dY < 0 ? -1 : 1;

	float deltaErr = dX ? fabs(dY / (1.0f * dX)) : 0;
	float err = 0;

	int y = start.y;
	foreach (int x; start.x .. end.x) {
		if (map[y][x].isSolid)
			return false;
		err += deltaErr;
		while (err >= 0.5) {
			y += sign;
			err -= 1;
		}
	}
	return true;
}

struct Room {
	vec2i id;
	vec2i position;
	enum vec2i size = vec2i(64, 64);
	Color color;

	size_t[] visibleRooms;
	vec2i[] canGoto;

	void explore(vec2i p, const ref vec2i[] doors, const ref Tile[][] map, const ref vec2i mapSize) {
		import std.algorithm : filter, canFind;

		vec2i pos = position + p;

		foreach (target; doors.filter!(door => !canGoto.canFind(door))) {
			if (map[target.y][target.x] != Tile.Door)
				continue;
			if (validPath(pos, target, map)) {
				//writeln("Pos: ", p, " can reach ", target);
				canGoto ~= target;
			}
		}
	}
}

int main(string[] args) {
	SDL sdl = new SDL;
	scope (exit)
		sdl.destroy;

	Tile[][] map;
	vec2i[] doors;
	vec2i mapSize;
	{
		SDL_Surface* mapSurface = IMG_Load("map.png");
		assert(mapSurface, "map.png is missing");
		scope (exit)
			SDL_FreeSurface(mapSurface);
		mapSize = vec2i(mapSurface.w, mapSurface.h);

		assert(mapSurface.format.format == SDL_PIXELFORMAT_RGBA32, "Wrong format");
		foreach (y; 0 .. mapSize.y) {
			Tile[] xRow;
			foreach (x; 0 .. mapSize.x) {
				Tile t = (cast(Color*)mapSurface.pixels)[y * mapSurface.w + x].toTile;
				if (t == Tile.Door)
					doors ~= vec2i(x, y);
				xRow ~= t;
			}
			map ~= xRow;
		}
	}
	Window w = new Window(mapSize.x, mapSize.y);
	scope (exit)
		w.destroy;

	Room[] rooms;

	enum roomSize = vec2i(64);

	writeln("Map size: ", mapSize.x, "x", mapSize.y);

	const int xCount = mapSize.x / roomSize.x;
	const int yCount = mapSize.y / roomSize.y;

	foreach (y; 0 .. yCount)
		foreach (x; 0 .. xCount) {
			ubyte r = 255; //cast(ubyte)((x * 128) / xCount);
			ubyte g = 255; //cast(ubyte)((y * 128) / yCount);
			ubyte b = 255; //cast(ubyte)(128 - r / 2 - g / 2);
			rooms ~= Room(vec2i(x, y), vec2i(x * roomSize.x, y * roomSize.y), Color(r, g, b, cast(ubyte)255));
		}

	size_t roomIdx;
	vec2i explorePos;
	bool exploring = true;
	bool quit = false;
	bool first = true;
	while (!quit) {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			switch (event.type) {
			case SDL_QUIT:
				quit = true;
				break;

			case SDL_KEYDOWN:
				if (event.key.keysym.sym == SDLK_ESCAPE)
					quit = true;
				break;

			case SDL_MOUSEWHEEL:
				w.scale += event.wheel.y * 0.01f;
				break;

			default:
				break;
			}
		}

		const size_t step = 2;
		if (!first) {
			const auto start = SDL_GetPerformanceCounter();
			while (((SDL_GetPerformanceCounter() - start) * 30) / SDL_GetPerformanceFrequency() < 1)
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
						// TODO: Doors should only contain doors that this rooms is connected to
						// TODO: or that rooms that it is connected to has.
						rooms[roomIdx].explore(explorePos, doors, map, mapSize);
						explorePos.x += step;

						string title = format("Exploring Room (%dx%d), Pixel (%dx%d)", roomIdx % xCount, roomIdx / xCount, explorePos.x, explorePos.y);
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
					const size_t myRoomIdx = myRoomPos.y * yCount + myRoomPos.x;
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
