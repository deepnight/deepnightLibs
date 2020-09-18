package dn;

class VersionNumber {
	static var VERSION_REG = ~/^([0-9]+)[.]*([0-9a-z]*)[.]*([0-9]*)\-*([a-z0-9]*)/gi;

	public var major = 0;
	public var minor = 0;
	public var patch = 0;
	public var tag : Null<String>;

	public function new(?v:String) {
		if( v!=null && VERSION_REG.match(v) ) {
			major = Std.parseInt( VERSION_REG.matched(1) );
			minor = VERSION_REG.matched(2)=="" ? 0 : Std.parseInt( VERSION_REG.matched(2) );
			patch = VERSION_REG.matched(3)=="" ? 0 : Std.parseInt( VERSION_REG.matched(3) );
			tag = VERSION_REG.matched(4)=="" ? null : VERSION_REG.matched(4);
		}
	}



	/**
		Return 0 if both versions are equal, 1 if greater than "with", -1 if lower than "with"

		tag is ignored
	**/
	public function compare(?with:VersionNumber, ?withStr:String) {
		if( with==null )
			with = new VersionNumber(withStr);

		// if( major==with.major && minor==with.minor && patch==with.patch )
		// 	return 0;

		if( major!=with.major )
			return Reflect.compare(major, with.major);
		else if( minor!=with.minor )
			return Reflect.compare(minor, with.minor);
		else if( patch!=with.patch )
			return Reflect.compare(patch, with.patch);
		else
			return 0;
	}


	/**
		Return TRUE is "cur" is greater than "than"
	**/
	public static inline function isGreater(cur:String, than:String) : Bool {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) > 0;
	}


	/**
		Return TRUE is "cur" is lower than "than"
	**/
	public static inline function isLower(cur:String, than:String) : Bool {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) < 0;
	}


	/**
		Return TRUE is both versions are equal (NOTE: tag is ignored)
	**/
	public static inline function isEqual(cur:String, than:String) : Bool return {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) == 0;
	}


	@:keep
	public function toString() {
		trace(major+" "+minor+" "+patch+" "+tag);
		return'$major.$minor.$patch${ tag!=null ? "-"+tag : "" }';
	}


	@:noCompletion
	public static function __test() {
		CiAssert.isNotNull( new VersionNumber() );
		CiAssert.isNotNull( new VersionNumber("1") );
		CiAssert.isNotNull( new VersionNumber("1.2") );
		CiAssert.isNotNull( new VersionNumber("1.2.3") );
		CiAssert.isTrue( new VersionNumber("10.02.30").major==10 );
		CiAssert.isTrue( new VersionNumber("10.02.30").minor==2 );
		CiAssert.isTrue( new VersionNumber("10.02.30").patch==30 );
		CiAssert.isTrue( new VersionNumber("1").minor==0 );
		CiAssert.isTrue( new VersionNumber("1.2").patch==0 );
		CiAssert.isTrue( new VersionNumber("1.0.6").patch==6 );
		CiAssert.isTrue( new VersionNumber("1.0.6-someTag").patch==6 );
		CiAssert.isTrue( new VersionNumber("1.0.6-someTag").tag=="someTag" );
		CiAssert.isTrue( new VersionNumber("1.0.6-some tag").tag=="some" );

		var a = new VersionNumber("1.0.2");
		var b = new VersionNumber("0.10.2-alpha");
		var c = new VersionNumber("1.0.3-rc1");

		CiAssert.isNotNull(a);
		CiAssert.isNotNull(b);
		CiAssert.isNotNull(c);

		CiAssert.isTrue( a.compare(b)==1 );
		CiAssert.isTrue( a.compare(c)==-1 );
		CiAssert.isTrue( b.compare(a)==-1 );

		CiAssert.isTrue( VersionNumber.isGreater("1.0.5", "0.9.9-alpha") );
		CiAssert.isTrue( VersionNumber.isLower("1.0.5", "1.1.0-alpha") );
		CiAssert.isTrue( VersionNumber.isEqual("1.0.5", "1.0.5") );
		CiAssert.isTrue( VersionNumber.isEqual("1.0", "1.0-alpha") );
	}
}