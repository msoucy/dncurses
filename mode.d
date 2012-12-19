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

final class Cooked : Mode {
protected:
	ClearFlags m_cf;
	override int apply() {
		if(m_cf == ClearFlags.Yes) {
			return nc.noraw();
		} else {
			return nc.nocbreak();
		}
	}
	this(ClearFlags cf) {
		m_cf = cf;
	}
public:
	override string toString() {
		if(m_cf == ClearFlags.Yes) {
			return "Cooked(Clear)";
		} else {
			return "Cooked(NoClear)";
		}
	}
	static Cooked opCall(ClearFlags cf = ClearFlags.No) {
		return new Cooked(cf);
	}
}

final class CBreak : Mode {
protected:
	override int apply() {
		return nc.cbreak();
	}
	this() {}
public:
	override string toString() {
		return "CBreak";
	}
	static CBreak opCall() {
		return new CBreak();
	}
}

final class HalfDelay : Mode {
protected:
	ubyte m_tenths;
	override int apply() {
		return nc.halfdelay(m_tenths);
	}
	this(ubyte tenths) {}
public:
	override string toString() {
		return "Cooked("~m_tenths.to!string()~")";
	}
	static HalfDelay opCall(ubyte tenths) {
		if(tenths == 0) {
			throw new NCursesException("Cannot have a halfdelay of 0");
		}
		return new HalfDelay(tenths);
	}
}

final class Raw : Mode {
protected:
	override int apply() {
		return nc.raw();
	}
	this() {}
public:
	override string toString() {
		return "Raw";
	}
	static Raw opCall() {
		return new Raw();
	}
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
