/**
 * @file formatting.d
 * @brief Structures and functions for attributes and formatting
 * @author Matthew Soucy <msoucy@csh.rit.edu>
 * @date Nov 12, 2012
 * @version 0.0.1
 */
/// Structures and functions for attributes and formatting
module metus.dncurses.formatting;

/// @cond NoDoc
import std.traits;
public import metus.dncurses.base;
/// @endcond


/**
 * Create a vertical line
 *
 * @param ch The character to print
 * @param n The length of the line
 * @return A TextAttribute that generates a horizontal line
 */
TextAttribute vline(CharType ch, int n) pure nothrow {
	return new class TextAttribute {
		void apply(nc.WINDOW* win) {
			nc.wvline(win, ch, n);
		}
		void bkgd(nc.WINDOW* win) {
			throw new NCursesException("Cannot put vline onto background");
		}
	};
}

/**
 * Create a horizontal line
 *
 * @param ch The character to print
 * @param n The length of the line
 * @return A TextAttribute that generates a vertical line
 */
TextAttribute hline(CharType ch, int n) pure nothrow {
	return new class TextAttribute {
		void apply(nc.WINDOW* win) {
			nc.whline(win, ch, n);
		}
		void bkgd(nc.WINDOW* win) {
			throw new NCursesException("Cannot put hline onto background");
		}
	};
}


/**
 * String with formatting
 *
 * Contains information about which attributes to turn on or off for this string
 */
