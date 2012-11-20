/** @file dncurses.d
	@brief D ncurses class wrappers
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
///D ncurses class wrappers
module metus.dncurses.dncurses;


/// @cond NoDoc
import std.c.string : strlen;
import std.string : toStringz, format, toUpper;
import std.algorithm;
private import nc = deimos.ncurses.ncurses;
public import metus.dncurses.window;

// Character type from Deimos
alias nc.chtype CharType;
/// @endcond

/** @brief Get the ncurses version

	@return The version number as a string
*/
char[] ncurses_version() {
	char* ver = nc.curses_version();
	return ver[0..strlen(ver)];
}

/** @brief Color wrapper

	Wraps color lookup calls in an OOP structure
*/
struct Color {
	@disable this();
	/// Map color values to their deimos ncurses names
	template opDispatch(string key)
	{
		enum opDispatch = mixin("nc.COLOR_"~key.toUpper());
	}
}

/// Create an audio beep
void beep() {
	nc.beep();
}
/// Create a visual flash as a "bell"
void flash() {
	nc.flash();
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
	return stdwin;
}
/** @brief End all windows

	Cleans up the library and leaves ncurses mode
	@return 
*/
void endwin() {
	stdwin = null;
	if(nc.endwin() == nc.ERR) {
		throw new NCursesException("Could not end window properly");
	}
}
