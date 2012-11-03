module metus.dncurses.dncurses;

import std.c.string : strlen;
import std.string : toStringz, format, toUpper;
import std.algorithm;

private import nc = deimos.ncurses.ncurses;

alias nc.chtype CharType;

char[] ncurses_version() {
	char* ver = nc.curses_version();
	return ver[0..strlen(ver)];
}

/** @brief ZMQ error class
Automatically gets the latest ZMQ error
*/
class NCursesError : Error {
public:
	/**
	 * Create and automatically initialize an NCursesError
	 */
    this (string _msg, string file=__FILE__, int line=__LINE__) {
    	super(_msg, file, line);
	}
};

struct Color {
	@disable this();
	template opDispatch(string key)
	{
		enum opDispatch = mixin("nc.COLOR_"~key.toUpper());
	}
}

static if(0)
immutable enum Attribute : CharType {
	/// Normal display (no highlight)
	Normal = nc.A_NORMAL,
	/// Bit-mask to get the attributes of a character
	Attributes = nc.A_ATTRIBUTES,
	/// Bit-mask to extract a character
	Chartext = nc.A_CHARTEXT,
	/// Bit-mask to extract a color
	Color = nc.A_COLOR,
	/// Best highlighting mode of the terminal
	Standout = nc.A_STANDOUT,
	/// Underlining
	Underline = nc.A_UNDERLINE,
	/// Reverse video
	Reverse = nc.A_REVERSE,
	/// Blinking
	Blink = nc.A_BLINK,
	/// Half bright
	Dim = nc.A_DIM,
	/// Extra bright or bold
	Bold = nc.A_BOLD,
	/// Bit-mask for alternate character set
	AltCharset = nc.A_ALTCHARSET,
	/// Invisible or blank mode
	Invis = nc.A_INVIS,
	/// Protected mode
	Protect = nc.A_PROTECT,
	/// XSI extra conformance standard
	// @{
	Horizontal = nc.A_HORIZONTAL,
	Left = nc.A_LEFT,
	Low = nc.A_LOW,
	Right = nc.A_RIGHT,
	Top = nc.A_TOP,
	Vertical = nc.A_VERTICAL,
	// @}
}

immutable enum Flag {
	subwin = 0x01, /* is this a sub-window? */
    endline = 0x02, /* is the window flush right? */
    fullwin = 0x04, /* is the window full-screen? */
    scrollwin = 0x08, /* bottom edge is at screen bottom? */
    ispad = 0x10, /* is this window a pad? */
    hasmoved = 0x20, /* has cursor moved since last refresh? */
    wrapped = 0x40 /* cursor was just wrappped */
}
private static bool isEcho;

auto echo(bool echoon) {
	bool currEcho = isEcho;
	if(((isEcho=echoon)==true ? nc.echo() : nc.noecho()) == nc.ERR) {
		throw new NCursesError("Could not change echo mode");
	}
	return currEcho;
}

auto qiflush(bool flush) {
	return (flush?nc.qiflush():nc.noqiflush());
}

auto intrflush(bool shouldFlush) {
	// nc.intrflush ignores the window parameter...
	return nc.intrflush(nc.stdscr,shouldFlush);
}

immutable enum Mode {
	Cooked = 0,
	CBreak = 1<<0,
	Raw = 1<<1,
	HalfDelay = CBreak|(1<<2),
}
private static Mode currMode=Mode.Cooked; // Why did I have this default to raw?

void mode(Mode r, ubyte delay = 0) {
	if(r & currMode) {
		return;
	}
	with(Mode)
	final switch(currMode) {
		case Cooked: {
			// Do nothing
			break;
		}
		case CBreak:
		case HalfDelay: {
			nc.nocbreak();
			break;
		}
		case Raw: {
			nc.noraw();
			break;
		}
	}

	with(Mode)
	final switch(r) {
		case Cooked: {
			nc.noraw();
			nc.nocbreak();
			break;
		}
		case CBreak: {
			nc.cbreak();
			break;
		}
		case HalfDelay: {
			if(delay != 0) {
				// They overrode the default value
				nc.halfdelay(delay);
			} else {
				throw new NCursesError("Invalid halfdelay time");
			}
			break;
		}
		case Raw: {
			nc.raw();
			break;
		}
	}
	currMode = r;
}

