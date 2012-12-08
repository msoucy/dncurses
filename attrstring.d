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
public import metus.dncurses.window;
/// @endcond


/// Character attributes
immutable enum Attribute : nc.attr_t {
	/// Normal display (no highlight)
	Normal = nc.A_NORMAL,
	/// Bit-mask to get the attributes of a character
	Attributes = nc.A_ATTRIBUTES,
	/// Bit-mask to extract a character
	Chartext = nc.A_CHARTEXT,
	/// Bit-mask to extract a color
	Color = nc.A_COLOR,
	/// Best highlighting mode of the terminal
	Standout = nc.A_STANDOUT,
	/// Underlining
	Underline = nc.A_UNDERLINE,
	/// Reverse video
	Reverse = nc.A_REVERSE,
	/// Blinking
	Blink = nc.A_BLINK,
	/// Half bright
	Dim = nc.A_DIM,
	/// Extra bright or bold
	Bold = nc.A_BOLD,
	/// Bit-mask for alternate character set
	AltCharset = nc.A_ALTCHARSET,
	/// Invisible or blank mode
	Invis = nc.A_INVIS,
	/// Protected mode
	Protect = nc.A_PROTECT,
	/// XSI extra conformance standard
	/// @{
	Horizontal = nc.A_HORIZONTAL,
	Left = nc.A_LEFT,
	Low = nc.A_LOW,
	Right = nc.A_RIGHT,
	Top = nc.A_TOP,
	Vertical = nc.A_VERTICAL,
	/// @}
}

package struct AttributeString {
private:
	nc.attr_t m_attr;
	string m_str;
	this(string s) {
		m_str = s;
	}
public:
	@property nc.attr_t attr() {
		return m_attr;
	}
	@property string str() {
		return m_str.idup;
	}
}

mixin template AttributeProperty(string name, string realname=name) {
	@property AttributeString AttributeProperty(AttributeString str) {
		str.m_attr |= mixin("nc.A_"~realname.toUpper());
		return str;
	}
	@property AttributeString AttributeProperty(string str) {
		AttributeString ret = str;
		ret.m_attr |= mixin("nc.A_"~realname.toUpper());
		return ret;
	}
	mixin("alias AttributeProperty "~name~";");
}

mixin AttributeProperty!"standout";
mixin AttributeProperty!"underline";
mixin AttributeProperty!("reversed","reverse");
mixin AttributeProperty!"blink";
mixin AttributeProperty!"dim";
mixin AttributeProperty!"bold";
