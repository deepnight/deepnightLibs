package dn;

// Version numbers should follow SemVer semantic x.y.z-label
// Everything except x is optional
// See: https://semver.org/

class VersionNumber {
	static var VERSION_REG = ~/^[ \t]*([0-9]+)[.]*([0-9a-z]*)[.]*([0-9]*)\-*([a-z0-9]*)/gim;

	public var major = 0;
	public var minor = 0;
	public var patch = 0;
	public var label : Null<String>;

	/** Version string in format "x.y.z" (without label)**/
	public var numbers(get,never) : String;
		inline function get_numbers() return '$major.$minor.$patch';

	/** Version string in format "x.y.z[-label]"" **/
	public var full(get,never) : String;
		inline function get_full() return '$numbers${ label!=null ? "-"+label : "" }';


	/**
		"v" should be a version number using "x.y.z[-label]" format.
	**/
	public function new(?v:String) {
		if( v!=null )
			set(v);
	}

	/**
		Set version using "x.y.z[-label]" format.
	**/
	public function set(v:String) {
		if( v!=null && VERSION_REG.match(v) ) {
			major = Std.parseInt( VERSION_REG.matched(1) );
			minor = VERSION_REG.matched(2)=="" ? 0 : Std.parseInt( VERSION_REG.matched(2) );
			patch = VERSION_REG.matched(3)=="" ? 0 : Std.parseInt( VERSION_REG.matched(3) );
			label = VERSION_REG.matched(4)=="" ? null : VERSION_REG.matched(4);
		}
	}

	@:keep
	public function toString() return full;


	/**
		Return TRUE if the provided version complies to SemVer semantic "x.y.z[-label]"
	**/
	public static inline function isValid(v:String) {
		return v!=null && VERSION_REG.match(v);
	}

	/**
		Similar to Reflect.compare().

		Return 0 if versions are equal, 1 if this is greater than "with", -1 if this is lower than "with"
	**/
	public function compare(?with:VersionNumber, ?withStr:String, ignoreLabel=false) {
		if( with==null )
			with = new VersionNumber(withStr);

		if( major!=with.major )
			return Reflect.compare(major, with.major);
		else if( minor!=with.minor )
			return Reflect.compare(minor, with.minor);
		else if( patch!=with.patch )
			return Reflect.compare(patch, with.patch);
		else if( !ignoreLabel && label!=with.label)
			return Reflect.compare(label, with.label);
		else
			return 0;
	}

	/**
		Return TRUE is both versions are strictly equal

		@param ignoreLabel if TRUE, the label isn't compared (x-y-z-label)
	**/
	public inline function isEqual(?vString:String, ?vClass:dn.VersionNumber, ignoreLabel=false) {
		return
			vString==null && vClass!=null ? compare(vClass, ignoreLabel)==0 :
			vString!=null ? compare(vString, ignoreLabel)==0 :
			false;
	}

	/**
		Return TRUE if "x.y.\*.\*" parts are equal (patch and label are ignored)
	**/
	public inline function sameMajorAndMinor(?vString:String, ?vClass:dn.VersionNumber) {
		if( vString==null && vClass==null )
			return false;

		if( vClass==null )
			vClass = new VersionNumber(vString);

		return vClass.major==major && vClass.minor==minor;
	}


	/**
		Return TRUE is "cur" is greater than "than"
	**/
	public static inline function isGreaterStr(cur:String, than:String) : Bool {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) > 0;
	}


	/**
		Return TRUE is "cur" is lower than "than"
	**/
	public static inline function isLowerStr(cur:String, than:String) : Bool {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) < 0;
	}


	/**
		Return TRUE is both versions are equal (NOTE: label is ignored)
	**/
	public static inline function isEqualStr(cur:String, than:String) : Bool return {
		return new VersionNumber(cur).compare( new VersionNumber(than) ) == 0;
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
		CiAssert.isTrue( new VersionNumber("   1.2.3").major==1 );
		CiAssert.isTrue( new VersionNumber("1").minor==0 );
		CiAssert.isTrue( new VersionNumber("1.2").patch==0 );
		CiAssert.isTrue( new VersionNumber("1.0.6").patch==6 );
		CiAssert.isTrue( new VersionNumber("1.0.6-someLabel").patch == 6 );
		CiAssert.isTrue( new VersionNumber("1.0.6-someLabel").label == "someLabel" );
		CiAssert.isTrue( new VersionNumber("1.0.6-some tag").label == "some" );
		CiAssert.isTrue( new VersionNumber("   1.2.3  ").full=="1.2.3" );
		CiAssert.isTrue( new VersionNumber("1.2.3-alpha").numbers=="1.2.3" );

		CiAssert.isTrue( new VersionNumber("1.0.1").compare( new VersionNumber("1.0.1") ) == 0 );
		CiAssert.isTrue( new VersionNumber("0.0.2").compare( new VersionNumber("0.0.1") ) == 1 );
		CiAssert.isTrue( new VersionNumber("0.0.2").compare( new VersionNumber("0.0.3") ) == -1 );
		CiAssert.isTrue( new VersionNumber("1.0.1").compare( new VersionNumber("1.0.2") ) == -1 );
		CiAssert.isTrue( new VersionNumber("1.0.1-a").compare( new VersionNumber("1.0.0-b") ) == 1 );
		CiAssert.isTrue( new VersionNumber("1.0.1-a").compare( new VersionNumber("1.0.1-b") ) == -1 );

		CiAssert.isTrue( new VersionNumber("1.0.1-a").isEqual("1.0.1-a") );
		CiAssert.isFalse( new VersionNumber("1.0.1-a").isEqual("1.0.1-b") );
		CiAssert.isFalse( new VersionNumber("1.0.1-a").isEqual("1.2") );
		CiAssert.isFalse( new VersionNumber("1.0.1-a").isEqual() );
		CiAssert.isTrue( new VersionNumber("1.0.1-a").isEqual( new VersionNumber("1.0.1-a") ) );
		CiAssert.isTrue( new VersionNumber("1.0.1-a").sameMajorAndMinor("1.0.2-b") );
		CiAssert.isTrue( new VersionNumber("1.0.1-a").sameMajorAndMinor( new VersionNumber("1.0.2-b") ) );

		CiAssert.isTrue( VersionNumber.isGreaterStr("1.0.5", "0.9.9-alpha") );
		CiAssert.isTrue( VersionNumber.isLowerStr("1.0.5", "1.1.0-alpha") );
		CiAssert.isTrue( VersionNumber.isEqualStr("1.0.5", "1.0.5") );
		CiAssert.isFalse( VersionNumber.isEqualStr("1.0", "1.0-alpha") );
		CiAssert.isTrue( VersionNumber.isEqualStr("1.0.5-a", "1.0.5-a") );
	}
}