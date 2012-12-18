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
	@safe nothrow this(string s) {
		m_str = s;
	}
public:
	@property nc.attr_t attr() {
		return m_attr;
	}
	@property nc.attr_t noattr() {
		return m_noattr;
	}
	@property string str() {
		return m_str;
	}
	alias m_str this;
	ref AttributeString opOpAssign(string op:"~")(string s) {
		this.m_str ~= s;
		return this;
	}
	AttributeString opBinary(string op:"~")(string s) {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
	AttributeString opOpAssign(string op:"~")(AttributeString s) {
		if(this.m_attr != s.m_attr) {
			throw new NCursesException("Cannot concatenate strings with different attributes");
		}
		this.m_str ~= s;
		return this;
	}
	AttributeString opBinary(string op:"~")(AttributeString s) {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
}

private interface TextAttribute {
public:
	void apply(nc.WINDOW*);
}

mixin template AttributeProperty(string name, string realname=name) {
	// Add a property to a string with attributes
	@property @safe nothrow AttributeString AttributeProperty(AttributeString str) {
		str.m_attr |= mixin("nc.A_"~realname.toUpper());
		str.m_noattr &= ~mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Add a property to a regular string
	@property @safe nothrow AttributeString AttributeProperty(string str) {
		return mixin(`AttributeString(str).`~name~`()`);
	}

	// Turn a formatted character into a formatted string
	@property @safe nothrow AttributeString AttributeProperty(nc.chtype ch) {
		AttributeString ret = "";
		ret ~= ch & nc.A_CHARTEXT;
		ret.m_attr = (ch & nc.A_ATTRIBUTES) | mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	// Enable a property
	@property @safe nothrow TextAttribute AttributeProperty() {
		return new class TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		};
	}

	mixin("alias AttributeProperty "~name~";");

	// Disable a property
	@property @safe nothrow TextAttribute NoAttributeProperty() {
		return new class TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		};
	}

	mixin("alias NoAttributeProperty no"~name~";");


	// Remove a property from a string with attributes
	@property @safe nothrow AttributeString NoAttributeProperty(AttributeString str) {
		str.m_attr &= ~mixin("nc.A_"~realname.toUpper());
		str.m_noattr |= mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Remove a property from a string
	@property @safe nothrow AttributeString NoAttributeProperty(string str) {
		AttributeString ret = str;
		ret.m_noattr = mixin("nc.A_"~realname.toUpper());
		return ret;
	}
	
	mixin("alias NoAttributeProperty no"~name~";");


	@property @safe nothrow bool CheckAttributeProperty(CharType ch) {
		return (ch & mixin("nc.A_"~realname.toUpper())) != 0;
	}
	@property @safe nothrow bool CheckAttributeProperty(inout(AttributeString) str) {
		return (str.m_attr & mixin("nc.A_"~realname.toUpper())) != 0;
	}

	mixin("alias CheckAttributeProperty is"~name~";");
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
immutable enum Color : nc.chtype
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


// Remove foreground color from a string with attributes
@property @safe nothrow AttributeString nofg(AttributeString str) {
	str.m_noattr |= FG_MASK;
	str.m_attr &= ~FG_MASK;
	return str;
}

// Remove foreground color from a regular string
@property @safe nothrow AttributeString nofg(string str) {
	return AttributeString(str).nofg();
}

// Remove foreground color
@property @safe nothrow TextAttribute nofg() {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = mkPairNum(win.attrs) & 0b00111000;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set foreground color");
			}
		}
	};
}

// Remove background color from a string with attributes
@property @safe nothrow AttributeString nobg(AttributeString str) {
	str.m_noattr |= BG_MASK;
	str.m_attr &= ~BG_MASK;
	return str;
}

// Remove background color from a regular string
@property @safe nothrow AttributeString nobg(string str) {
	return AttributeString(str).nobg();
}

// Remove background color
@property @safe nothrow TextAttribute nobg() {
	return new class TextAttribute {
		@trusted void apply(nc.WINDOW* win) {
			short pairnum = mkPairNum(win.attrs) & 0b00000111;

			if(nc.wcolor_set(win, pairnum, cast(void*)0) == nc.ERR) {
				throw new NCursesException("Could not set background color");
			}
		}
	};
}

alias nc.color_set colorSet;
