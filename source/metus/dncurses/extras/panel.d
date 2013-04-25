/*******************************************************************************
 * D ncurses panel class wrappers
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Jan 11, 2013
 * Version: 0.0.1
 */
module metus.dncurses.extras.panel;

import metus.dncurses.window;
private import ncp = deimos.ncurses.panel;

/// ncurses panel wrapper class
class Panel {
private:
	Window m_win;
	Panel m_above;
	Panel m_below;
	ncp.PANEL* m_raw;
public:
	alias m_win this;

	/**
	 * Create a Panel around a window
	 *
	 * Params:
	 * 		win	=	The window to wrap
	 */
	this(Window win...) {
		m_win = win;
		m_raw = ncp.new_panel(win.raw);
	}

	~this() {
		ncp.del_panel(m_raw);
	}

	/**
	 * Hide a panel from being displayed
	 */
	void hide() {
		if(ncp.hide_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot hide panel");
		}
	}
	/**
	 * Display a panel
	 */
	void show() {
		if(ncp.show_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot show panel");
		}
	}
	/**
	 * Check to see if a panel is hidden
	 * Returns: true if the panel is hidden, false otherwise
	 */
	bool hidden() @property {
		return !!ncp.panel_hidden(m_raw);
	}

	/**
	 * Move a panel to the top of the display stack
	 */
	void top() {
		if(ncp.top_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot move panel to top");
		}
	}
	/**
	 * Move a panel to the bottom of the display stack
	 */
	void bottom() {
		if(ncp.bottom_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot move panel to bottom");
		}
	}

	/**
	 * Get the panel directly above this panel
	 *
	 * Returns: The panel above
	 */
	Panel above() @property pure nothrow {return m_above;}
	/**
	 * Get the panel directly below this panel
	 *
	 * Returns: The panel below
	 */
	Panel below() @property pure nothrow {return m_below;}


	////////////////////////////////////////////////////////////////////////////
	// Override Window functions
	////////////////////////////////////////////////////////////////////////////

	/**
	 * Move the current window
	 *
	 * The current window is moved relative to the screen.
	 * Coordinates are given for the top left corner of the window
	 *
	 * Params:
	 * @param y The row to move to
	 * @param x The column to move to
	*/
	void move(int y, int x) {
		if(ncp.move_panel(m_raw, y, x) != nc.OK) {
			throw new NCursesException("Could not move panel to correct location");
		}
	}

	/**
	 * Refresh the panel display stack
	 */
	void refresh() {
		ncp.update_panels();
		if(nc.doupdate() != nc.OK) {
			throw new NCursesException("Could not refresh window");
		}
	}
}
