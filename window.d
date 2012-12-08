/** @file window.d
	@brief D ncurses window class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses window class wrappers
module metus.dncurses.window;


/// @cond NoDoc
import std.string : toStringz, xformat, strlen;
import std.algorithm : canFind;
import std.conv : to;
private import nc = deimos.ncurses.ncurses;
public import metus.dncurses.base;
public import metus.dncurses.attrstring;
/// @endcond


/// Positioning style for subwindow creation
enum Positioning {
	/// Windows are created with coordinates relative to the parent window
	Relative,
	/// Windows are created with coordinates relative to the screen
	Absolute
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
		@property auto Coord() {
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

	class AttributeHandler {
	private:
		Window outer;
		void apply() {
			if(nc.wattrset(this.outer.m_raw, outer.m_raw.attrs) == nc.ERR) {
				throw new NCursesException("Could not set attributes");
			}
		}
		@property CharType get() {
			return outer.m_raw.attrs;
		}
	public:
		this(Window w) {
			outer=w;
		}
		AttributeHandler opAssign(CharType newattrs) {
			outer.m_raw.attrs = newattrs;
			apply();
			return this;
		}
		AttributeHandler opOpAssign(string op)(CharType newattrs)
		if(["|=","&="].canFind(op)) {
			mixin("outer.m_raw.attrs "~op~" newattrs;");
			apply();
			return this;
		}

		alias get this;
	}

	AttributeHandler attributes;

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

	/** Print to a window with printf functionality
	 *
	 * @param fmt The format specifier
	 */
	void printf(T...)(string fmt, T d) {
		string ret = xformat(fmt, d);
		if(nc.waddstr(m_raw, ret.toStringz()) == nc.ERR) {
			throw new NCursesException("Error printing string");
		}
	}
	mixin MoveWrapper!"printf";

	/** Put a character at the current position on the window
	 *
	 * @param c The character (and attributes) to put
	 */
	void addch(CharType c) {
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


	//
	auto put(T:string)(T str) {
		if(nc.waddstr(m_raw, str.toStringz()) == nc.ERR) {
			throw new NCursesException("Error adding string");
		}
		return this;
	}
	auto put(T:CharType)(T c) {
		if(nc.waddch(m_raw, c) == nc.ERR) {
			throw new NCursesException("Error adding a character");
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
		if(nc.wattron(this.m_raw, str.attr) == nc.ERR) {
			throw new NCursesException("Could not set attributes");
		} else if(nc.wattroff(this.m_raw, str.noattr) == nc.ERR) {
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
	int hline(CharType ch, int n) {
		return nc.whline(m_raw, ch, n);
	}
	mixin MoveWrapper!"hline";
	int vline(CharType ch, int n) {
		return nc.wvline(m_raw, ch, n);
	}
	mixin MoveWrapper!"vline";


	// Attributes
	@property ref attr() {
		if(attributes is null) {
			attributes = new AttributeHandler(this);
		}
		return attributes;
	}

	// Flags
	/// Is this a sub-window?
	@property bool subwin() {return (m_raw.flags & nc._SUBWIN) != 0;}
	/// Is the window flush right?
	@property bool endline() {return (m_raw.flags & nc._ENDLINE) != 0;}
	/// Is the window full-screen?
	@property bool fullwin() {return (m_raw.flags & nc._FULLWIN) != 0;}
	/// Bottom edge is at screen bottom?
	@property bool scrollwin() {return (m_raw.flags & nc._SCROLLWIN) != 0;}
	/// Has cursor moved since last refresh?
	@property bool hasmoved() {return (m_raw.flags & nc._HASMOVED) != 0;}
	/// Cursor was just wrappped
	@property bool wrapped() {return (m_raw.flags & nc._WRAPPED) != 0;}
}
