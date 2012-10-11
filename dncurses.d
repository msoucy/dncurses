module metus.dncurses.dncurses;

import std.c.string : strlen;
import std.string : toStringz;
import std.range : appender;
import core.vararg;

private import nc = ncurses;
public import ncurses : getch, flash;

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


immutable enum Color : nc.chtype {
	/* colors */
	BLACK = nc.COLOR_BLACK,
	RED = nc.COLOR_RED,
	GREEN = nc.COLOR_GREEN,
	YELLOW = nc.COLOR_YELLOW,
	BLUE = nc.COLOR_BLUE,
	MAGENTA = nc.COLOR_MAGENTA,
	CYAN = nc.COLOR_CYAN,
	WHITE = nc.COLOR_WHITE
}

immutable enum Attribute : nc.chtype {
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

immutable enum Mode {
	Cooked,
	CBreak,
	Raw,
}
private static Mode currMode=Mode.Raw;

int echo(bool echoon) {
	return (echoon ? nc.echo() : nc.noecho());
}

void mode(Mode r) {
	if(r == currMode) {
		return;
	} else if(r == Mode.Cooked) {
		if(currMode == Mode.CBreak) {
			nc.nocbreak();
		} else if(currMode == Mode.Raw) {
			nc.noraw();
		}
	} else if(r == Mode.CBreak) {
		if(currMode == Mode.Cooked) {
			nc.cbreak();
		} else if(currMode == Mode.Raw) {
			nc.noraw();
			nc.cbreak();
		}
	} else if(r == Mode.Raw) {
		if(currMode == Mode.Cooked) {
			nc.cbreak();
		} else if(currMode == Mode.CBreak) {
			nc.nocbreak();
			nc.raw();
		}
	}
	currMode = r;
}

class Window {
private:
	nc.WINDOW* m_raw;
	struct Pos {
		immutable int x,y;
		this(int _y, int _x) {
			this.x = _x;
			this.y = _y;
		}
	}
public:
	/**
	 * Constructor from a C-style window
	 */
	this(nc.WINDOW* raw) {
		m_raw = raw;
	}


	// I/O
	/** Print to a window with printf functionality
	 *
	 * @param fmt The format specifier
	 */
	extern(C) int printf(string fmt, ...) {
		va_list ap;
		version (X86_64) va_start(ap, __va_argsave);
		else version (X86) va_start(ap, fmt);
		nc.vwprintw(m_raw, fmt.toStringz(), ap);
		return 0;
	}
	/** Move and print to a window with printf functionality
	 *
	 * @param fmt The format specifier
	 */
	extern(C) int mvprintf(int y, int x, string fmt, ...) {
		if(move(y,x) == nc.ERR) return nc.ERR;
		va_list ap;
		version (X86_64) va_start(ap, __va_argsave);
		else version (X86) va_start(ap, fmt);
		nc.vwprintw(m_raw, fmt.toStringz(), ap);
		return 0;
	}
	/** Put a character at the current position on the window
	 *
	 * @param c The character (and attributes) to put
	 */
	auto addch(C:CharType)(C c) {
		return nc.waddch(c);
	}
	/** Move to a given position and put the given character
	 *
	 * @param y The row to go to
	 * @param x The column to go to
	 * @param c The character (and attributes) to put
	 */
	auto mvaddch(C:CharType)(int y, int x, C c) {
		if(move(y,x) == nc.ERR) return nc.ERR;
		return nc.waddch(c);
	}

	/** Put a string at the current position on the window
	 *
	 * @param str The string to put
	 */
	auto addstr(string str) {
		return nc.waddstr(m_raw, str.toStringz());
	}
	/** Move to a given position and put the given string
	 *
	 * @param y The row to go to
	 * @param x The column to go to
	 * @param c The string to put
	 */
	auto mvaddstr(int y, int x, string str) {
		if(move(y,x) == nc.ERR) {
			throw new NCursesError("Could not move to correct location");
		}
		return nc.waddstr(m_raw, str.toStringz());
	}

	/** Get a string from the window
	 */
	char[] getstr() {
		// Get as much data as possible
		auto ret = appender!string();
		int ch = nc.getch();
		while(!(ch=='\n' || ch == '\r' || ch == '\x04')) {
			ret.put(cast(char)ch);
			ch = nc.getch();
		}
		return ret.data.dup;
	}
	char[] getstr(int maxlen) {
		// We know the max length
		char[] ret = new char[maxlen];
		if(nc.getnstr(ret.ptr,maxlen) == nc.OK) {
			// All good!
			return ret[0..$];
		} else {
			// Something's wrong
			throw new NCursesError("Error receiving input");
		}
	}


	// Updating
	auto refresh() {
		return nc.wrefresh(m_raw);
	}
	auto erase() {
		return nc.werase(m_raw);
	}


	// Movement and X/Y
	auto move(int y, int x) {
		return nc.wmove(m_raw,y,x);
	}
	@property auto cur() {
		return Pos(nc.getcury(m_raw), nc.getcurx(m_raw));
	}
	@property auto beg() {
		return Pos(nc.getbegy(m_raw), nc.getbegx(m_raw));
	}
	@property auto max() {
		return Pos(nc.getmaxy(m_raw), nc.getmaxx(m_raw));
	}
	@property auto par() {
		return Pos(nc.getpary(m_raw), nc.getparx(m_raw));
	}


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

// Wrap the original ncurses implementations
public Window stdwin;
auto initscr() {
	nc.initscr(); // Call library initscr
	stdwin = new Window(nc.stdscr); // Bind our standard window
	return stdwin;
}
auto endwin() {
	return nc.endwin();
}
