/** @file dncurses.d
	@brief D ncurses class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses class wrappers
module metus.dncurses.dncurses;


/// @cond NoDoc
import std.string : toUpper, strlen;
public import metus.dncurses.window;
public import metus.dncurses.mode;
/// @endcond

/** @brief Get the ncurses version

	@return The version number as a string
*/
char[] ncurses_version() {
	char* ver = nc.curses_version();
	return ver[0..strlen(ver)];
}



/** @brief Standard window

	Equivalent to ncurses' stdscr
*/
public Window stdwin;


// Wrap the original ncurses implementations
/** @brief Initialize the screen

	Creates stdwin and forces echo to be true
	@return stdwin
*/
auto initscr() {
	 // Call library initscr and bind our standard window
	stdwin = new Window(nc.initscr());
	echo = true;
	mode = Cooked(SetFlags.No);
	return stdwin;
}
/** @brief End all windows

	Cleans up the library and leaves ncurses mode
	@return 
*/
 void endwin() {
	stdwin = null;
	if(nc.endwin() != nc.OK) {
		throw new NCursesException("Could not end window properly");
	}
}
