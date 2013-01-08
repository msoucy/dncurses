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


/** @brief Positioning style for subwindow creation
*/
enum Positioning {
	/// Windows are created with coordinates relative to the parent window
	Relative,
	/// Windows are created with coordinates relative to the screen
	Absolute
}


/** @brief Window wrapper
 */
class Window {
	private {
		Window m_parent = null;
		Window[] m_children = [];
		nc.WINDOW* m_raw;
		bool currKeypad=false;
		bool currMeta = false;

		// Handle coordinate functions
		mixin template Coord(string name) {
			@property @trusted nothrow const Coord() const {
				return mixin("Pos(m_raw."~name~"y, m_raw."~name~"x)");
			}
			mixin("alias Coord "~name~";");
		}

		mixin template MoveWrapper(string Func) {
			auto MoveWrapper(T...)(int y, int x, T t) {
				this.cursor(y,x);
				return mixin(Func~"(t)");
			}
			mixin("alias MoveWrapper mv"~Func~";");
		}
	}

	/// @cond NoDoc
	/** Constructor from a C-style window
	 * @param raw The base ncurses window to use
	 */
	package this(nc.WINDOW* raw)
	in {
		assert(raw);
	} body {
		m_raw = raw;
	}

	/** Construct an ncurses Window
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
	/// @endcond

	/** @brief Get the window's parent
		@return The parent window of the current window
	*/
	@property Window parent() {
		return m_parent;
	}

	/** @brief Duplicate a window
		@return A copy window of the current window
	*/
	@property Window dup() {
		return new Window(nc.dupwin(m_raw));
	}

	/** @brief Resize a window
		@param rows The number of rows the window contains
		@param columns The number of columns the window contains
	*/
	void resize(int rows, int columns) {
		if(nc.wresize(m_raw, rows, columns) == nc.ERR) {
			throw new NCursesException("Error resizing window");
		}
	}

	/** @brief Delete window
		
		Performs all operations needed to properly clean up a window
	*/
	void delwin() {
		foreach(c;m_children) {
			c.delwin();
		}
		nc.delwin(m_raw);
		m_raw = null;
	}

