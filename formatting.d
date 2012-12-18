/** @file attrstring.d
	@brief Structures and functions for attributes and formatting
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
/// Structures and functions for attributes and formatting
module metus.dncurses.formatting;


/// @cond NoDoc
import std.traits;
public import metus.dncurses.base;
/// @endcond


package struct AttributeString {
package:
	nc.attr_t m_attr;
	nc.attr_t m_noattr;
	string m_str;
public:
	@safe pure nothrow this(string s) {
		m_str = s;
	}
	@property @safe pure nothrow nc.attr_t attr() const {
		return m_attr;
	}
	@property @safe pure nothrow nc.attr_t attrDisable() const {
		return m_noattr;
	}
	@property @safe pure nothrow string str() const {
		return m_str;
	}
	alias m_str this;

	@property @safe pure nothrow ref AttributeString opOpAssign(string op:"~")(string s) {
		this.m_str ~= s;
		return this;
	}
	@property @safe pure nothrow AttributeString opBinary(string op:"~")(string s) const {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
	@property @safe pure nothrow AttributeString opOpAssign(string op:"~")(AttributeString s) {
		if(this.m_attr != s.m_attr) {
			throw new NCursesException("Cannot concatenate strings with different attributes");
		}
		this.m_str ~= s;
		return this;
	}
	@property @safe pure nothrow AttributeString opBinary(string op:"~")(AttributeString s) const {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
}

private interface TextAttribute {
public:
	void apply(nc.WINDOW*);
	void bkgd(nc.WINDOW*);
}

mixin template AttributeProperty(string name, string realname=name) {
	// Add a property to a string with attributes
	@property @safe pure nothrow AttributeString AttributeProperty(AttributeString str) {
		str.m_attr |= mixin("nc.A_"~realname.toUpper());
		str.m_noattr &= ~mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Add a property to a regular string
	@property @safe pure nothrow AttributeString AttributeProperty(string str) {
		return mixin(`AttributeString(str).`~name~`()`);
	}

	// Turn a formatted character into a formatted string
	@property @safe pure nothrow AttributeString AttributeProperty(nc.chtype ch) {
		AttributeString ret = "";
		ret ~= ch & nc.A_CHARTEXT;
		ret.m_attr = (ch & nc.A_ATTRIBUTES) | mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	// Enable a property
	@property @safe pure nothrow TextAttribute AttributeProperty() {
		return new class TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			@trusted void bkgd(nc.WINDOW* win) {
				nc.wbkgdset(win, nc.getbkgd(win)|mixin("nc.A_"~realname.toUpper()));
			}
		};
	}

	mixin("alias AttributeProperty "~name~";");

	// Disable a property
	@property @safe pure nothrow TextAttribute NoAttributeProperty() {
		return new class TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			@trusted void bkgd(nc.WINDOW* win) {
				nc.wbkgdset(win, nc.getbkgd(win)&~mixin("nc.A_"~realname.toUpper()));
			}
		};
	}

	mixin("alias NoAttributeProperty no"~name~";");


	// Remove a property from a string with attributes
	@property @safe pure nothrow AttributeString NoAttributeProperty(AttributeString str) {
		str.m_attr &= ~mixin("nc.A_"~realname.toUpper());
		str.m_noattr |= mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Remove a property from a string
	@property @safe pure nothrow AttributeString NoAttributeProperty(string str) {
		AttributeString ret = str;
		ret.m_noattr = mixin("nc.A_"~realname.toUpper());
		return ret;
	}
	
	mixin("alias NoAttributeProperty no"~name~";");


	@property @safe pure nothrow bool CheckAttributeProperty(CharType ch) {
		return (ch & mixin("nc.A_"~realname.toUpper())) != 0;
	}
	@property @safe pure nothrow bool CheckAttributeProperty(inout(AttributeString) str) {
		return (str.m_attr & mixin("nc.A_"~realname.toUpper())) != 0;
	}

	mixin("alias CheckAttributeProperty is"~name~";");
}

// Enable a property
@property @safe pure nothrow TextAttribute attrclear() {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			if(nc.wattrset(win, 0UL) == nc.ERR) {
				throw new NCursesException("Could not set attributes");
			}
		}
		@trusted void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, 0UL);
		}
	};
}

mixin AttributeProperty!"standout";
mixin AttributeProperty!"underline";
mixin AttributeProperty!("invert","reverse");
mixin AttributeProperty!"blink";
mixin AttributeProperty!"dim";
mixin AttributeProperty!"bold";
mixin AttributeProperty!"invis";
mixin AttributeProperty!"protect";
mixin AttributeProperty!"horizontal";
mixin AttributeProperty!"left";
mixin AttributeProperty!"low";
mixin AttributeProperty!"right";
mixin AttributeProperty!"top";
mixin AttributeProperty!"vertical";

////////////////////////////////////////////////////////////////////////////////
// Colors
////////////////////////////////////////////////////////////////////////////////

/* colors */
immutable enum Color : short
{
	BLACK   = 0,
	RED     = 1,
	GREEN   = 2,
	YELLOW  = 3,
	BLUE    = 4,
	MAGENTA = 5,
	CYAN    = 6,
	WHITE   = 7
}

