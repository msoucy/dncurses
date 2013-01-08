/** @file base.d
	@brief D ncurses basic functionality
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
/// D ncurses basic functionality
module metus.dncurses.base;


/// @cond NoDoc
import std.string : toUpper;
import std.stdio : File;
package import nc = deimos.ncurses.ncurses;

// Character type from Deimos
alias nc.chtype CharType;
/// @endcond

/** @brief Ncurses error class

	Base class for all errors related to dncurses
*/
class NCursesException : Exception {
public:
	/** @brief Create and automatically initialize an NCursesException
		
		@param _msg The error message
		@param file The file that the error is being thrown in
		@param line The line that the error is being thrown on
	*/
    this (string _msg, string file=__FILE__, int line=__LINE__) {
    	super(_msg, file, line);
	}
};/// @cond NoDoc
// Stores whether ncurses is in echo mode or not
private static bool isEcho;
/// @endcond


/** @name Handle echo modes
@{
*/
/** @brief Get echo mode
	@return The current echo mode
*/
@safe @property nothrow auto echo() {
	return isEcho;
}
/** @brief Change echo mode
	@param echoOn Whether echo should be enabled
	@return The old echo mode
*/
@trusted @property auto echo(bool echoOn) {
	bool currEcho = isEcho;
	if(((isEcho=echoOn)==true ? nc.echo() : nc.noecho()) != nc.OK) {
		throw new NCursesException("Could not change echo mode");
	}
	return currEcho;
}
/// @}


/** @brief Control flush of input and output on interrupt

	Control flushing of input and output queues when an interrupt, quit,
	or suspend character is sent to the terminal.
	
	@param shouldFlush Enable (true) or disable (false) flushing
*/
@trusted @property void qiflush(bool shouldFlush) {
	if(shouldFlush) {
		nc.qiflush();
	} else {
		nc.noqiflush();
	}
}

/** @brief Control flush of output on interrupt

	If the value of shouldFlush is TRUE, then flushing of the output buffer
	associated with the current screen will occur when an interrupt key
	(interrupt, suspend, or quit) is pressed. If the value of shouldFlush is
	FALSE, then no flushing of the buffer will occur when an interrupt key
	is pressed.
	
	@param shouldFlush Enable (true) or disable (false) flushing
*/
@trusted @property void intrflush(bool shouldFlush) {
	// nc.intrflush ignores the window parameter...
	if(nc.intrflush(nc.stdscr, shouldFlush) != nc.OK) {
		throw new NCursesException("Could not change flush behavior");
	}
}

/** @brief Key name wrapper

Allows the use of Key.NAME instead of KEY_NAME to get key names
*/
struct Key {
	@disable this();
	/// Map key names to their deimos values
	template opDispatch(string key)
	{
		static if(key.toUpper()[0] == 'F' && key.length > 1 && (key[1]>'0'&&key[1]<='9')) {
			enum opDispatch = mixin("nc.KEY_F("~key[1..$]~")");
		} else {
			enum opDispatch = mixin("nc.KEY_"~key.toUpper());
		}
	}
}

/** @brief ACS name wrapper

Allows the use of ACS.name instead of ACS_NAME to get alternative character sets
*/
struct ACS {
	@disable this();
	/// Map key names to their deimos values
	static @system nothrow @property CharType opDispatch(string key)() {
		return mixin("nc.ACS_"~key.toUpper()~"()");
	}
}

/// Position structure
struct Pos {
	/// The x coordinate (column)
	immutable int x;
	/// The y coordinate (row)
	immutable int y;
	/** @brief Create a position

		@param _y The y coordinate (row)
		@param _x The x coordinate (column)
	*/
	nothrow this(int _y, int _x) {
		this.x = _x;
		this.y = _y;
	}
}

/// Create an audio beep
@trusted void beep() {
	nc.beep();
}
/// Create a visual flash as a "bell"
@trusted void flash() {
	nc.flash();
}

/// Set the file descriptor to use for typeahead
@trusted void typeahead(File fd) {
	if(nc.typeahead(fd.fileno()) != nc.OK) {
		throw new NCursesException("Could not set typeahead variable");
	}
}

/// @cond NoDoc
alias nc.killchar killchar;
alias nc.erasechar erasechar;
/// @endcond
