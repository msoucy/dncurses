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
/// @endcond


private abstract class Mode {
protected:
	int apply() {
		throw new NCursesException("Mode is undefined");
	}
}


enum ClearFlags {
	No,
	Yes
}

Mode Cooked(ClearFlags cf = ClearFlags.No) {
	return new class Mode {
	protected:
		override int apply() {
			if(cf == ClearFlags.Yes) {
				return nc.noraw();
			} else {
				return nc.nocbreak();
			}
		}
	public:
		override string toString() {
			if(cf == ClearFlags.Yes) {
				return "Cooked(Clear)";
			} else {
				return "Cooked(NoClear)";
			}
		}
	};
}

Mode CBreak() {
	return new class Mode {
	protected:
		override int apply() {
			return nc.cbreak();
		}
		this() {}
	public:
		override string toString() {
			return "CBreak";
		}
	};
}


Mode HalfDelay(ubyte tenths) {
	if(tenths == 0) {
		throw new NCursesException("Cannot have a halfdelay of 0");
	}
	return new class Mode {
	protected:
		override int apply() {
			return nc.halfdelay(tenths);
		}
	public:
		override string toString() {
			return "Cooked("~tenths.to!string()~")";
		}
	};
}

Mode Raw() {
	return new class Mode {
	protected:
		override int apply() {
			return nc.raw();
		}
	public:
		override string toString() {
			return "Raw";
		}
	};
}


private static Mode currMode;


@property void mode(Mode m) {
	if(m is null || m.apply() == nc.ERR) {
		throw new NCursesException("Could not change to mode: "~m.to!string());
	}
	currMode = m;
}

@property Mode mode() {
	return currMode;
}

static this() {
	currMode = Cooked(ClearFlags.No);
}
