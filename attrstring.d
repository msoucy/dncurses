/** @file attrstring.d
	@brief Structure and functions to create formatted strings
	@authors Matthew Soucy <msoucy@csh.rit.edu>
	@date Nov 12, 2012
	@version 0.0.1
*/
/// Structure and functions to create formatted strings
module metus.dncurses.attrstring;


/// @cond NoDoc
import std.string : toStringz, toUpper;
private import nc = deimos.ncurses.ncurses;
public import metus.dncurses.base;
/// @endcond


package struct AttributeString {
package:
	nc.attr_t m_attr;
	nc.attr_t m_noattr;
	string m_str;
	this(string s) {
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
	// Overload AttrString~String and vice-versa
	// Disable this for now, until I figure out what cases are allowed
	@disable opBinary(string s:"~")(AttributeString);
}

private interface TextAttribute {
public:
	void apply(nc.WINDOW*);
	void unapply(nc.WINDOW*);
}

mixin template AttributeProperty(string name, string realname=name) {
	// Add a property to a string with attributes
	@property AttributeString AttributeProperty(AttributeString str) {
		str.m_attr |= mixin("nc.A_"~realname.toUpper());
		str.m_noattr &= ~mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Add a property to a regular string
	@property AttributeString AttributeProperty(string str) {
		AttributeString ret = str;
		ret.m_attr |= mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	// Turn a formatted character into a formatted string
	@property AttributeString AttributeProperty(nc.chtype ch) {
		AttributeString ret = "";
		ret ~= ch & nc.A_CHARTEXT;
		ret.m_attr = (ch & nc.A_ATTRIBUTES) | mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	// Enable a property
	@property TextAttribute AttributeProperty() {
		class Attribute : TextAttribute {
			void apply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			void unapply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		}
		return new Attribute();
	}

	mixin("alias AttributeProperty "~name~";");

	// Disable a property
	@property TextAttribute NoAttributeProperty() {
		class Attribute : TextAttribute {
			void apply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
			void unapply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) == nc.ERR) {
					throw new NCursesException("Could not set attributes");
				}
			}
		}
		return new Attribute();
	}

	mixin("alias NoAttributeProperty no"~name~";");


	// Remove a property from a string with attributes
	@property AttributeString NoAttributeProperty(AttributeString str) {
		str.m_attr &= ~mixin("nc.A_"~realname.toUpper());
		str.m_noattr |= mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Remove a property from a string
	@property AttributeString NoAttributeProperty(string str) {
		AttributeString ret = str;
		ret.m_noattr = mixin("nc.A_"~realname.toUpper());
		return ret;
	}
	
	mixin("alias NoAttributeProperty no"~name~";");


	@property bool CheckAttributeProperty(CharType ch) {
		return (ch & mixin("nc.A_"~realname.toUpper())) != 0;
	}
	@property bool CheckAttributeProperty(AttributeString str) {
		return (str.m_attr & mixin("nc.A_"~realname.toUpper())) != 0;
	}

	mixin("alias CheckAttributeProperty is"~name~";");
}

mixin AttributeProperty!"standout";
mixin AttributeProperty!"underline";
mixin AttributeProperty!("reversed","reverse");
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