package struct AttributeString {
private:
	nc.attr_t m_attr;
	nc.attr_t m_noattr;
	string m_str;
public:
	/**
	 * Create a new AttributeString
	 *
	 * @param s The D string to use as a source
	 */
	this(string s) @safe pure {
		m_str = s.idup;
	}
	/**
	 * Get the attributes to enable
	 *
	 * @return A compound of all attributes to enable
	 */
	nc.attr_t attr() @property @safe pure nothrow const {
		return m_attr;
	}
	/**
	 * Get the attributes to disable
	 *
	 * @return A compound of all attributes to disable
	 */
	nc.attr_t attrDisable() @property @safe pure nothrow const {
		return m_noattr;
	}
	/**
	 * Get the raw string
	 *
	 * @return The basic string without formatting
	 */
	string str() @property @safe pure nothrow const {
		return m_str;
	}

	/// @cond NoDoc
	alias this = m_str;

	/// Allow assignment concatenation with a string
	ref AttributeString opOpAssign(string op:"~")(string s) @property @safe pure nothrow {
		this.m_str ~= s;
		return this;
	}
	/// Allow concatenation with a string
	AttributeString opBinary(string op:"~")(string s) @property @safe pure nothrow const {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
	/// Allow assignment concatenation with strings with matching attributes
	AttributeString opOpAssign(string op:"~")(AttributeString s) @property @safe pure nothrow {
		if(this.m_attr != s.m_attr) {
			throw new NCursesException("Cannot concatenate strings with different attributes");
		}
		this.m_str ~= s;
		return this;
	}
	/// Allow concatenation with strings with matching attributes
	AttributeString opBinary(string op:"~")(AttributeString s) @property @safe pure nothrow const {
		AttributeString ret = this;
		ret ~= s;
		return ret;
	}
	/// @endcond
}

/// Basic interface for Text Attributes
package interface TextAttribute {
public:
	/// Apply an attribute to a window
	void apply(nc.WINDOW*);
	/// Apply an attribute to a window's background
	void bkgd(nc.WINDOW*);
}

private mixin template AttributeProperty(string name, string realname=name) {
	// Add a property to a string with attributes
	AttributeString AttributeProperty(AttributeString str) @property @safe pure nothrow {
		str.m_attr |= mixin("nc.A_"~realname.toUpper());
		str.m_noattr &= ~mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Add a property to a regular string
	AttributeString AttributeProperty(string str) @property @safe pure {
		return mixin(`AttributeString(str).`~name~`()`);
	}

	// Turn a formatted character into a formatted string
	AttributeString AttributeProperty(nc.chtype ch) @property @safe pure {
		AttributeString ret = "";
		ret ~= ch & nc.A_CHARTEXT;
		ret.m_attr = (ch & nc.A_ATTRIBUTES) | mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	// Enable a property
	TextAttribute AttributeProperty() @property pure nothrow {
		return new class TextAttribute {
			void apply(nc.WINDOW* win) {
				if(nc.wattron(win, mixin("nc.A_"~realname.toUpper())) != nc.OK) {
					throw new NCursesException("Could not set attributes");
				}
			}
			void bkgd(nc.WINDOW* win) {
				nc.wbkgdset(win, nc.getbkgd(win)|mixin("nc.A_"~realname.toUpper()));
			}
		};
	}

	mixin("alias AttributeProperty "~name~";");

	// Disable a property
	TextAttribute NoAttributeProperty() @property pure nothrow {
		return new class TextAttribute {
			void apply(nc.WINDOW* win) {
				if(nc.wattroff(win, mixin("nc.A_"~realname.toUpper())) != nc.OK) {
					throw new NCursesException("Could not set attributes");
				}
			}
			void bkgd(nc.WINDOW* win) {
				nc.wbkgdset(win, nc.getbkgd(win)&~mixin("nc.A_"~realname.toUpper()));
			}
		};
	}

	mixin("alias NoAttributeProperty no"~name~";");


	// Remove a property from a string with attributes
	AttributeString NoAttributeProperty(AttributeString str) @property @safe pure nothrow {
		str.m_attr &= ~mixin("nc.A_"~realname.toUpper());
		str.m_noattr |= mixin("nc.A_"~realname.toUpper());
		return str;
	}

	// Remove a property from a string
	AttributeString NoAttributeProperty(string str) @property @safe pure {
		AttributeString ret = str;
		ret.m_noattr = mixin("nc.A_"~realname.toUpper());
		return ret;
	}

	mixin("alias NoAttributeProperty no"~name~";");


	bool CheckAttributeProperty(CharType ch) @property @safe pure nothrow {
		return (ch & mixin("nc.A_"~realname.toUpper())) != 0;
	}
	bool CheckAttributeProperty(inout(AttributeString) str) @property @safe pure nothrow {
		return (str.m_attr & mixin("nc.A_"~realname.toUpper())) != 0;
	}

	mixin("alias CheckAttributeProperty is"~name~";");
}

/**
 * Clear all attributes from a window
 *
 * @return An attribute object that a Window uses to clear attributes
 */
TextAttribute attrclear() @property pure nothrow {
	return new class TextAttribute {
		/// Remove all attributes from a window
		void apply(nc.WINDOW* win) {
			if(nc.wattrset(win, nc.chtype.init) != nc.OK) {
				throw new NCursesException("Could not set attributes");
			}
		}

		/// Clear all attributes from a window's background
		void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, nc.chtype.init);
		}
	};
}

/// @cond NoDoc
mixin AttributeProperty!"standout"; ///< Creates standout attribute
mixin AttributeProperty!"underline"; ///< Creates underline attribute
mixin AttributeProperty!("invert","reverse"); ///< Creates reversed attribute
mixin AttributeProperty!"blink"; ///< Creates blink attribute
mixin AttributeProperty!"dim"; ///< Creates dim attribute
mixin AttributeProperty!"bold"; ///< Creates bold attribute
mixin AttributeProperty!"invis"; ///< Creates invisible attributes
mixin AttributeProperty!"protect"; ///< Creates attribute to protect a character
mixin AttributeProperty!"horizontal"; ///< Creates an extension attribute
mixin AttributeProperty!"left"; ///< Creates an extension attribute
mixin AttributeProperty!"low"; ///< Creates an extension attribute
mixin AttributeProperty!"right"; ///< Creates an extension attribute
mixin AttributeProperty!"top"; ///< Creates an extension attribute
mixin AttributeProperty!"vertical"; ///< Creates an extension attribute
/// @endcond

////////////////////////////////////////////////////////////////////////////////
// Colors
////////////////////////////////////////////////////////////////////////////////

/// All colors used by ncurses
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

private {
	enum FG_SHIFT = 8;
	enum FG_MASK = 0b00000000_00000000_00000111_00000000UL;
	enum BG_SHIFT = 11;
	enum BG_MASK = 0b00000000_00000000_00111000_00000000UL;
}

/**
 * Detect color support
 *
 * @return true if colors can be used, false otherwise
 */
bool hasColors() {
	return nc.has_colors();
}

private short mkPairNum(short fg, short bg) @safe pure nothrow {
	return ((bg<<3)|fg)&0xFFFF;
}

private short mkPairNum(ulong attrs) @safe pure nothrow {
	return mkPairNum(((attrs&~FG_MASK)>>FG_SHIFT)&0xFFFF, ((attrs&~BG_MASK)>>BG_SHIFT)&0xFFFF);
}

/**
 * Initialize colors
 *
 * Start ncurses' color mode and create the required color pairs
 */
void initColor() {
	assert(nc.has_colors());
	nc.start_color();
	assert(nc.COLOR_PAIRS >= Color.max*Color.max);
	foreach(Color bg ; EnumMembers!Color) {
		foreach(Color fg ; EnumMembers!Color) {
			nc.init_pair(mkPairNum(fg, bg), fg, bg);
		}
	}
}


/**
 * @name Set foreground color
 * @param str The string to apply the color to
 * @param c The color to apply to the foreground
 * @{
 */
/**
 * Set foreground color on a string
 *
 * @param str The string to apply the color to
 * @param c The color to apply
 * @return An attribute string with the new foreground applied
 */
AttributeString fg(AttributeString str, short c) @property @safe pure nothrow {
	str.m_noattr |= FG_MASK;
	str.m_attr = (str.m_attr & ~FG_MASK) | (c<<FG_SHIFT);
	return str;
}

/**
 * Set foreground color on a string
 *
 * @param str The string to apply the color to
 * @param c The color to apply
 * @return An attribute string with the new foreground applied
 */
AttributeString fg(string str, short c) @property @safe pure {
	return AttributeString(str).fg(c);
}

/**
 * Set foreground color on a window
 *
 * @param c The color to apply
 * @return A text attribute object that the window evaluates
 */
TextAttribute fg(short c) @property pure nothrow {
	return new class TextAttribute {
		/// Apply a background color to a window
		void apply(nc.WINDOW* win) {
			if(nc.wcolor_set(win, (mkPairNum(win.attrs) & 0b00111000) | c, cast(void*)0) != nc.OK) {
				throw new NCursesException("Could not set foreground color");
			}
		}
		/// Apply a foreground color to a window's background
		void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, (nc.getbkgd(win) & ~FG_MASK) | (c<<FG_SHIFT));
		}
	};
}
/// @}

