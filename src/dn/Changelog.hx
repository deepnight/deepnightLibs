package dn;

// Version numbers should follow SemVer semantic x.y.z-label
// Everything except x is optional
// See: https://semver.org/

typedef ChangelogEntry = {
	/**
		Version with format x.y.z[-label]
	**/
	var version : dn.Version;

	/**
		Version title
	**/
	var title: Null<String>;

	/**
		Markdown description lines
	**/
	var allNoteLines : Array<String>;

	/**
		Markdown description lines
	**/
	var notEmptyNoteLines : Array<String>;
}


class Changelog {
	/**
		Customizable title parser to recognize lines with a new version number
	**/
	public static var VERSION_TITLE_REG = ~/^[ \t]*#[ \t]+v?([0-9]+[0-9.a-z\-]*)[\- \t]*(.*)$/gim;

	/**
		Changelog entries
	**/
	public var entries : Array<ChangelogEntry>;

	/** Latest entry **/
	public var latest(get,never) : Null<ChangelogEntry>;
		inline function get_latest() return entries.length==0 ? null : entries[0];

	/** Latest entry **/
	public var oldest(get,never) : Null<ChangelogEntry>;
		inline function get_oldest() return entries.length==0 ? null : entries[ entries.length-1 ];

	/**
		Version numbers should comply to the SemVer format.
		See parse() for more informations.
	**/
	public function new(markdown:String) {
		parse(markdown);
	}

	/**
		Return a short description of the changelog data.
	**/
	@:keep
	public function toString() {
		return 'Changelog, ${entries.length} entries = ['
			+ entries.map(function(v) {
				return '${v.version.full}, "${v.title}", ${v.notEmptyNoteLines.length} lines';
			}).join("], [")
			+ "]";
	}

	public static inline function fromString(markdown:String) {
		return new Changelog(markdown);
	}

	/**
		Version numbers should comply to the SemVer format.

		Changelog markdown should comply to the example below. Parser can be customized by
		changing static RegEx.

		\#\# 0.1 - Some title

		Some markdown...

		Another markdown...

		\#\# 0.0.1-alpha - Another title

		A markdown paragraph...
	**/
	public function parse(markdown:String) {
		entries = [];

		var endl = markdown.indexOf("\r\n")>=0 ? "\r\n" : "\n";
		var lines = markdown.split( endl );
		var cur  : ChangelogEntry = null;
		for(l in lines) {
			if( VERSION_TITLE_REG.match(l) ) {
				var rawVersion = VERSION_TITLE_REG.matched(1);

				// Parse version number according to SemVer format
				if( !Version.isValid(rawVersion, true) )
					throw 'Version number "$rawVersion" in changelog do not comply to SemVer semantics';

				var ver = new Version(rawVersion);
				cur = {
					version: ver,
					title: VERSION_TITLE_REG.matched(2)=="" ? null : VERSION_TITLE_REG.matched(2),
					allNoteLines: [],
					notEmptyNoteLines: [],
				}

				entries.push(cur);
				continue;
			}

			if( cur==null )
				continue;

			cur.allNoteLines.push(l);
			var trim = trimLine(l);
			if( trim.length>0 )
				cur.notEmptyNoteLines.push(l);
		}

		entries.sort( function(a,b) return -a.version.compareEverything( b.version ) );
	}

	function trimLine(l:String) {
		while( l.length>0 && ( l.charAt(0)==" " || l.charAt(0)=="\t" ) )
			l = l.substr(1);

		while( l.length>0 && ( l.charAt(l.length-1)==" " || l.charAt(l.length-1)=="\t" ) )
			l = l.substr(0, l.length-1);

		return l;
	}


	@:noCompletion
	public static function __test() {
		var markDown = "
		# 0.9 - Not in proper position

		Some note

		# 1 - Release

		Some note

		- list 1
		- list 2


		# 0.7-beta - Some update

		Some note

		# 0.1-alpha - not in the right position
		markdown
		Some note

		# 0.2-beta - Going beta

		Some note
		";

		var c = new Changelog( markDown );

		CiAssert.isTrue( c.entries.length>0 );

		CiAssert.isNotNull( c.latest );
		CiAssert.isTrue( c.latest.version.full == "1.0.0" );
		CiAssert.isTrue( c.latest.title == "Release" );
		CiAssert.isTrue( c.latest.allNoteLines.length==7 );
		CiAssert.isTrue( c.latest.notEmptyNoteLines.length==3 );

		CiAssert.isNotNull( c.oldest );
		CiAssert.isTrue( c.oldest.version.full == "0.1.0-alpha" );
	}
}