struct Key {
	@disable this();
	template opDispatch(string key)
	{
		static if(key.toUpper()[0] == 'F' && key.length > 1 && (key[1]>'0'&&key[1]<='9')) {
			enum opDispatch = mixin("nc.KEY_F("~key[1..$]~")");
		} else {
			enum opDispatch = mixin("nc.KEY_"~key.toUpper());
		}
	}
}

enum Positioning {
	Relative,
	Absolute
}


/** Window wrapper
 */
class Window {
private:
	Window m_parent = null;
	nc.WINDOW* m_raw;
	bool currKeypad=false;
	bool currMeta = false;

	// Handle coordinate functions
	mixin template Coord(string name) {
		@property auto Coord() {
			struct Pos {
				immutable int x,y;
				this(int _y, int _x) {
					this.x = _x;
					this.y = _y;
				}
			}
			return mixin("Pos(nc.get"~name~"y(m_raw), nc.get"~name~"x(m_raw))");
		}
		mixin("alias Coord "~name~";");
	}

	mixin template MoveWrapper(string Func) {
		auto MoveWrapper(T...)(int y, int x, T t) {
			this.move(y,x);
			return mixin(Func~"(t)");
		}
		mixin("alias MoveWrapper mv"~Func~";");
	}

	/**
	 * Constructor from a C-style window
	 */
	this(nc.WINDOW* raw)
	in {
		assert(raw);
	} body {
		m_raw = raw;
	}

public:
	/** Construct an ncurses Window
	 *
	 * @param nlines The number of lines for the window
	 * @param lcols The number of columns for the window
	 * @param y0 The number of the first row that the window uses
	 * @param x0 The number of the first column that the window uses
	 */
	this(int nlines, int ncols, int y0, int x0)
	in {
		assert(0 <= y0 && y0 < nc.getmaxy(nc.stdscr));
		assert(0 <= x0 && x0 < nc.getmaxx(nc.stdscr));
	}
	out {
		assert(m_raw);
	}
	body {
		m_raw = nc.newwin(nlines,ncols,y0,x0);
	}

	/** Construct an ncurses Window
	 *
	 * @param myParent The parent window of the window to be created
	 * @param nlines The number of lines for the window
	 * @param lcols The number of columns for the window
	 * @param y0 The number of the first row that the window uses
	 * @param x0 The number of the first column that the window uses
	 */
	this(Window myParent, int nlines, int ncols, int y0, int x0)
	in {
		assert(0 <= y0 && y0 < nc.getmaxy(nc.stdscr));
		assert(0 <= x0 && x0 < nc.getmaxx(nc.stdscr));
	}
	out {
		assert(m_raw);
	}
	body {
		m_parent = myParent;
		m_raw = nc.newwin(nlines,ncols,y0,x0);
	}

	@property Window parent() {
		return m_parent;
	}

	auto nodelay(bool bf) {
		return nc.nodelay(m_raw,bf);
	}
	auto timeout(int delay) {
		return nc.wtimeout(m_raw,delay);
	}
	auto keypad(bool enabled) {
		return nc.keypad(m_raw,(currKeypad=enabled));
	}
	auto meta(bool enabled) {
		return nc.meta(m_raw,(currMeta=enabled));
	}


	// Output

	/** Print to a window with printf functionality
	 *
	 * @param fmt The format specifier
	 */
	auto printf(T...)(string fmt, T d) {
		string ret = format(fmt, d);
		if(nc.waddstr(m_raw, ret.toStringz()) == nc.ERR) {
			throw new NCursesError("Error printing string");
		}
	}
	mixin MoveWrapper!"printf";

	/** Put a character at the current position on the window
	 *
	 * @param c The character (and attributes) to put
	 */
	auto addch(C:CharType)(C c) {
		if(nc.waddch(m_raw, c) == nc.ERR) {
			throw new NCursesError("Error adding a character");
		}
	}
	mixin MoveWrapper!"addch";

	/** Delete the character under the cursor
	 */
	auto delch() {
		if(nc.wdelch(m_raw) == nc.ERR) {
			throw new NCursesError("Error deleting a character");
		}
	}
	mixin MoveWrapper!"delch";

