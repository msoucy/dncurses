/**
 * @file errors.d
 * @brief D ncurses errors
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Nov 12, 2012
 * @version 0.0.1
 */
/// D ncurses basic functionality
module metus.dncurses.errors;


/// @cond NoDoc
package import eti = deimos.ncurses.eti;
/// @endcond


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
	 * @param _msg The error message
	 * @param file The file that the error is being thrown in
	 * @param line The line that the error is being thrown on
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
