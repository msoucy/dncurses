/** @file window.d
	@brief D ncurses window class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses window class wrappers
module metus.dncurses.window;


/// @cond NoDoc
import std.string : toStringz, format, toUpper;
import std.algorithm;
private import nc = deimos.ncurses.ncurses;
public import metus.dncurses.base;
/// @endcond


/// @cond NoDoc
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
	/// @{
	Horizontal = nc.A_HORIZONTAL,
	Left = nc.A_LEFT,
	Low = nc.A_LOW,
	Right = nc.A_RIGHT,
	Top = nc.A_TOP,
	Vertical = nc.A_VERTICAL,
	/// @}
}
/// @endcond

/// Flags for windows
immutable enum Flag {
	/// Is this a sub-window?
	subwin = 0x01,
    /// Is the window flush right?
    endline = 0x02,
    /// Is the window full-screen?
    fullwin = 0x04,
    /// Bottom edge is at screen bottom?
    scrollwin = 0x08,
    /// Is this window a pad?
    ispad = 0x10,
    /// Has cursor moved since last refresh?
    hasmoved = 0x20,
    /// Cursor was just wrappped
    wrapped = 0x40
}


/// Positioning style for subwindow creation
enum Positioning {
	/// Windows are created relative to the parent window
	Relative,
	/// Windows are created relative to the screen
	Absolute
}


/** @brief Window wrapper
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

package:
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
	 * @param ptype Absolute or relative positioning of subwindow
	 */
	this(Window myParent, int nlines, int ncols, int y0, int x0, Positioning ptype = Positioning.Absolute)
	in {
		assert(0 <= y0 && y0 < nc.getmaxy(nc.stdscr));
		assert(0 <= x0 && x0 < nc.getmaxx(nc.stdscr));
	}
	out {
		assert(m_raw);
	}
	body {
		m_parent = myParent;
		if(ptype == Positioning.Absolute) {
			m_raw = nc.subwin(m_parent.m_raw, nlines,ncols,y0,x0);
		} else {
			m_raw = nc.derwin(m_parent.m_raw, nlines,ncols,y0,x0);
		}
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
	void printf(T...)(string fmt, T d) {
		string ret = format(fmt, d);
		if(nc.waddstr(m_raw, ret.toStringz()) == nc.ERR) {
			throw new NCursesException("Error printing string");
		}
	}
	mixin MoveWrapper!"printf";

	/** Put a character at the current position on the window
	 *
	 * @param c The character (and attributes) to put
	 */
	void addch(C:CharType)(C c) {
		if(nc.waddch(m_raw, c) == nc.ERR) {
			throw new NCursesException("Error adding a character");
		}
	}
	mixin MoveWrapper!"addch";

	/** Delete the character under the cursor
	 */
	void delch() {
		if(nc.wdelch(m_raw) == nc.ERR) {
			throw new NCursesException("Error deleting a character");
		}
	}
	mixin MoveWrapper!"delch";

	/** Put a string at the current position on the window
	 *
	 * @param str The string to put
	 */
	void addstr(string str) {
		if(nc.waddstr(m_raw, str.toStringz()) == nc.ERR) {
			throw new NCursesException("Error adding string");
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
			throw new NCursesException("Error receiving input");
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
	auto touch() {
		return nc.touchwin(m_raw);
	}
	auto touch(int start, int count) {
		return nc.touchline(m_raw, start, count);
	}
	auto sync() {
		return nc.wsyncup(m_raw);
	}
	auto syncok(bool isOk) {
		return nc.syncok(m_raw, isOk);
	}


	// Movement and X/Y
	auto move(int y, int x) {
		if(nc.wmove(m_raw,y,x) == nc.ERR) {
			throw new NCursesException("Could not move cursor to correct location");
		}
	}

	mixin Coord!"cur";
	mixin Coord!"beg";
	mixin Coord!"max";
	mixin Coord!"par";

	// Move window
	auto movewin(int y, int x) {
		if(nc.mvderwin(m_raw, y, x) == nc.ERR) {
			throw new NCursesException("Could not move window to correct location");
		}
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
