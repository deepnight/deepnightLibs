package dn;

// Version numbers should follow SemVer semantic x.y.z-label
// Everything except x is optional
// See: https://semver.org/

typedef ChangelogEntry = {
	/**
		Version with format x[.y][.z][-label]
	**/
	var shortVersion: String;

	/**
		Version with format x.y.z[-label]
	**/
	var fullVersion: String;


	/**
		"x" in "x.y.z-label"
	**/
	var major: Int; // x

	/**
		"y" in "x.y.z-label"
	**/
	var minor: Null<Int>;

	/**
		"z" in "x.y.z-label"
	**/
	var patch: Null<Int>;

	/**
		"label" in "x.y.z-label"
	**/
	var metaLabel: Null<String>;

	/**
		Version title
	**/
	var title: Null<String>;

	/**
		Markdown description lines
	**/
	var linesMd : Array<String>;
}


class Changelog {
	/**
		Customizable title parser to recognize lines with a new version number
	**/
	public static var VERSION_TITLE_REG = ~/^[ \t]*##[ \t]+([0-9.a-z\-]+)[\- \t]*(.*)$/gim;

	static var VERSION_NUMBER_REG = ~/^([0-9]+)[.]*([0-9a-z]*)[.]*([0-9]*)\-*([a-z0-9]*)/gi;

	/**
		Changelog entries
	**/
	public var versions : Array<ChangelogEntry>;


	/**
		Version numbers should comply to the SemVer format.
		See parse() for more informations.
	**/
	public function new(markdown:String) {
		parse(markdown);
	}

	@:keep
	public function toString() {
		return 'Changelog, ${versions.length} entries = ['
			+ versions.map(function(v) {
				return '${v.fullVersion}, "${v.title}", ${v.linesMd.length} lines';
			}).join("], [")
			+ "]";
	}

	public static inline function fromString(markdown:String) {
		return new Changelog(markdown);
	}

	function getVersion(v:ChangelogEntry, fillZeros=false) : String {
		return v.major
		+ ( v.minor!=null ? "."+v.minor : fillZeros ? ".0" : "" )
		+ ( v.patch!=null ? "."+v.patch : fillZeros ? ".0" : "" )
		+ ( v.metaLabel!=null ? "-"+v.metaLabel : "" );
	}

	/**
		Version numbers should comply to the SemVer format.

		Changelog markdown should comply to the example below. Parser can be customized by
		changing static RegEx.

		\#\# 0.1 - Some title

		hello world

		foo

		\#\# 0.0.1-alpha - Another title

		bar
	**/
	public function parse(markdown:String) {
		versions = [];

		var lines = markdown.split("\n");
		var cur  : ChangelogEntry = null;
		for(l in lines) {
			if( VERSION_TITLE_REG.match(l) ) {
				var rawVersion = VERSION_TITLE_REG.matched(1);

				// Parse version number according to SemVer format
				var r = VERSION_NUMBER_REG;
				if( !r.match(rawVersion) )
					throw "Version number "+rawVersion+" in changelog doesn't comply to SemVer semantics";

				cur = {
					fullVersion: "???",
					shortVersion: "???",
					major: Std.parseInt( r.matched(1) ),
					minor: r.matched(2)!="" ? Std.parseInt( r.matched(2) ) : null,
					patch: r.matched(3)!="" ? Std.parseInt( r.matched(3) ) : null,
					metaLabel: r.matched(4)!="" ?r.matched(4) : null,
					title: VERSION_TITLE_REG.matched(2)=="" ? null : VERSION_TITLE_REG.matched(2),
					linesMd: [],
				}
				cur.fullVersion = getVersion(cur, true);
				cur.shortVersion = getVersion(cur, false);

				versions.push(cur);
				continue;
			}

			if( cur==null )
				continue;

			cur.linesMd.push(l);
		}
	}
}