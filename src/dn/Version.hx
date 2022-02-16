package dn;

/**
	Version numbers should follow SemVer semantic "x.y.z-preReleaseLabel". Everything except x is optional.
	"preReleaseLabel" can only contain numbers, letters and "-" and can have multiple parts separated by dots.

	Ex: 1.2.3-alpha.1,  1.0,  2-beta.20

	See: https://semver.org/
**/

class Version {
	static var VERSION_REG = ~/^[ \t]*([0-9]+)[.]*([0-9a-z]*)[.]*([0-9]*)\-*([a-z0-9.-]*)/gim;

	public var major = 0;
	public var minor = 0;
	public var patch = 0;
	public var preReleaseLabel : Null<String>;

	/** Version string in format "x.y.z" (without label)**/
	public var numbers(get,never) : String;
		inline function get_numbers() return '$major.$minor.$patch';

	/** Version string in format "x.y.z[-label]"" **/
	public var full(get,never) : String;
		inline function get_full() return '$numbers${ preReleaseLabel!=null ? "-"+preReleaseLabel : "" }';


	/**
		"v" should be a version number using "x.y.z[-preReleaseLabel]" format.
		The label should only contain letters, numbers dots and "-".
	**/
	public function new(?versionString:String) {
		if( versionString!=null )
			set(versionString);
	}

	/**
		Version string in format `x[.y[.z]]` (discard trailing zeros and without label). If `keepMinor` is TRUE, the ouput is `x.y[.z]`.
	**/
	public function getTrimmedNumbers(keepMinor:Bool) {
		return patch==0
			? minor==0 && !keepMinor
				? '$major'
				: '$major.$minor'
			: '$major.$minor.$patch';
	}

	/**
		Set version using "x.y.z[-preReleaseLabel]" format.
		The label should only contain letters, numbers, dots and "-".
	**/
	public function set(v:String) {
		if( v!=null && VERSION_REG.match(v) ) {
			major = Std.parseInt( VERSION_REG.matched(1) );
			minor = VERSION_REG.matched(2)=="" ? 0 : Std.parseInt( VERSION_REG.matched(2) );
			patch = VERSION_REG.matched(3)=="" ? 0 : Std.parseInt( VERSION_REG.matched(3) );
			preReleaseLabel = VERSION_REG.matched(4)=="" ? null : VERSION_REG.matched(4);
		}
	}

	@:keep
	public function toString() return full;


	/**
		Return TRUE if the provided version strictly complies to SemVer semantic "x.y.z[-preReleaseLabel]"
		If checked, the label should only contain letters, numbers, dots and "-".
	**/
	public static inline function isValid(v:String, checkLabel=true) {
		if( v==null )
			return false;
		else if( !checkLabel )
			return VERSION_REG.match(v);
		else {
			if( !VERSION_REG.match(v) )
				return false;
			else if( v.indexOf("-")>=0 && VERSION_REG.matched(4)!=v.substr(v.indexOf("-")+1) )
				return false;
			else if( v.indexOf("-")>=0 && VERSION_REG.matched(4)=="" )
				return false;
			else
				return true;
		}
	}

	/**
		Compare version numbers of `this` with `with`.

		Return values similar to Reflect.compare(). **0** if versions are equal, **1** if this is greater than "with", **-1** if this is lower than "with".

		Labels are NOT compared, so "1.0.0" equals "1.0.0-beta".
	**/
	public function compareNumbers(?withObj:Version, ?withStr:String) : Int {
		if( withObj==null )
			withObj = new Version(withStr);

		if( major!=withObj.major )
			return Reflect.compare(major, withObj.major);
		else if( minor!=withObj.minor )
			return Reflect.compare(minor, withObj.minor);
		else if( patch!=withObj.patch )
			return Reflect.compare(patch, withObj.patch);
		else
			return 0;
	}


