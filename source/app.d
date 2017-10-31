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
	if (c == Color(cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF))
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
		return Color(cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF, cast(ubyte)0xFF);
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

SDL_Texture* makeRoomsBackground(Window w, vec2i mapSize, ref Room[] rooms) {
	SDL_Texture* t = SDL_CreateTexture(w.renderer, SDL_PIXELFORMAT_RGB24, SDL_TEXTUREACCESS_TARGET,
			cast(int)(mapSize.x * w.scale), cast(int)(mapSize.y * w.scale));

	//SDL_RenderSetScale(w.renderer, 1, 1);
	SDL_SetRenderTarget(w.renderer, t);
	foreach (ref Room room; rooms)
		with (room) {
			SDL_SetRenderDrawColor(w.renderer, color.x, color.y, color.z, 255);
			SDL_Rect r = SDL_Rect(cast(int)(position.x * w.scale), cast(int)(position.y * w.scale),
					cast(int)((position.x + size.x) * w.scale), cast(int)((position.y + size.y) * w.scale));
			SDL_RenderFillRect(w.renderer, &r);
			SDL_SetRenderDrawColor(w.renderer, cast(int)(color.x / 4), cast(int)(color.y / 4), cast(int)(color.z / 4), 255);
			SDL_RenderDrawRect(w.renderer, &r);
		}
	return t;
}

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
		vec2i pos = position + p;

		foreach (target; doors) {
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

	const xCount = mapSize.x / roomSize.x;
	const yCount = mapSize.y / roomSize.y;

	foreach (y; 0 .. yCount)
		foreach (x; 0 .. xCount) {
			ubyte r = cast(ubyte)((x * 128) / xCount);
			ubyte g = cast(ubyte)((y * 128) / yCount);
			ubyte b = cast(ubyte)(128 - r / 2 - g / 2);
			rooms ~= Room(vec2i(x, y), vec2i(x * roomSize.x, y * roomSize.y), Color(r, g, b, cast(ubyte)255));
		}

	auto roomsBackground = makeRoomsBackground(w, mapSize, rooms);
	scope (exit)
		SDL_DestroyTexture(roomsBackground);

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
				SDL_DestroyTexture(roomsBackground);
				roomsBackground = makeRoomsBackground(w, mapSize, rooms);
				break;

			default:
				break;
			}
		}

		if (!first) {
			auto start = SDL_GetPerformanceCounter();
			while (((SDL_GetPerformanceCounter() - start) * 100) / SDL_GetPerformanceFrequency() < 1)
				if (exploring) {
					if (explorePos.x == roomSize.x) {
						explorePos.y++;
						explorePos.x = 0;
					}

					if (explorePos.y == roomSize.y) {
						explorePos.y = 0;
						roomIdx++;
					}

					import std.format : format;

					if (roomIdx < rooms.length) {
						rooms[roomIdx].explore(explorePos, doors, map, mapSize);
						explorePos.x++;

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

		SDL_RenderCopy(w.renderer, roomsBackground, null, null);

		foreach (int y, const ref Tile[] xRow; map)
			foreach (int x, const ref Tile tile; xRow) {
				auto c = tile.toColor;
				SDL_SetRenderDrawColor(w.renderer, c.x, c.y, c.z, cast(ubyte)(c.w / 2));

				SDL_RenderDrawPoint(w.renderer, x, y);
			}

		SDL_RenderPresent(w.renderer);
	}

	return 0;
}
