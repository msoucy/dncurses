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
private import nc = deimos.ncurses.ncurses;

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


/** @brief Get echo mode

	@return The current echo mode
*/
@property auto echo() {
	return isEcho;
}
/** @brief Change echo mode

	@param echoOn Whether echo should be enabled
	@return The old echo mode
*/
@property auto echo(bool echoOn) {
	bool currEcho = isEcho;
	if(((isEcho=echoOn)==true ? nc.echo() : nc.noecho()) == nc.ERR) {
		throw new NCursesException("Could not change echo mode");
	}
	return currEcho;
}


/** @brief Control flush of input and output on interrupt

	Control flushing of input and output queues when an interrupt, quit,
	or suspend character is sent to the terminal.
	
	@param shouldFlush Enable (true) or disable (false) flushing
*/
@property void qiflush(bool shouldFlush) {
	if(shouldFlush) {
		nc.qiflush();
	} else {
		nc.noqiflush();
	}
}

/** @brief Control flush of output on interrupt

	If the value of shouldFlush is TRUE, then flushing of the output buffer
	associated with the current screen will occur when an interrupt key
	(interrupt, suspend, or quit) is pressed.If the value of shouldFlush is
	FALSE, then no flushing of the buffer will occur when an interrupt key
	is pressed.
	
	@param shouldFlush Enable (true) or disable (false) flushing
*/
@property void intrflush(bool shouldFlush) {
	// nc.intrflush ignores the window parameter...
	if(nc.intrflush(nc.stdscr, shouldFlush) == nc.ERR) {
		throw new NCursesException("Could not change flush behavior");
	}
}

/// Character attributes
immutable enum Attribute : CharType {
	/// Normal display (no highlight)
	Normal = nc.A_NORMAL,
	/// Bit-mask to get the attributes of a character
	Attributes = nc.A_ATTRIBUTES,
	/// Bit-mask to extract a character
	Chartext = nc.A_CHARTEXT,
	/// Bit-mask to extract a color
	Color = nc.A_COLOR,
	/// Best highlighting mode of the terminal
	Standout = nc.A_STANDOUT,
	/// Underlining
	Underline = nc.A_UNDERLINE,
	/// Reverse video
	Reverse = nc.A_REVERSE,
	/// Blinking
	Blink = nc.A_BLINK,
	/// Half bright
	Dim = nc.A_DIM,
	/// Extra bright or bold
	Bold = nc.A_BOLD,
	/// Bit-mask for alternate character set
	AltCharset = nc.A_ALTCHARSET,
	/// Invisible or blank mode
	Invis = nc.A_INVIS,
	/// Protected mode
	Protect = nc.A_PROTECT,
	/// XSI extra conformance standard
	/// @{
	Horizontal = nc.A_HORIZONTAL,
	Left = nc.A_LEFT,
	Low = nc.A_LOW,
	Right = nc.A_RIGHT,
	Top = nc.A_TOP,
	Vertical = nc.A_VERTICAL,
	/// @}
}

/** @brief Key name wrapper

Allows the use of Key.NAME instead of KEY_NAME, which makes it nicer to use
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

Allows the use of ACS.name instead of ACS_NAME,
which makes it nicer to use alternative character sets
*/
struct ACS {
	@disable this();
	/// Map key names to their deimos values
	static @property CharType opDispatch(string key)() {
		return mixin("nc.ACS_"~key.toUpper()~"()");
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

/// @cond NoDoc
alias nc.killchar killchar;
alias nc.erasechar erasechar;
/// @endcond
