package dn;

// Version numbers should follow SemVer semantic x.y.z-label
// Everything except x is optional
// See: https://semver.org/

typedef ChangelogEntry = {
	var fullVersion: String;
	var major: Int;
	var minor: Null<Int>;
	var patch: Null<Int>;
	var metaLabel: Null<String>;

	var title: Null<String>;
	var linesMd : Array<String>;
}

class Changelog {
	static var VERSION_TITLE_REG = ~/^[ \t]*##[ \t]+([0-9.]+)[ \t\-]*(.*)$/gim;
	static var VERSION_NUMBER_REG = ~/^([0-9]+)[.]*([0-9a-z]*)[.]*([0-9]*)\-*([a-z0-9]*)/gi;

	public var versions : Array<ChangelogEntry>;

	public function new(markdown:String) {
		parse(markdown);
	}

	public function parse(markdown:String) {
		versions = [];

		var lines = markdown.split("\n");
		var cur  : ChangelogEntry = null;
		for(l in lines) {
			// l = StringTools.trim(l);
			// if( l.length==0 )
			// 	continue;

			if( VERSION_TITLE_REG.match(l) ) {
				cur = {
					fullVersion: VERSION_TITLE_REG.matched(1),
					major: -1,
					minor: -1,
					patch: -1,
					metaLabel: null,
					title: VERSION_TITLE_REG.matched(2),
					linesMd: [],
				}

				if( !VERSION_NUMBER_REG.match(cur.fullVersion) )
					throw "Version number "+cur.fullVersion+" in changelog doesn't comply to SemVer semantics";

				cur.major = Std.parseInt( VERSION_NUMBER_REG.matched(1) );

				if( VERSION_NUMBER_REG.matched(2)!=null )
					cur.minor = Std.parseInt( VERSION_NUMBER_REG.matched(2) );

				if( VERSION_NUMBER_REG.matched(3)!=null )
					cur.patch = Std.parseInt( VERSION_NUMBER_REG.matched(3) );

				if( VERSION_NUMBER_REG.matched(4)!=null )
					cur.metaLabel = VERSION_NUMBER_REG.matched(4);

				versions.push(cur);
				continue;
			}

			if( cur==null )
				continue;

			cur.linesMd.push(l);
		}
	}
}