	/**
		Compare `this` with `with`, including labels.

		Return values similar to Reflect.compare(). **0** if versions are equal, **1** if this is greater than "with", **-1** if this is lower than "with".

		Labels are compared using the SemVer specs, as described here: https://semver.org/#spec-item-11
		Ex: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
	**/
	public function compareEverything(?withObj:Version, ?withStr:String) : Int {
		// Check numbers
		var result = compareNumbers(withObj, withStr);
		if( result!=0 )
			return result;

		if( withObj==null )
			withObj = new Version(withStr);

		// No label
		if( preReleaseLabel==null && withObj.preReleaseLabel==null )
			return 0;

		// One has no label
		if( preReleaseLabel!=null && withObj.preReleaseLabel==null )
			return -1;
		else if( preReleaseLabel==null && withObj.preReleaseLabel!=null )
			return 1;

		// Compare labels parts, separated by "."
		var parts = preReleaseLabel.split(".");
		var withParts = withObj.preReleaseLabel.split(".");
		for( i in 0...M.imin(parts.length,withParts.length) ) {
			var id = Std.parseInt(parts[i]);
			var withId = Std.parseInt(withParts[i]);
			if( M.isValidNumber(id) && !M.isValidNumber(withId) ) // int is lower than string
				return -1;
			else if( !M.isValidNumber(id) && M.isValidNumber(withId) ) // string is greater than int
				return 1;
			else if( id!=withId && M.isValidNumber(id) && M.isValidNumber(withId) ) // compare ints
				return id<withId ? -1 : 1;
			else if( parts[i]!=withParts[i] && !M.isValidNumber(id) && !M.isValidNumber(withId) ) // compare string
				return Reflect.compare(parts[i], withParts[i]) > 0 ? 1 : -1;
		}

		// One has extra parts
		if( parts.length > withParts.length )
			return 1;
		else if( parts.length < withParts.length )
			return -1;

		return 0;
	}

	/**
		Return TRUE is both versions are strictly equal

		@param ignoreLabel if TRUE, the label isn't compared (x-y-z-label)
	**/
	public inline function isEqual(?withString:String, ?withClass:dn.Version, ignoreLabel=false) {
		if( withClass==null && withString==null )
			return false;

		if( withClass==null )
			withClass = new Version(withString);

		var result = compareNumbers(withClass);
		if( result==0 && !ignoreLabel && preReleaseLabel!=withClass.preReleaseLabel )
			return false;
		else
			return result==0;
	}

	/**
		Return TRUE if "x.y.\*.\*" parts are equal (patch and label are ignored)
	**/
	public inline function hasSameMajorAndMinor(?vString:String, ?vClass:dn.Version) {
		if( vString==null && vClass==null )
			return false;

		if( vClass==null )
			vClass = new Version(vString);

		return vClass.major==major && vClass.minor==minor;
	}


	/** Return TRUE is "cur" is greater than "than" **/
	public static inline function greater(cur:String, than:String, ignoreLabel:Bool) : Bool {
		return ignoreLabel
			? new Version(cur).compareNumbers(than) > 0
			: new Version(cur).compareEverything(than) > 0;
	}

	/** Return TRUE is "cur" is greater than or equal to "than" **/
	public static inline function greaterEq(cur:String, than:String, ignoreLabel:Bool) : Bool {
		return ignoreLabel
			? new Version(cur).compareNumbers(than) >= 0
			: new Version(cur).compareEverything(than) >= 0;
	}

	/** Return TRUE is "x" and "y" are equals in "x.y.z" **/
	public static inline function sameMajorAndMinor(a:String, b:String) : Bool {
		return new Version(a).hasSameMajorAndMinor(b);
	}


	/** Return TRUE is "cur" is lower than "than" **/
	public static inline function lower(cur:String, than:String, ignoreLabel:Bool) : Bool {
		return ignoreLabel
			? new Version(cur).compareNumbers(than) < 0
			: new Version(cur).compareEverything(than) < 0;
	}

	/** Return TRUE is "cur" is lower than or equal to "than" **/
	public static inline function lowerEq(cur:String, than:String, ignoreLabel:Bool) : Bool {
		return ignoreLabel
			? new Version(cur).compareNumbers(than) <= 0
			: new Version(cur).compareEverything(than) <= 0;
	}


	/**
		Return TRUE is both versions are strictly equal.
		If labels are ignored, "1.0-a" will be equal to "1.0-b".
	 **/
	public static inline function equal(cur:String, with:String, ignoreLabels=false) : Bool {
		return new Version(cur).isEqual( with, ignoreLabels );
	}



