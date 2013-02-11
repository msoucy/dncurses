/** @file errors.d
	@brief D ncurses errors
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
/// D ncurses basic functionality
module metus.dncurses.errors;


/// @cond NoDoc
package import eti = deimos.ncurses.eti;
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
};

immutable enum ETI : int {
	OK = 0,
	SYSTEM_ERROR = -1,
	BAD_ARGUMENT = -2,
	POSTED = -3,
	CONNECTED = -4,
	BAD_STATE = -5,
	NO_ROOM = -6,
	NOT_POSTED = -7,
	UNKNOWN_COMMAND = -8,
	NO_MATCH = -9,
	NOT_SELECTABLE = -10,
	NOT_CONNECTED = -11,
	REQUEST_DENIED = -12,
	INVALID_FIELD = -13,
	CURRENT = -14
}
