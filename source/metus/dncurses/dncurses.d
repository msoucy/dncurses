/*******************************************************************************
 * Main entry point for ncurses
 *
 * Provides functions to initialize and deinitialize the main windows.
 * This would be done as static this()/static ~this(), but we need to
 * have the ability to exit ncurses mode and reenter it later.
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Nov 12, 2012
 * Version: 0.0.1
 */
module metus.dncurses.dncurses;


public import metus.dncurses.window;
public import metus.dncurses.mode;


/**
 * Standard window
 *
 * Equivalent to ncurses' stdscr
 */
public Window stdwin;


/**
 * Initialize the screen
 *
 * Creates stdwin and forces echo to be true
 *
 * Returns: stdwin
*/
Window initscr() {
	 // Call library initscr and bind our standard window
	stdwin = new Window(nc.initscr());
	echo = true;
	mode = Cooked(SetFlags.No);
	return stdwin;
}
/**
 * End all windows
 *
 * Cleans up the library and leaves ncurses mode
 */
void endwin() {
	stdwin = null;
	if(nc.endwin() != nc.OK) {
		throw new NCursesException("Could not end window properly");
	}
}