private enum FG_SHIFT = 8;
private enum FG_MASK = 0b00000000_00000000_00000111_00000000UL;
private enum BG_SHIFT = 11;
private enum BG_MASK = 0b00000000_00000000_00111000_00000000UL;

@trusted bool hasColors() {
	return nc.has_colors();
}

private short mkPairNum(short fg, short bg) {
	return ((bg<<3)|fg)&0xFFFF;
}

private short mkPairNum(ulong attrs) {
	return mkPairNum(((attrs&~FG_MASK)>>FG_SHIFT)&0xFFFF, ((attrs&~BG_MASK)>>BG_SHIFT)&0xFFFF);
}

@trusted void initColor() {
	nc.start_color();
	assert(nc.COLOR_PAIRS >= Color.max*Color.max);
	foreach(Color bg ; EnumMembers!Color) {
		foreach(Color fg ; EnumMembers!Color) {
			nc.init_pair(mkPairNum(fg, bg), fg, bg);
		}
	}
}


// Set foreground color on a string with attributes
@property @safe pure nothrow AttributeString fg(AttributeString str, short c) {
	str.m_noattr |= FG_MASK;
	str.m_attr = (str.m_attr & ~FG_MASK) | (c<<FG_SHIFT);
	return str;
}

// Set foreground color on a D string
@property @safe pure nothrow AttributeString fg(string str, short c) {
	return AttributeString(str).fg(c);
}

// Set foreground color
@property @safe pure nothrow TextAttribute fg(short c) {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = (mkPairNum(win.attrs) & 0b00111000) | c;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set foreground color");
			}
		}
		@trusted void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, (nc.getbkgd(win) & ~FG_MASK) | (c<<FG_SHIFT));
		}
	};
}

// Remove foreground color from a string with attributes
@property @safe pure nothrow AttributeString nofg(AttributeString str) {
	str.m_noattr |= FG_MASK;
	str.m_attr &= ~FG_MASK;
	return str;
}

// Remove foreground color from a regular string
@property @safe pure nothrow AttributeString nofg(string str) {
	return AttributeString(str).nofg();
}

// Remove foreground color
@property @safe pure nothrow TextAttribute nofg() {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = mkPairNum(win.attrs) & 0b00111000;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set foreground color");
			}
		}
		@trusted void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, nc.getbkgd(win) & ~FG_MASK);
		}
	};
}

// Set background color on a string with attributes
@property @safe pure nothrow AttributeString bg(AttributeString str, short c) {
	str.m_noattr |= BG_MASK;
	str.m_attr = (str.m_attr & ~BG_MASK) | (c<<BG_SHIFT);
	return str;
}

// Set background color on a D string
@property @safe pure nothrow AttributeString bg(string str, short c) {
	return AttributeString(str).bg(c);
}

// Set background color
@property @safe pure nothrow TextAttribute bg(short c) {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = ((mkPairNum(win.attrs) & 0b00000111) | (c<<3)) & 0xFFFF;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set foreground color");
			}
		}
		@trusted void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, (nc.getbkgd(win) & ~BG_MASK) | (c<<BG_SHIFT));
		}
	};
}

// Remove background color from a string with attributes
@property @safe pure nothrow AttributeString nobg(AttributeString str) {
	str.m_noattr |= BG_MASK;
	str.m_attr &= ~BG_MASK;
	return str;
}

// Remove background color from a regular string
@property @safe pure nothrow AttributeString nobg(string str) {
	return AttributeString(str).nobg();
}

// Remove background color
@property @safe pure nothrow TextAttribute nobg() {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = mkPairNum(win.attrs) & 0b00000111;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set background color");
			}
		}
		@trusted void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, nc.getbkgd(win) & ~BG_MASK);
		}
	};
}

// Set colors on a string with attributes
@safe pure nothrow AttributeString color(AttributeString str, short f, short b) {
	return str.fg(f).bg(b);
}

// Set background color on a D string
@safe pure nothrow AttributeString color(string str, short f, short b) {
	return AttributeString(str).fg(f).bg(b);
}
