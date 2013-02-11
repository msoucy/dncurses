/** @file panel.d
	@brief D ncurses panel class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses window class wrappers
module metus.dncurses.panel;

/// @cond NoDoc
import metus.dncurses.window;
private import ncp = deimos.ncurses.panel;
/// @endcond

class Panel {
private:
	Window m_win;
	Panel m_above;
	Panel m_below;
	ncp.PANEL* m_raw;
public:
	alias this = m_win;

	this(Window win...) {
		m_win = win;
		m_raw = ncp.new_panel(win.m_raw);
	}

	void hide() {
		if(ncp.hide_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot hide panel");
		}
	}
	void show() {
		if(ncp.show_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot show panel");
		}
	}
	bool hidden() @property {
		return !!ncp.panel_hidden(m_raw);
	}

	void top() {
		if(ncp.top_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot move panel to top");
		}
	}
	void bottom() {
		if(ncp.bottom_panel(m_raw) == nc.ERR) {
			throw new NCursesException("Cannot move panel to bottom");
		}
	}

	Panel above() @property pure nothrow {return m_above;}
	Panel below() @property pure nothrow {return m_below;}


	////////////////////////////////////////////////////////////////////////////
	// Override Window functions
	////////////////////////////////////////////////////////////////////////////

	/**
	 * @brief Move the current window
	 *
	 * The current window is moved relative to the screen.
	 * Coordinates are given for the top left corner of the window
	 *
	 * @param y The row to move to
	 * @param x The column to move to
	*/
	void move(int y, int x) {
		if(ncp.move_panel(m_raw, y, x) != nc.OK) {
			throw new NCursesException("Could not move panel to correct location");
		}
	}

	void refresh() {
		ncp.update_panels();
		if(nc.doupdate() != nc.OK) {
			throw new NCursesException("Could not refresh window");
		}
	}
	~this() {
		ncp.del_panel(m_raw)
	}
}