	@:noCompletion
	public static function __test() {
		CiAssert.isNotNull( new Version() );
		CiAssert.isNotNull( new Version("1") );
		CiAssert.isNotNull( new Version("1.2") );
		CiAssert.isNotNull( new Version("1.2.3") );
		CiAssert.isTrue( new Version("10.02.30").major==10 );
		CiAssert.isTrue( new Version("10.02.30").minor==2 );
		CiAssert.isTrue( new Version("10.02.30").patch==30 );
		CiAssert.isTrue( new Version("   1.2.3").major==1 );
		CiAssert.isTrue( new Version("1").minor==0 );
		CiAssert.isTrue( new Version("1.2").major==1 );
		CiAssert.isTrue( new Version("1.2").minor==2 );
		CiAssert.isTrue( new Version("1.2").patch==0 );
		CiAssert.isTrue( new Version("1.0.6").patch==6 );
		CiAssert.isTrue( new Version("1.0.6-someLabel").patch == 6 );
		CiAssert.isTrue( new Version("1.0.6-someLabel").preReleaseLabel == "someLabel" );
		CiAssert.isTrue( new Version("1.0.6-some tag").preReleaseLabel == "some" );
		CiAssert.isTrue( new Version("   1.2.3  ").full=="1.2.3" );
		CiAssert.isTrue( new Version("1.2.3-alpha").numbers=="1.2.3" );
		CiAssert.equals( new Version("1.2.3-alpha.2").preReleaseLabel, "alpha.2");
		CiAssert.equals( new Version("1.2.3-alpha-2").preReleaseLabel, "alpha-2");
		CiAssert.equals( new Version("1.2.3-alpha-2.0-c").preReleaseLabel, "alpha-2.0-c");
		CiAssert.equals( new Version("0.5.1-rc.1").preReleaseLabel, "rc.1");

		CiAssert.equals( new Version("1.2.3").compareNumbers("1.2.3"), 0 );

		// Patches
		CiAssert.equals( new Version("0.0.2").compareNumbers("0.0.1"), 1 );
		CiAssert.equals( new Version("0.0.1").compareNumbers("0.0.2"), -1 );
		CiAssert.equals( new Version("0.0.1-b").compareNumbers("0.0.2-a"), -1 );
		CiAssert.equals( new Version("0.0.1-a").compareNumbers("0.0.1-b"), 0 );

		// Minors
		CiAssert.equals( new Version("0.1.0").compareNumbers("0.2.0"), -1 );
		CiAssert.equals( new Version("0.2.0").compareNumbers("0.1.0"), 1 );
		CiAssert.equals( new Version("0.1.0-b").compareNumbers("0.2.0-a"), -1 );
		CiAssert.equals( new Version("0.1.0-a").compareNumbers("0.1.0-b"), 0 );


		// Majors
		CiAssert.equals( new Version("1.0.0").compareNumbers("2.0.0"), -1 );
		CiAssert.equals( new Version("2.0.0").compareNumbers("1.0.0"), 1 );
		CiAssert.equals( new Version("1.0.0-b").compareNumbers("2.0.0-a"), -1 );
		CiAssert.equals( new Version("1.0.0-a").compareNumbers("1.0.0-b"), 0 );

		// Labels
		CiAssert.isTrue( !new Version("1.0.0").isEqual("1.0.0-b") );
		CiAssert.isTrue( !new Version("1.0.0-a").isEqual("1.0.0-b") );
		CiAssert.isTrue( new Version("1.0.0-a").isEqual("1.0.0-b",true) );
		CiAssert.isTrue( new Version("1.0.0-a").isEqual("1.0.0-a") );
		CiAssert.isTrue( !new Version("1.0.0-a").isEqual("1.0.0-A") );

		// Label comparisons
		CiAssert.equals( new Version("1.0").compareEverything("1.0-a"), 1 );
		CiAssert.equals( new Version("1.0").compareEverything("1.0-1"), 1 );
		CiAssert.equals( new Version("1.0-b").compareEverything("1.0-a"), 1 );
		CiAssert.equals( new Version("1.0-a").compareEverything("1.0-b"), -1 );
		CiAssert.equals( new Version("1.0-alpha.10").compareEverything("1.0-alpha.2"), 1 );
		CiAssert.equals( new Version("1.0-alpha.beta").compareEverything("1.0-alpha.1"), 1 );
		CiAssert.equals( new Version("1.0-alpha.1").compareEverything("1.0-alpha"), 1 );
		CiAssert.equals( new Version("1.0-rc.1").compareEverything("1.0-alpha.beta.3"), 1 );

		// Incomplete versions
		CiAssert.equals( new Version("0.2").isEqual("0.2.0"), true );
		CiAssert.equals( new Version("2").isEqual("2.0.0"), true );
		CiAssert.equals( new Version("2-a").isEqual("2.0.0-a"), true );
		CiAssert.equals( new Version("0.2-a").isEqual("0.2.0-a"), true );

		// Bad labels
		CiAssert.equals( new Version("2-").isEqual("2.0.0"), true );
		CiAssert.equals( new Version("2- ?").isEqual("2.0.0"), true );

		// Validity
		CiAssert.isTrue( Version.isValid("1") );
		CiAssert.isTrue( Version.isValid("1.2") );
		CiAssert.isTrue( Version.isValid("1.2.3") );
		CiAssert.isTrue( Version.isValid("1-a") );
		CiAssert.isTrue( !Version.isValid("a") );
		CiAssert.isTrue( Version.isValid("11.22.33") );
		CiAssert.isTrue( Version.isValid("1.2.3-alpha1") );
		CiAssert.isTrue( Version.isValid("1.2.3-alpha-1") );
		CiAssert.isTrue( Version.isValid("1.2.3-alpha.1") );
		CiAssert.isTrue( !Version.isValid("1.2.3-alpha 1") );
		CiAssert.isTrue( !Version.isValid("2- ?") );
		CiAssert.isTrue( !Version.isValid("2-") );
		CiAssert.isTrue( !Version.isValid("-") );
		CiAssert.isTrue( !Version.isValid("2.0.0-") );
		CiAssert.isTrue( Version.isValid("2.0.0-rc.1") );

		// Major+minor checks
		CiAssert.isTrue( new Version("1.0.1-a").hasSameMajorAndMinor("1.0.2-b") );
		CiAssert.isTrue( new Version("1.0.1-a").hasSameMajorAndMinor( new Version("1.0.2-b") ) );
		CiAssert.isTrue( !new Version("1.0.0-a").hasSameMajorAndMinor("1.1.0-a") );

		// Static greater
		CiAssert.isTrue( Version.greater("1.0.5", "0.9.9-alpha", false) );
		CiAssert.isTrue( Version.greater("0.6.0-alpha", "0.5.9-beta.debug", false) );
		CiAssert.isTrue( Version.greater("0.6.0-beta", "0.6.0-alpha", false) );
		CiAssert.isTrue( Version.greater("0.6.0-beta.2", "0.6.0-beta.1", false) );
		CiAssert.isTrue( Version.greater("0.6.0", "0.6.0-beta.1", false) );
		CiAssert.isTrue( Version.greater("0.6.0-rc.10", "0.6.0-rc.2", false) );
		CiAssert.isTrue( !Version.greater("0.6.0-beta.2", "0.6.0-beta.1", true) );
		CiAssert.isTrue( Version.greaterEq("1.0.5", "1.0.5", false) );

		// Static lower
		CiAssert.isTrue( Version.lower("1.0.5", "1.1.0-alpha",false) );
		CiAssert.isTrue( Version.lower("0.5.9-beta-debug", "0.6",false) );
		CiAssert.isTrue( Version.lower("0.6.0-alpha", "0.6.0-beta",false) );
		CiAssert.isTrue( Version.lower("0.6.0-beta.1", "0.6.0", false) );
		CiAssert.isTrue( Version.lower("0.6.0-rc.2", "0.6.0-rc.10", false) );
		CiAssert.isTrue( !Version.lower("0.6.0-alpha", "0.6.0-beta",true) );
		CiAssert.isTrue( Version.lowerEq("1.0.5", "1.0.5",false) );

		CiAssert.isTrue( Version.equal("1.0.5", "1.0.5") );
		CiAssert.isTrue( !Version.equal("1.0", "1.0-alpha") );
		CiAssert.isTrue( Version.equal("1", "1.0") );
		CiAssert.isTrue( Version.equal("1", "1.0.0") );
		CiAssert.isTrue( Version.equal("0.1", "0.1.0") );
		CiAssert.isTrue( Version.equal("1.0.5-a", "1.0.5-a") );
		CiAssert.isTrue( Version.equal("1.0.5-alpha", "1.0.5-beta", true) );
	}
}