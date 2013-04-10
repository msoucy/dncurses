/**
 * @file mode.d
 * @brief D ncurses mode information
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Dec 2, 2012
 * @version 0.0.1
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

/// Flags to determine whether entering cooked mode clears flags
immutable enum SetFlags {
	No,
	Yes
}

/**
 * @name Modes
 *
 * Different input modes provided by ncurses
 * @{
 */
/**
 * Enter cooked mode
 *
 * Cooked mode is the same as regular terminal input.
 * All special characters are handled outside of the application
 *
 * @param cf true to clear the IXON and ISIG flags, false to leave them
 * @return A cooked mode specifier
 */
Mode Cooked(SetFlags cf = SetFlags.No) @safe pure nothrow {
	return new class Mode {
	protected:
		override int apply() @system {
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

/**
 * Enter cbreak mode
 *
 * Entered characters are immediately available to the application.
 * No special processing is performed for the kill or erase characters.
 *
 * @return A cbreak mode specifier
 */
Mode CBreak() @safe pure nothrow {
	return new class Mode {
	protected:
		override int apply() @system {
			return nc.cbreak();
		}
	public:
		override string toString() {
			return "CBreak";
		}
	};
}

/**
 * Enter halfdelay mode
 *
 * Behaves like cbreak mode, but the application waits a specified interval
 *
 * @param tenths The time to wait, in tenths of a second
 * @return A halfdelay mode specifier
 */
Mode HalfDelay(ubyte tenths) @safe pure {
	if(tenths == 0) {
		throw new NCursesException("Cannot have a halfdelay of 0");
	}
	return new class Mode {
	protected:
		override int apply() @system {
			return nc.halfdelay(tenths);
		}
	public:
		override string toString() @system {
			return "Cooked("~tenths.to!string()~")";
		}
	};
}

/**
 * Enter raw mode
 *
 * The application receives each character as it is entered.
 * No special processing is performed.
 *
 * @return A raw mode specifier
 */
Mode Raw() @safe nothrow pure {
	return new class Mode {
	protected:
		override int apply() @system {
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


/**
 * @name Handle modes
 *
 * Work with the current mode
 * @{
 */
/**
 * Set the current mode to a new mode
 *
 * @param m The new mode to use
 * @return The new mode
 */
Mode mode(Mode m) @property {
	if(m is null || m.apply() != nc.OK) {
		throw new NCursesException("Could not change to mode: "~m.to!string());
	}
	return currMode = m;
}

/**
 * Get the current mode
 *
 * @return The current mode object
 */
Mode mode() @property @safe nothrow {
	return currMode;
}
/// @}

/// Initialize the current mode
static this() {
	currMode = Cooked(SetFlags.No);
}
