/** @file attrstring.d
	@brief Structure and functions to create formatted strings
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
/// Structure and functions to create formatted strings
module metus.dncurses.attrstring;


/// @cond NoDoc
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
	void unapply(nc.WINDOW*);
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
		AttributeString ret = str;
		ret.m_attr |= mixin("nc.A_"~realname.toUpper());
		return ret;
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
		class Attribute : TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			@trusted void unapply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		}
		return new Attribute();
	}

	mixin("alias AttributeProperty "~name~";");

	// Disable a property
	@property @safe nothrow TextAttribute NoAttributeProperty() {
		class Attribute : TextAttribute {
			@trusted void apply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			@trusted void unapply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		}
		return new Attribute();
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
