/*******************************************************************************
 * Window wrappers
 *
 * Author: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Nov 12, 2012
 * Version: 0.0.1
 */
module metus.dncurses.window;


import std.string : strlen, toStringz;
import std.algorithm : canFind;
import std.conv : to;
public import metus.dncurses.base;
public import metus.dncurses.formatting;
import metus.dncurses.mode;


///Positioning style for subwindow creation
enum Positioning {
	/// Windows are created with coordinates relative to the parent window
	Relative,
	/// Windows are created with coordinates relative to the screen
	Absolute
}


/// Window wrapper
class Window {
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
	}

	/**
	 * Constructor from a C-style window
	 *
	 * Param:
	 * 		raw	=	The base ncurses window to use
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
	 * Param:
	 * 		nlines	=	The number of lines for the window
	 * 		lcols	=	The number of columns for the window
	 * 		y0	=	The number of the first row that the window uses
	 * 		x0	=	The number of the first column that the window uses
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
	 * Param:
	 * 		myParent	=	The parent window of the window to be created
	 * 		nlines	=	The number of lines for the window
	 * 		lcols	=	The number of columns for the window
	 * 		y0	=	The number of the first row that the window uses
	 * 		x0	=	The number of the first column that the window uses
	 * 		ptype	=	Absolute or relative positioning of subwindow
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

	/**
	 * Get the window's parent
	 *
	 * Returns: The parent window of the current window
	 */
	nc.WINDOW* raw() @property {
		return m_raw;
	}

	/**
	 * Get the window's parent
	 *
	 * Returns: The parent window of the current window
	 */
	Window parent() @property {
		return m_parent;
	}

	/**
	 * Duplicate a window
	 *
	 * Returns: A copy window of the current window
	 */
	Window dup() @property {
		return new Window(nc.dupwin(m_raw));
	}

	/**
	 * Resize a window
	 *
	 * Param:
	 * 		rows	=	The number of rows the window contains
	 * 		columns	=	The number of columns the window contains
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
	 * Param:
	 * 		bf	=	true if calls to getch should be nonblocking
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
	 * Param:
	 * 		delay	=	The delay value
	 */
	void timeout(int delay) @property {
		nc.wtimeout(m_raw,delay);
	}
	/**
	 * Enable the user's keypad
	 *
	 * Param:
	 * 		enabled	=	true to enable keypad detection, false otherwise
	 */
	void keypad(bool enabled) @property {
		if(nc.keypad(m_raw,(currKeypad=enabled)) != nc.OK) {
			throw new NCursesException("Cannot set keypad recognition for window");
		}
	}
	/**
	 * Enable 8 significant digits of input
	 *
	 * Param:
	 * 		enabled	=	true to enable meta keys, false otherwise
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
	/**
	 * Delete a character
	 *
	 * Param:
	 * 		row	=	The row of the character to move to
	 * 		col	=	The column of the character to move to
	 */
	void delch(int row, int col) {
		this.cursor(row, col);
		this.delch();
	}
	/**
	 * Delete a character
	 *
	 * Param:
	 * 		pos	=	The position of the character to move to
	 */
	void delch(Pos pos) {
		delch(pos.y, pos.x);
	}


	/// Output data to the window
	auto put(T:string)(T str) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.waddstr(m_raw, str.toStringz()) != nc.OK) {
			throw new NCursesException("Error adding string");
		}
		return this;
	}
	/// ditto
	auto put(T:Pos)(T p) {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wmove(m_raw, p.y, p.x) != nc.OK) {
			throw new NCursesException("Could not move cursor to correct location");
		}
		return this;
	}
	/// ditto
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
	/// ditto
	auto put(T:TextAttribute)(T attr) {
		if(parent !is null) {
			parent.refresh();
		}
		attr.apply(m_raw);
		return this;
	}
	/// ditto
	auto put(T)(T t) {
		return this.put(t.to!string());
	}
	/// ditto
	auto put(T...)(T t) {
		if(parent !is null) {
			parent.refresh();
		}
		foreach(val;t) {
			this.put(val);
		}
		return this;
	}
	/// ditto
	alias print = put;

	/**
	 * Apply a set of attributes to the background of a window
	 *
	 * Param:
	 * 		attrs	=	The attributes to apply
	 * Returns: this
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
	 * Param:
	 * 		c	=	The new background character
	 * Returns: this
	*/
	auto bkgd(char c) {
		nc.wbkgdset(m_raw, (nc.getbkgd(m_raw)&~nc.A_CHARTEXT)|c);
		return this;
	}
	/**
	 * Apply a set of attributes and background character to a window
	*/
	auto bkgd(char c, TextAttribute[] attrs ...) {
		return bkgd(c).bkgd(attrs);
	}
	/**
	 * Retrieve the background information from a character
	 *
	 * Returns: The background information
	*/
	auto bkgd() {
		return nc.getbkgd(m_raw);
	}




	// Input

	/**
	 * Get a single keypress
	 *
	 * Returns: The pressed key
	 */
	auto getch() {
		return nc.wgetch(m_raw);
	}
	/**
	 * Get a single keypress
	 *
	 * Moves to a given position before getting the character
	 *
	 * Param:
	 * 		row	=	The row to move to
	 * 		col	=	The column to move to
	 * Returns: The pressed key
	 */
	auto getch(int row, int col) {
		this.cursor(row, col);
		return this.getch();
	}
	/**
	 * Get a single keypress
	 *
	 * Moves to a given position before getting the character
	 *
	 * Param:
	 * 		p	=	The position to move to
	 * Returns: The pressed key
	 */
	auto getch(Pos p) {
		return this.getch(p.y, p.x);
	}

	/**
	 * Get a string from the window
	 *
	 * Returns: The string entered by the user
	 */
	string getstr() {
		// Make sure not to output directly
		auto oldecho = echo(false);
		scope(exit) echo(oldecho);
		auto oldmode = mode;
		mode = Cooked(SetFlags.Yes);
		mode = CBreak();
		scope(exit) mode = oldmode;

		if (nc.is_wintouched(m_raw) || this.hasmoved) {
			nc.wrefresh(m_raw);
		}

		char[] str;
		CharType ch;
		int y = this.cur.y;
		int x = this.cur.x;

		void WipeOut()
		{
			// Adapted from the original ncurses' WipeOut.
			// This one uses the external scope to make it simpler
			if (str.length) {
				str.length -= 1;
				if (oldecho) {
					auto oldpos = this.cur;

					this.put(Pos(y, x), str);
					auto newpos = this.cur;
					// Clear the removed character
					while (this.cur.y < oldpos.y || (this.cur.y == oldpos.y && this.cur.x < oldpos.x)) {
						nc.waddch(m_raw, ' ');
					}
					// Go back to the correct position
					this.cursor(newpos);
				}
			}
		}

		auto erasech = erasechar();
		auto killch = killchar();

		/**
		 * This is also translated/partially transliterated from the original ncurses' getnstr
		 * This is the only way that I can see to get the same behavior with dynamic strings
		 */
		while ((ch = nc.wgetch(m_raw)) != nc.ERR) {
			/*
			 * Some terminals (the Wyse-50 is the most common) generate
			 * a \n from the down-arrow key.  With this logic, it's the
			 * user's choice whether to set kcud=\n for wgetch();
			 * terminating *getstr() with \n should work either way.
			 */
			if (['\n', '\r', Key.Down, Key.Enter].canFind(ch)) {
				if (oldecho && this.cur.y == this.max.y && m_raw.scroll) {
					nc.wechochar(m_raw, '\n');
				}
				break;
			}
			if ([Key.Event, Key.Resize].canFind(ch)) {
				break;
			}

			if ([erasech, Key.Left, Key.Backspace].canFind(ch)) {
				// Remove the last character
				WipeOut();
			} else if (ch == killch) {
				// "Undo" printing the created string
				while (str.length) {
					WipeOut();
				}
			} else if (ch >= Key.Min) {
				// Control character
				nc.beep();
			} else {
				str ~= cast(char) ch;
				if (oldecho) {
					int oldy = this.cur.y;
					if (nc.waddch(m_raw, ch) == nc.ERR) {
						/*
						 * We can't really use the lower-right
						 * corner for input, since it'll mess
						 * up bookkeeping for erases.
						 */
						m_raw.flags &= ~nc._WRAPPED;
						nc.waddch(m_raw, ' ');
						WipeOut();
						continue;
					} else if (m_raw.flags & nc._WRAPPED) {
						/*
						 * If the last waddch forced a wrap &
						 * scroll, adjust our reference point
						 * for erasures.
						 */
						if (m_raw.scroll && oldy == this.max.y && this.cur.y == this.max.y) {
							y = (y ? (y-1) : 0);
						}
						m_raw.flags &= ~nc._WRAPPED;
					}
					nc.wrefresh(m_raw);
				}
			}
		}

		return str.idup;
	}
	/**
	 * Get a string from the window
	 *
	 * Param:
	 * 		maxlen	=	The maximum length of a string to get
	 * Returns: The string entered by the user
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
	/**
	 * Get a string from the window
	 *
	 * Moves to a given position before getting the string
	 *
	 * Param:
	 * 		row	=	The row to move to
	 * 		col	=	The column to move to
	 * Returns: The string entered by the user
	 */
	auto getstr(int row, int col) {
		this.cursor(row, col);
		return this.getstr();
	}
	/**
	 * Get a string from the window
	 *
	 * Moves to a given position before getting the string
	 *
	 * Param:
	 * 		row	=	The row to move to
	 * 		col	=	The column to move to
	 * 		maxlen	=	The maximum length of a string to get
	 * Returns: The string entered by the user
	 */
	auto getstr(int row, int col, int maxlen) {
		this.cursor(row, col);
		return this.getstr(maxlen);
	}
	/**
	 * Get a string from the window
	 *
	 * Moves to a given position before getting the string
	 *
	 * Param:
	 * 		p	=	The position to move to
	 * Returns: The string entered by the user
	 */
	auto getstr(Pos p) {
		this.cursor(p.y, p.x);
		return this.getstr();
	}
	/**
	 * Get a string from the window
	 *
	 * Moves to a given position before getting the string
	 *
	 * Param:
	 * 		p	=	The position to move to
	 * 		maxlen	=	The maximum length of a string to get
	 * Returns: The string entered by the user
	 */
	auto getstr(Pos p, int maxlen) {
		this.cursor(p.y, p.x);
		return this.getstr(maxlen);
	}


	/// Refresh the window display
	void refresh() {
		if(parent !is null) {
			parent.refresh();
		}
		if(nc.wrefresh(m_raw) != nc.OK) {
			throw new NCursesException("Could not refresh window");
		}
	}
	/// Blank out the window
	void erase() {
		if(nc.werase(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/// Blank out the window and repaint on next refresh
	void clear() {
		if(nc.wclear(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/// Blank out the window from the cursor to the end of the screen
	void clrtobot() {
		if(nc.wclrtobot(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}
	/// Blank out the window from the cursor to the end of the line
	void clrtoeol() {
		if(nc.wclrtoeol(m_raw) != nc.OK) {
			throw new NCursesException("Could not erase window");
		}
	}

	/// Tell the window to redraw everything
	void touch() {
		if(nc.touchwin(m_raw) != nc.OK) {
			throw new NCursesException("Error touching window");
		}
	}
	/**
	 * Tell the window to redraw a specific area
	 *
	 * Param:
	 * 		start	=	The starting line number
	 * 		count	=	The number of lines to touch
	 */
	void touch(int start, int count) {
		if(nc.touchline(m_raw, start, count) != nc.OK) {
			throw new NCursesException("Error touching lines");
		}
	}
	/// Touch all parent locations that are changed in win
	void sync() {
		nc.wsyncup(m_raw);
	}
	/**
	 * Automatically call sync when the window is updated
	 *
	 * Param:
	 * 		isOk	=	true to automatically sync, false otherwise
	 * Returns: isOk
	 */
	bool syncok(bool isOk) @property {
		if(nc.syncok(m_raw, isOk) != nc.OK) {
			throw new NCursesException("Error setting sync status");
		}
		return isOk;
	}

	/**
	 * Allow or disable scrolling
	 *
	 * Tell the window whether it is allowed to scroll upon print
	 *
	 * Param:
	 * 		isOk	=	Whether scrolling is allowed or not
	 */
	void scrollok(bool isOk) @property {
		nc.scrollok(m_raw, isOk);
	}


	/**
	 * Move the cursor position
	 *
	 * Param:
	 * 		y	=	The row to move to
	 * 		x	=	The column to move to
	 */
	void cursor(int y, int x) {
		if(nc.wmove(m_raw,y,x) != nc.OK) {
			throw new NCursesException("Could not move cursor to correct location");
		}
	}
	void cursor(Pos p) {
		cursor(p.y, p.x);
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
	 * Param:
	 * 		y	=	The row to move to
	 * 		x	=	The column to move to
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


	/**
	 * Create a border around the current window
	 *
	 * The border takes up the first and last rows and columns inside the window.
	 * If 0 is used for any argument, the default character is used instead.
	 *
	 * Param:
	 * 		ls	=	The character to use for the left side. Default to ACS.VLINE
	 * 		rs	=	The character to use for the right side. Default to ACS.VLINE
	 * 		ts	=	The character to use for the top. Default to ACS.HLINE
	 * 		bs	=	The character to use for the bottom. Default to ACS.HLINE
	 * 		tl	=	The character to use for the top left corner. Default to ACS.ULCORNER
	 * 		tr	=	The character to use for the top right corner. Default to ACS.URCORNER
	 * 		bl	=	The character to use for the bottom left corner. Default to ACS.LLCORNER
	 * 		br	=	The character to use for the bottom right corner. Default to ACS.LRCORNER
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
	 * ---
	 * border(verch, verch, horch, horch, 0, 0, 0, 0);
	 * ---
	 *
	 * Param:
	 * 		verch	=	The character to use for the vertical sides
	 * 		horch	=	The character to use for the horizontal sides
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
