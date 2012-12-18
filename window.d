/** @file window.d
	@brief D ncurses window class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses window class wrappers
module metus.dncurses.window;


/// @cond NoDoc
import std.string : strlen, toStringz;
import std.algorithm : canFind;
import std.conv : to;
public import metus.dncurses.base;
public import metus.dncurses.formatting;
/// @endcond


/// Positioning style for subwindow creation
enum Positioning {
	/// Windows are created with coordinates relative to the parent window
	Relative,
	/// Windows are created with coordinates relative to the screen
	Absolute
}

struct hline {
private:
	CharType m_char;
	int m_n;
public:
	nothrow this(CharType ch, int n) {
		m_char = ch;
		m_n = n;
	}
}

struct vline {
private:
	CharType m_char;
	int m_n;
public:
	nothrow this(CharType ch, int n) {
		m_char = ch;
		m_n = n;
	}
}


/** @brief Window wrapper
 */
class Window {
private:
	Window m_parent = null;
	Window[] m_children = [];
	nc.WINDOW* m_raw;
	bool currKeypad=false;
	bool currMeta = false;

	// Handle coordinate functions
	mixin template Coord(string name) {
		@property @trusted nothrow auto Coord() const {
			return mixin("Pos(m_raw."~name~"y, m_raw."~name~"x)");
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
		assert(0 <= y0 && y0 <= nc.getmaxy(nc.stdscr));
		assert(0 <= x0 && x0 <= nc.getmaxx(nc.stdscr));
	}
	out {
		assert(m_raw);
	}
	body {
		m_parent = myParent;
		m_parent.m_children ~= this;
		if(ptype == Positioning.Absolute) {
			m_raw = nc.subwin(m_parent.m_raw, nlines,ncols,y0,x0);
		} else {
			m_raw = nc.derwin(m_parent.m_raw, nlines,ncols,y0,x0);
		}
	}

	@property Window parent() {
		return m_parent;
	}

	@property Window dup() {
		return new Window(nc.dupwin(m_raw));
	}

	void delwin() {
		foreach(c;m_children) {
			c.delwin();
		}
		nc.delwin(m_raw);
		m_raw = null;
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

	/** Delete the character under the cursor
	 */
	void delch() {
		if(nc.wdelch(m_raw) == nc.ERR) {
			throw new NCursesException("Error deleting a character");
		}
	}
	mixin MoveWrapper!"delch";


	// Output functions
	auto put(T:string)(T str) {
		if(nc.waddstr(m_raw, str.toStringz()) == nc.ERR) {
			throw new NCursesException("Error adding string");
		}
		return this;
	}
	auto put(T:Pos)(T p) {
		if(nc.wmove(m_raw, p.y, p.x) == nc.ERR) {
			throw new NCursesException("Could not move cursor to correct location");
		}
		return this;
	}
	auto put(T:AttributeString)(T str) {
		nc.attr_t oldAttr = m_raw.attrs;
		nc.attr_t newAttr = ((str.attr|this.m_raw.attrs)&~str.attrDisable) | (str.attr & str.attrDisable & nc.A_COLOR);
		if(nc.wattrset(this.m_raw, newAttr) == nc.ERR) {
			throw new NCursesException("Could not set attributes");
		}
		if(nc.waddstr(this.m_raw, str.str.toStringz()) == nc.ERR) {
			throw new NCursesException("Error adding string");
		}
		if(nc.wattrset(this.m_raw, oldAttr) == nc.ERR) {
			throw new NCursesException("Could not set attributes");
		}
		return this;
	}
	auto put(T:hline)(T line) {
		// ncurses doesn't do error handling for this
		nc.whline(m_raw, line.m_char, line.m_n);
		return this;
	}
	auto put(T:vline)(T line) {
		// ncurses doesn't do error handling for this
		nc.wvline(m_raw, line.m_char, line.m_n);
		return this;
	}
	auto put(T:TextAttribute)(T attr) {
		attr.apply(m_raw);
		return this;
	}
	auto put(T)(T t) {
		this.put(t.to!string());
		return this;
	}
	auto put(T...)(T t) {
		foreach(val;t) {
			this.put(val);
		}
		return this;
	}
	alias put print;

	auto bkgd(TextAttribute attr) {
		attr.bkgd(m_raw);
		return this;
	}




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
					put(cast(char)buf);
				}
			}
		}
		return ret.dup;
	}
	string getstr(int maxlen) {
		// We know the max length
		char[] ret = new char[maxlen];
		if(nc.getnstr(ret.ptr,maxlen) == nc.OK) {
			// All good!
			return ret[0..strlen(ret.ptr)].idup;
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
	int border(CharType ls = cast(CharType)0, CharType rs = cast(CharType)0,
		CharType ts = cast(CharType)0, CharType bs = cast(CharType)0,
		CharType tl = cast(CharType)0, CharType tr = cast(CharType)0,
		CharType bl = cast(CharType)0, CharType br = cast(CharType)0)
	{
		return nc.wborder(m_raw, ls, rs, ts, bs, tl, tr, bl, br);
	}
	int box(CharType verch, CharType horch)
	{
		return nc.wborder(m_raw, verch, verch, horch, horch, 0, 0, 0, 0);
	}

	// Flags
	/// Is this a sub-window?
	@property @safe nothrow bool subwin() const {return (m_raw.flags & nc._SUBWIN) != 0;}
	/// Is the window flush right?
	@property @safe nothrow bool endline() const {return (m_raw.flags & nc._ENDLINE) != 0;}
	/// Is the window full-screen?
	@property @safe nothrow bool fullwin() const {return (m_raw.flags & nc._FULLWIN) != 0;}
	/// Bottom edge is at screen bottom?
	@property @safe nothrow bool scrollwin() const {return (m_raw.flags & nc._SCROLLWIN) != 0;}
	/// Has cursor moved since last refresh?
	@property @safe nothrow bool hasmoved() const {return (m_raw.flags & nc._HASMOVED) != 0;}
	/// Cursor was just wrappped
	@property @safe nothrow bool wrapped() const {return (m_raw.flags & nc._WRAPPED) != 0;}
}
