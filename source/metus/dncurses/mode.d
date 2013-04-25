/*******************************************************************************
 * D ncurses mode information
 *
 * Authors: Matthew Soucy, msoucy@csh.rit.edu
 * Date: Dec 2, 2012
 * Version: 0.0.1
 */
module metus.dncurses.mode;


import std.conv : to;
import metus.dncurses.base;

private abstract class Mode {
protected:
	int apply() {
		throw new NCursesException("Mode is undefined");
	}
}

/// Flags to determine whether entering cooked mode clears flags
immutable enum SetFlags {
	/// Do not clear flags
	No,
	/// Clear flags
	Yes
}

/**
 * Enter cooked mode
 *
 * Cooked mode is the same as regular terminal input.
 * All special characters are handled outside of the application
 *
 * Params:
 * 		cf	=	true to clear the IXON and ISIG flags, false to leave them
 * Returns: A cooked mode specifier
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
 * Returns: A cbreak mode specifier
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
 * Params:
 * 		tenths	=	The time to wait, in tenths of a second
 * Returns: A halfdelay mode specifier
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
 * Returns: A raw mode specifier
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

private static Mode currMode;

/**
 * Set the current mode to a new mode
 *
 * Params:
 * 		m	=	The new mode to use
 * Returns: The new mode
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
 * Returns: The current mode object
 */
Mode mode() @property @safe nothrow {
	return currMode;
}

/// Initialize the current mode
static this() {
	currMode = Cooked(SetFlags.No);
}
