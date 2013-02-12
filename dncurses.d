/**
 * @file dncurses.d
 * @brief D ncurses class wrappers
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Nov 12, 2012
 * @version 0.0.1
 */
///D ncurses class wrappers
module metus.dncurses.dncurses;


/// @cond NoDoc
public import metus.dncurses.window;
public import metus.dncurses.mode;
/// @endcond


/**
 * Standard window
 *
 * Equivalent to ncurses' stdscr
 */
public Window stdwin;


// Wrap the original ncurses implementations

/**
 * Initialize the screen
 *
 * Creates stdwin and forces echo to be true
 *
 * @return stdwin
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
