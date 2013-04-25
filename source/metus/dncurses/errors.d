/*******************************************************************************
 * D ncurses errors
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Nov 12, 2012
 * Version: 0.0.1
 */
module metus.dncurses.errors;

package import eti = deimos.ncurses.eti;

/**
 * Ncurses error class
 *
 * Base class for all errors related to dncurses
 */
class NCursesException : Exception {
public:
	/**
	 * Create and automatically initialize an NCursesException
	 *
	 * Params:
	 * 		_msg	=	The error message
	 * 		file	=	The file that the error is being thrown in
	 * 		line	=	The line that the error is being thrown on
	 */
    this (string _msg, string file=__FILE__, int line=__LINE__) {
    	super(_msg, file, line);
	}
};

/**
 * ETI error codes
 */
struct ETI {
	@disable this();
	/// Map error codes to their deimos values
	template opDispatch(string key)
	{
		enum opDispatch = mixin("eti.ETI_"~key.toUpper());
	}
}