/**
 * @name Remove background color
 * @{
 */
/**
 * Remove foreground color from a string
 *
 * @param str The string to remove the color from
 * @return An attribute string with the foreground removed
 */
AttributeString nofg(AttributeString str) @property @safe pure nothrow {
	str.m_noattr |= FG_MASK;
	str.m_attr &= ~FG_MASK;
	return str;
}

/**
 * Remove foreground color from a string
 *
 * @param str The string to remove the color from
 * @return An attribute string with the foreground removed
 */
AttributeString nofg(string str) @property @safe pure {
	return AttributeString(str).nofg();
}

/**
 * Remove foreground color from a window
 *
 * @return A text attribute object that the window evaluates
 */
TextAttribute nofg() @property pure nothrow {
	return new class TextAttribute {
		/// Remove a foreground color from a window
		void apply(nc.WINDOW* win) {
			if(nc.wcolor_set(win, mkPairNum(win.attrs) & 0b00111000, cast(void*)0) != nc.OK) {
				throw new NCursesException("Could not set foreground color");
			}
		}
		/// Remove a foreground color from a window's background
		void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, nc.getbkgd(win) & ~FG_MASK);
		}
	};
}
/// @}

/**
 * @name Set background color
 * @param str The string to apply the color to
 * @param c The color to apply to the background
 * @{
 */
/**
 * Set background color on a string
 *
 * @param str The string to apply the color to
 * @param c The color to apply
 * @return An attribute string with the new background applied
 */
AttributeString bg(AttributeString str, short c) @property @safe pure nothrow {
	str.m_noattr |= BG_MASK;
	str.m_attr = (str.m_attr & ~BG_MASK) | (c<<BG_SHIFT);
	return str;
}

/**
 * Set background color on a string
 *
 * @param str The string to apply the color to
 * @param c The color to apply to the background
 * @return An attribute string with the new background applied
 */
AttributeString bg(string str, short c) @property @safe pure {
	return AttributeString(str).bg(c);
}

/**
 * Set background color on a window
 *
 * @param c The color to apply
 * @return A text attribute object that the window evaluates
 */
TextAttribute bg(short c) @property pure nothrow {
	return new class TextAttribute {
		/// Apply a background color to a window
		void apply(nc.WINDOW* win) {
			if(nc.wcolor_set(win, ((mkPairNum(win.attrs) & 0b00000111) | (c<<3)) & 0xFFFF, cast(void*)0) != nc.OK) {
				throw new NCursesException("Could not set background color");
			}
		}
		/// Apply a background color to a window's background
		void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, (nc.getbkgd(win) & ~BG_MASK) | (c<<BG_SHIFT));
		}
	};
}
/// @}

/**
 * @name Remove background color
 * @{
 */
/**
 * Removes background color from a string
 *
 * @param str The string to remove the color from
 * @return An attribute string with the background removed
 */
AttributeString nobg(AttributeString str) @property @safe pure nothrow {
	str.m_noattr |= BG_MASK;
	str.m_attr &= ~BG_MASK;
	return str;
}

/**
 * Removes background color from a string
 *
 * @param str The string to remove the color from
 * @return An attribute string with the background removed
 */
AttributeString nobg(string str) @property @safe pure {
	return AttributeString(str).nobg();
}

/**
 * Remove background color from a window
 *
 * @return A text attribute object that the window evaluates
 */
TextAttribute nobg() @property pure nothrow {
	return new class TextAttribute {
		/// Remove a background color from a window
		void apply(nc.WINDOW* win) {
			if(nc.wcolor_set(win, mkPairNum(win.attrs) & 0b00000111, cast(void*)0) != nc.OK) {
				throw new NCursesException("Could not set background color");
			}
		}
		/// Remove a background color from a window's background
		void bkgd(nc.WINDOW* win) {
			nc.wbkgdset(win, nc.getbkgd(win) & ~BG_MASK);
		}
	};
}
/// @}

/**
 * @name Set colors on a string
 * @param str The string to apply the color to
 * @param f The color to apply to the foreground
 * @param b The color to apply to the background
 * @return An AttributeString with the colors applied
 * @{
 */

AttributeString color(AttributeString str, short f, short b) @safe pure nothrow {
	return str.fg(f).bg(b);
}
AttributeString color(string str, short f, short b) @safe pure {
	return AttributeString(str).fg(f).bg(b);
}

/// @}