	/** Put a string at the current position on the window
	 *
	 * @param str The string to put
	 */
	auto addstr(string str) {
		if(nc.waddstr(m_raw, str.toStringz()) == nc.ERR) {
			throw new NCursesError("Error adding string");
		}
	}
	mixin MoveWrapper!"addstr";


	// Input

	/**
	 * Get a single keypress
	 */
	auto getch() {
		return nc.wgetch(m_raw);
	}
	mixin MoveWrapper!"getch";

	/** Get a string from the window
	 */
	char[] getstr() {
		// Get as much data as possible
		// Make sure not to output directly
		bool tmpecho = echo(false);
		scope(exit) echo(tmpecho);

		char[] ret;
		int buf;
		bool isKill(int ch) {
			return (currKeypad
					? [nc.killchar(), nc.erasechar(), Key.Left, Key.Backspace]
					: [cast(int)nc.killchar(), cast(int)nc.erasechar()]
				).canFind(ch);
		}
		bool isEnd(int ch) {return "\r\n\x04".canFind(ch);}
		while((buf=nc.getch()),!isEnd(buf)) {
			if(isKill(buf)) {
				if(ret.length) {
					ret = ret[0..($-1)];
					if(tmpecho) {
						if(cur.x) {
							move(cur.y, cur.x-1);
							delch();
						} else {
							move(cur.y-1, max.x);
							delch();
						}
					}
				}
			} else {
				ret ~= cast(char)buf;
				if(tmpecho) {
					addch(cast(char)buf);
				}
			}
		}
		return ret.dup;
	}
	char[] getstr(int maxlen) {
		// We know the max length
		char[] ret = new char[maxlen];
		if(nc.getnstr(ret.ptr,maxlen) == nc.OK) {
			// All good!
			return ret.dup;
		} else {
			// Something's wrong
			throw new NCursesError("Error receiving input");
		}
	}
	mixin MoveWrapper!"getstr";


	// Updating
	auto refresh() {
		return nc.wrefresh(m_raw);
	}
	auto erase() {
		return nc.werase(m_raw);
	}
	auto clear() {
		return nc.wclear(m_raw);
	}
	auto clrtobot() {
		return nc.wclrtobot(m_raw);
	}
	auto clrtoeol() {
		return nc.wclrtoeol(m_raw);
	}


	// Movement and X/Y
	auto move(int y, int x) {
		if(nc.wmove(m_raw,y,x)==nc.ERR) {
			throw new NCursesError("Could not move to correct location");
		}
	}

	mixin Coord!"cur";
	mixin Coord!"beg";
	mixin Coord!"max";
	mixin Coord!"par";


	// Border and graphics
	int border()() {
		return nc.wborder(m_raw, 0, 0, 0, 0, 0, 0, 0, 0);
	}
	int border(C:CharType)(C ls, C rs, C ts, C bs,
		C tl = cast(C)0, C tr = cast(C)0, C bl = cast(C)0, C br = cast(C)0)
	{
		return nc.wborder(m_raw, ls, rs, ts, bs, tl, tr, bl, br);
	}
	int box(C:CharType)(C verch, C horch)
	{
		return nc.wborder(m_raw, verch, verch, horch, horch, 0, 0, 0, 0);
	}
	int hline(C:CharType)(C ch, int n) {
		return nc.whline(m_raw, ch, n);
	}
	mixin MoveWrapper!"hline";
	int vline(C:CharType)(C ch, int n) {
		return nc.wvline(m_raw, ch, n);
	}
	mixin MoveWrapper!"vline";


	// Attributes
	auto attron(N:CharType)(N attrs) {
		return nc.wattron(m_raw, attrs);
	}
	auto attroff(N:CharType)(N attrs) {
		return nc.wattroff(m_raw, attrs);
	}
	auto attrset(N:CharType)(N attrs) {
		return nc.wattron(m_raw, attrs);
	}
}

/**
 * Create an audio beep
 */
alias nc.beep beep;
/**
 * Create a visual "bell"
 */
alias nc.flash flash;

alias nc.killchar killchar;
alias nc.erasechar erasechar;

// Wrap the original ncurses implementations
public Window stdwin;
auto initscr() {
	 // Call library initscr and bind our standard window
	stdwin = new Window(nc.initscr());
	echo(true);
	return stdwin;
}
auto endwin() {
	return nc.endwin();
}