	@property auto nodelay(bool bf) {
		return nc.nodelay(m_raw,bf);
	}
	@property auto timeout(int delay) {
		return nc.wtimeout(m_raw,delay);
	}
	@property auto keypad(bool enabled) {
		return nc.keypad(m_raw,(currKeypad=enabled));
	}
	@property auto meta(bool enabled) {
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
	/// @cond NoDoc
	mixin MoveWrapper!"delch";
	/// @endcond


	/// @name Output functions
	/// @{
	auto put(T:string)(T str) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.waddstr(m_raw, str.toStringz()) == nc.ERR) {
			throw new NCursesException("Error adding string");
		}
		return this;
	}
	auto put(T:Pos)(T p) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wmove(m_raw, p.y, p.x) == nc.ERR) {
			throw new NCursesException("Could not move cursor to correct location");
		}
		return this;
	}
	auto put(T:AttributeString)(T str) {
		if(parent !is null) {
			parent.refresh();
		}
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
	auto put(T:TextAttribute)(T attr) {
		if(parent !is null) {
			parent.refresh();
		}
		attr.apply(m_raw);
		return this;
	}
	auto put(T)(T t) {
		return this.put(t.to!string());
	}
	auto put(T...)(T t) {
		if(parent !is null) {
			parent.refresh();
		}
		foreach(val;t) {
			this.put(val);
		}
		return this;
	}
	/// @}
	/// @cond NoDoc
	alias put print;
	/// @endcond

	/// @name Window background
	/// @{
	/** @fn bkgd(TextAttribute[] attr ...)
	 * @brief Apply a set of attributes to the background of a window
	 * @param attrs The attributes to apply
	*/
	auto bkgd(TextAttribute[] attrs ...) {
		foreach(attr;attrs) {
			attr.bkgd(m_raw);
		}
		return this;
	}
	auto bkgd(char c) {
		nc.wbkgdset(m_raw, (nc.getbkgd(m_raw)&~nc.A_CHARTEXT)|c);
		return this;
	}
	auto bkgd(char c, TextAttribute[] attrs ...) {
		return bkgd(c).bkgd(attrs);
	}
	auto bkgd() {
		return nc.getbkgd(m_raw);
	}
	/// @}




	// Input

	/**
	 * Get a single keypress
	 * @return The pressed key
	 */
	auto getch() {
		return nc.wgetch(m_raw);
	}
	/// @cond NoDoc
	mixin MoveWrapper!"getch";
	/// @endcond

	/** Get a string from the window
	 * @return The string input by the user
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
							cursor(cur.y, cur.x-1);
							delch();
						} else {
							cursor(cur.y-1, max.x);
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
	/// @cond NoDoc
	mixin MoveWrapper!"getstr";
	/// @endcond


	// Updating
	void refresh() {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wrefresh(m_raw) == nc.ERR) {
			throw new NCursesException("Could not refresh window");
		}
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

	/** @brief Allow or disable scrolling

		Tell the window whether it is allowed to scroll upon print

		@param isOk Whether scrolling is allowed or not
	*/
	@property void scrollok(bool isOk) {
		nc.scrollok(m_raw, isOk);
	}


	/// @name Movement and Coordinates
	/// @{
	/**
	 * @brief Move the cursor position
	 * 
	 * @param y The row to move to
	 * @param x The column to move to
	*/
	void cursor(int y, int x) {
		if(nc.wmove(m_raw,y+beg.y,x+beg.x) == nc.ERR) {
			throw new NCursesException("Could not move cursor to correct location");
		}
	}

	/// Get the current position
	mixin Coord!"cur";
	/// Get the window's beginning position
	mixin Coord!"beg";
	/// Get the window's maximum position
	mixin Coord!"max";
	/// Get the window's beginning position relative to its parent
	mixin Coord!"par";

	/**
	 * @brief Move the current window
	 *
	 * The current window is moved relative to the screen.
	 * Coordinates are given for the top left corner of the window
	 *
	 * @param y The row to move to
	 * @param x The column to move to
	*/
	void movewin(int y, int x) {
		if(nc.mvderwin(m_raw, y, x) == nc.ERR) {
			throw new NCursesException("Could not move window to correct location");
		}
	}
	/// @}


	/// @name Borders
	/// @{

	/**
	 * @brief Create a border around the current window
	 * 
	 * The border takes up the first and last rows and columns inside the window.
	 * If 0 is used for any argument, the default character is used instead.
	 * 
	 * @param ls The character to use for the left side. Default to ACS.VLINE
	 * @param rs The character to use for the right side. Default to ACS.VLINE
	 * @param ts The character to use for the top. Default to ACS.HLINE
	 * @param bs The character to use for the bottom. Default to ACS.HLINE
	 * @param tl The character to use for the top left corner. Default to ACS.ULCORNER
	 * @param tr The character to use for the top right corner. Default to ACS.URCORNER
	 * @param bl The character to use for the bottom left corner. Default to ACS.LLCORNER
	 * @param br The character to use for the bottom right corner. Default to ACS.LRCORNER
	*/
	void border(CharType ls = 0, CharType rs = 0, CharType ts = 0, CharType bs = 0,
		CharType tl = 0, CharType tr = 0, CharType bl = 0, CharType br = 0)
	{
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wborder(m_raw, ls, rs, ts, bs, tl, tr, bl, br) != nc.OK) {
			throw new NCursesException("Could not draw border");
		}
	}
	/**
	 * @brief Create a box around the current window
	 * 
	 * The border takes up the first and last rows and columns inside the window.
	 * If 0 is used for any argument, the default character is used instead.
	 * Equivalent to:
	 * @code border(verch, verch, horch, horch, 0, 0, 0, 0) @endcode
	 * 
	 * @param verch The character to use for the vertical sides
	 * @param horch The character to use for the horizontal sides
	*/
	void box(CharType verch, CharType horch)
	{
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wborder(m_raw, verch, verch, horch, horch, 0, 0, 0, 0) != nc.OK) {
			throw new NCursesException("Could not draw box");
		}
	}
	/// @}

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
