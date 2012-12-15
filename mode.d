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


private interface Mode {
private:
	auto apply() {return nc.ERR;}
public:
	string toString();
}


enum ClearFlags {
	No,
	Yes
}

class Cooked : Mode {
private:
	ClearFlags m_cf;
	auto apply() {
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
			return "Cooked(Flags set)";
		} else {
			return "Cooked(Flags not set)";
		}
	}
	static Cooked opCall(ClearFlags cf = ClearFlags.No) {
		return new Cooked(cf);
	}
}

class CBreak : Mode {
private:
	auto apply() {
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

class HalfDelay : Mode {
private:
	ubyte m_tenths;
	auto apply() {
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

class Raw : Mode {
private:
	auto apply() {
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


public:

@property void mode(Mode m) {
	if(m.apply() == nc.ERR) {
		throw new NCursesException("Could not change mode");
	}
	currMode = m;
}

@property Mode mode() {
	return currMode;
}

static this() {
	currMode=Cooked(ClearFlags.No);
}
