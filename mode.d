/** @file mode.d
	@brief D ncurses mode information
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Dec 2, 2012
	@version 0.0.1
*/
/// D ncurses mode information
module metus.dncurses.mode;


/// @cond NoDoc
import std.conv : to;
import metus.dncurses.base;

private abstract class Mode {
protected:
	int apply() {
		throw new NCursesException("Mode is undefined");
	}
}
/// @endcond

/** @brief Flags to determine whether entering cooked mode clears flags */
immutable enum SetFlags {
	No,
	Yes
}

/** @name Modes

	Different input modes provided by ncurses
@{
*/
/** @brief Enter cooked mode

	Cooked mode is the same as regular terminal input.
	All special characters are handled outside of the application

	@param cf true to clear the IXON and ISIG flags, false to leave them
	@return A cooked mode specifier
*/
@safe pure nothrow Mode Cooked(SetFlags cf = SetFlags.No) {
	return new class Mode {
	protected:
		@system override int apply() {
			if(cf == SetFlags.Yes) {
				return nc.noraw();
			} else {
				return nc.nocbreak();
			}
		}
	public:
		override string toString() {
			return "Cooked("~(cf==SetFlags.Yes? "" : "No")~"SetFlags)";
		}
	};
}

/** @brief Enter cbreak mode

	Entered characters are immediately available to the application.
	No special processing is performed for the kill or erase characters.
	
	@return A cbreak mode specifier
*/
@safe pure nothrow Mode CBreak() {
	return new class Mode {
	protected:
		@system override int apply() {
			return nc.cbreak();
		}
	public:
		override string toString() {
			return "CBreak";
		}
	};
}

/** @brief Enter halfdelay mode

	Behaves like cbreak mode, but the application waits a specified interval

	@param tenths The time to wait, in tenths of a second
	@return A halfdelay mode specifier
*/
@safe pure Mode HalfDelay(ubyte tenths) {
	if(tenths == 0) {
		throw new NCursesException("Cannot have a halfdelay of 0");
	}
	return new class Mode {
	protected:
		@system override int apply() {
			return nc.halfdelay(tenths);
		}
	public:
		@system override string toString() {
			return "Cooked("~tenths.to!string()~")";
		}
	};
}

/** @brief Enter raw mode

	The application receives each character as it is entered.
	No special processing is performed.
	
	@return A raw mode specifier
*/
@safe nothrow pure Mode Raw() {
	return new class Mode {
	protected:
		@system override int apply() {
			return nc.raw();
		}
	public:
		override string toString() {
			return "Raw";
		}
	};
}
/// @}

/// @cond NoDoc
private static Mode currMode;
/// @endcond


/** @name Handle modes
	Work with the current mode
@{
*/
/** @brief Set the current mode to a new mode

	@param m The new mode to use
*/
@property void mode(Mode m) {
	if(m is null || m.apply() != nc.OK) {
		throw new NCursesException("Could not change to mode: "~m.to!string());
	}
	currMode = m;
}

/** @brief Get the current mode
	@return The current mode object
*/
@property @safe nothrow Mode mode() {
	return currMode;
}
/// @}

/// Initialize the current mode
static this() {
	currMode = Cooked(SetFlags.No);
}
