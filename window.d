/**
 * @file window.d
 * @brief D ncurses window class wrappers
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Nov 12, 2012
 * @version 0.0.1
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


///Positioning style for subwindow creation
enum Positioning {
	/// Windows are created with coordinates relative to the parent window
	Relative,
	/// Windows are created with coordinates relative to the screen
	Absolute
}


/// Window wrapper
class Window {
	/// @cond NoDoc
	package {
		Window m_parent = null;
		Window[] m_children = [];
		nc.WINDOW* m_raw;
		bool currKeypad=false;
		bool currMeta = false;

		// Handle coordinate functions
		mixin template Coord(string name) {
			const Coord() @property nothrow const {
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

	/**
	 * Constructor from a C-style window
	 *
	 * @param raw The base ncurses window to use
	 */
	package this(nc.WINDOW* raw)
	in {
		assert(raw);
	} body {
		m_raw = raw;
	}

	/**
	 * Construct an ncurses Window
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

	/**
	 * Construct an ncurses Window
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
	/// @endcond

	/**
	 * Get the window's parent
	 *
	 * @return The parent window of the current window
	 */
	Window parent() @property {
		return m_parent;
	}

	/**
	 * Duplicate a window
	 *
	 * @return A copy window of the current window
	 */
	Window dup() @property {
		return new Window(nc.dupwin(m_raw));
	}

	/**
	 * Resize a window
	 *
	 * @param rows The number of rows the window contains
	 * @param columns The number of columns the window contains
	 */
	void resize(int rows, int columns) {
		if(nc.wresize(m_raw, rows, columns) != nc.OK) {
			throw new NCursesException("Error resizing window");
		}
	}

	/**
	 * Delete window
	 *
	 * Performs all operations needed to properly clean up a window
	 */
	~this() {
		foreach(c;m_children) {
			c.destroy();
		}
		nc.delwin(m_raw);
		m_raw = null;
	}

	/**
	 * Set getch's nodelay option
	 *
	 * If this is set to true, then getch is nonblocking
	 * Otherwise, it's blocking
	 *
	 * @param bf true if calls to getch should be nonblocking
	 */
	void nodelay(bool bf) @property {
		if(nc.nodelay(m_raw,bf) != nc.OK) {
			throw new NCursesException("Cannot set blocking status of window");
		}
	}
	/**
	 * Set getch's timeout option
	 *
	 * If this is set to a negative number, then getch is blocking
	 * If this is set to 0, then nonblocking read is used
	 * If this is set to a positive number, then getch will block for delay milliseconds.
	 *
	 * @param delay The delay value
	 */
	void timeout(int delay) @property {
		nc.wtimeout(m_raw,delay);
	}
	/**
	 * Enable the user's keypad
	 *
	 * @param enabled true to enable keypad detection, false otherwise
	 */
	void keypad(bool enabled) @property {
		if(nc.keypad(m_raw,(currKeypad=enabled)) != nc.OK) {
			throw new NCursesException("Cannot set keypad recognition for window");
		}
	}
	/**
	 * Enable 8 significant digits of input
	 *
	 * @param enabled true to enable meta keys, false otherwise
	 */
	void meta(bool enabled) @property {
		if(nc.meta(m_raw,(currMeta=enabled)) != nc.OK) {
			throw new NCursesException("Cannot set meta key recognition for window");
		}
	}


	// Output

	/// Delete the character under the cursor
	void delch() {
		if(nc.wdelch(m_raw) != nc.OK) {
			throw new NCursesException("Error deleting a character");
		}
	}
	void delch(Pos p...) {
		this.cursor(p.y, p.x);
		this.delch();
	}


	/**
	 * @name Output functions
	 * @{
	 */
	auto put(T:string)(T str) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.waddstr(m_raw, str.toStringz()) != nc.OK) {
			throw new NCursesException("Error adding string");
		}
		return this;
	}
	auto put(T:Pos)(T p) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wmove(m_raw, p.y, p.x) != nc.OK) {
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
		if(nc.wattrset(this.m_raw, newAttr) != nc.OK) {
			throw new NCursesException("Could not set attributes");
		}
		if(nc.waddstr(this.m_raw, str.str.toStringz()) != nc.OK) {
			throw new NCursesException("Error adding string");
		}
		if(nc.wattrset(this.m_raw, oldAttr) != nc.OK) {
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
	/// @cond NoDoc
	alias print = put;
	/// @endcond
	/// @}

	/**
	 * @name Window background
	 * @{
	 */
	/**
	 * Apply a set of attributes to the background of a window
	 *
	 * @fn bkgd(TextAttribute[] attrs ...)
	 * @param attrs The attributes to apply
	 * @return this
	*/
	auto bkgd(TextAttribute[] attrs ...) {
		foreach(attr;attrs) {
			attr.bkgd(m_raw);
		}
		return this;
	}
	/**
	 * Set the background character
	 *
	 * @fn bkgd(char c)
	 * @param c The new background character
	 * @return this
	*/
	auto bkgd(char c) {
		nc.wbkgdset(m_raw, (nc.getbkgd(m_raw)&~nc.A_CHARTEXT)|c);
		return this;
	}
	/**
	 * Apply a set of attributes and background character to a window
	 *
	 * @fn bkgd(char c, TextAttribute[] attrs ...)
	*/
	auto bkgd(char c, TextAttribute[] attrs ...) {
		return bkgd(c).bkgd(attrs);
	}
	/**
	 * Retrieve the background information from a character
	 *
	 * @fn bkgd()
	 * @return The background information
	*/
	auto bkgd() {
		return nc.getbkgd(m_raw);
	}
	/// @}




	// Input

	/**
	 * Get a single keypress
	 *
	 * @return The pressed key
	 */
	auto getch() {
		return nc.wgetch(m_raw);
	}
	auto getch(Pos p...) {
		this.cursor(p.y, p.x);
		return this.getch();
	}

	/**
	 * Get a string from the window
	 *
	 * @todo Rewrite to better handle edge cases
	 * @return The string entered by the user
	 */
	string getstr() {
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
		return ret.idup;
	}
	/**
	 * Get a string from the window
	 *
	 * @param maxlen The maximum length of a string to get
	 * @return The string entered by the user
	 */
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


	/**
	 * @name Updating
	 * @{
	 */
	/**
	 * Refresh the window display
	 */
	void refresh() {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wrefresh(m_raw) != nc.OK) {
			throw new NCursesException("Could not refresh window");
		}
	}
	/**
	 * Blank out the window
	 */
	void erase() {
		if(nc.werase(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/**
	 * Blank out the window and repaint on next refresh
	 */
	void clear() {
		if(nc.wclear(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/**
	 * Blank out the window from the cursor to the end of the screen
	 */
	void clrtobot() {
		if(nc.wclrtobot(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/**
	 * Blank out the window from the cursor to the end of the line
	 */
	void clrtoeol() {
		if(nc.wclrtoeol(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}

	/**
	 * Tell the window to redraw everything
	 */
	void touch() {
		if(nc.touchwin(m_raw) != nc.OK) {
			throw new NCursesException("Error touching window");
		}
	}
	/**
	 * Tell the window to redraw a specific area
	 *
	 * @param start The starting line number
	 * @param count The number of lines to touch
	 */
	void touch(int start, int count) {
		if(nc.touchline(m_raw, start, count) != nc.OK) {
			throw new NCursesException("Error touching lines");
		}
	}
	/**
	 * Touch all parent locations that are changed in win
	 */
	void sync() {
		nc.wsyncup(m_raw);
	}
	/**
	 * Automatically call sync when the window is updated
	 *
	 * @param isOk true to automatically sync, false otherwise
	 * @return isOk
	 */
	bool syncok(bool isOk) @property {
		if(nc.syncok(m_raw, isOk) != nc.OK) {
			throw new NCursesException("Error setting sync status");
		}
		return isOk;
	}
	/// @}

	/**
	 * Allow or disable scrolling
	 *
	 * Tell the window whether it is allowed to scroll upon print
	 *
	 * @param isOk Whether scrolling is allowed or not
	 */
	void scrollok(bool isOk) @property {
		nc.scrollok(m_raw, isOk);
	}


	/**
	 * @name Movement and Coordinates
	 * @{
	 */
	/**
	 * Move the cursor position
	 *
	 * @param y The row to move to
	 * @param x The column to move to
	 */
	void cursor(int y, int x) {
		if(nc.wmove(m_raw,y,x) != nc.OK) {
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
	 * Move the current window
	 *
	 * The current window is moved relative to the screen.
	 * Coordinates are given for the top left corner of the window
	 *
	 * @param y The row to move to
	 * @param x The column to move to
	 */
	void move(int y, int x) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.mvwin(m_raw, y, x) != nc.OK) {
			throw new NCursesException("Could not move window to correct location");
		}
		this.refresh();
	}
	/// @}


	/**
	 * @name Borders
	 * @{
	 */

	/**
	 * Create a border around the current window
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
		this.refresh();
	}
	/**
	 * Create a box around the current window
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
		this.refresh();
	}
	/// @}

	// Flags
	/// Is this a sub-window?
	bool subwin() @property @safe nothrow const {return (m_raw.flags & nc._SUBWIN) != 0;}
	/// Is the window flush right?
	bool endline() @property @safe nothrow const {return (m_raw.flags & nc._ENDLINE) != 0;}
	/// Is the window full-screen?
	bool fullwin() @property @safe nothrow const {return (m_raw.flags & nc._FULLWIN) != 0;}
	/// Bottom edge is at screen bottom?
	bool scrollwin() @property @safe nothrow const {return (m_raw.flags & nc._SCROLLWIN) != 0;}
	/// Has cursor moved since last refresh?
	bool hasmoved() @property @safe nothrow const {return (m_raw.flags & nc._HASMOVED) != 0;}
	/// Cursor was just wrappped
	bool wrapped() @property @safe nothrow const {return (m_raw.flags & nc._WRAPPED) != 0;}
}
