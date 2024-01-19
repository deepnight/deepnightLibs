package dn;

class Args {
	static var ARG_REG = ~/^\s*(-{1,2}[a-z0-9-]+(?:$|[=:]|\s+))/gi;

	/** Raw args string as initially provided to the constructor **/
	public var raw(default,null) : String;

	var args(default,null) : Map<String, Array<String>> = new Map();
	var soloValues(default,null) : Array<String> = [];

	/**
		Parse arguments in given String. Supported args format: -v, --v, -v=5, -v:5 and solo (isolated) values.

		`knownArgs` is a map of known args with X expected following parameters. It is required to parse properly args like `-v foo bar`, where foo and bar should be considered as the 2 following parameters of -v.
	**/
	public function new(rawArgs:String, ?knownArgs:Map<String, Int>, debug=false) {
		// RegExs
		var valueReg = ~/^\s*(?:"([^-].*?)"|'([^-].*?)'|([^-\s].*?)(?:\s|$))/gi;
		var argNameReg = ~/^(-{0,2}.*?)(?:[=:\s]|$)/gi;

		// Init
		this.raw = rawArgs;

		// Check known args
		if( knownArgs==null )
			knownArgs = new Map();
		for( a in knownArgs.keyValueIterator() )
			if( !argNameReg.match(a.key) )
				throw "Malformed known arg: "+a.key;
		if( debug )
			trace("KnownArgs: "+knownArgs);

		// Parse args
		var str = rawArgs;
		while( true ) {
			if( ARG_REG.match(str) ) {
				// Found an arg
				if( debug )
					trace("Found arg: "+ARG_REG.matched(1));

				argNameReg.match( ARG_REG.matched(1) );
				var argName = argNameReg.matched(1);
				args.set(argName, []);
				if( debug )
					trace('  (argName="$argName")');

				// Determine following params count
				var valueCount = knownArgs.exists(argName)
						? knownArgs.get(argName)
						: ARG_REG.matched(1).indexOf("=")>=0 ? 1 : 0;

				str = ARG_REG.matchedRight();

				// Parse following values
				if( valueCount>0 ) {
					if( debug )
						trace('  Expecting $valueCount following parameter(s)');

					var idx = 0;
					while( valueCount>0 ) {
						if( valueReg.match( str ) ) {
							var v = valueReg.matched( valueReg.matched(1)==null ? valueReg.matched(2)==null ? 3 : 2 : 1 );
							if( debug )
								trace('   -> Parameter#$idx=$v');
							args.get(argName).push(v);
							str = valueReg.matchedRight();
							valueCount--;
							idx++;
						}
						else
							break;
					}
				}
			}
			else if( valueReg.match(str) ) {
				// Found a solo value
				var v = valueReg.matched( valueReg.matched(1)==null ? valueReg.matched(2)==null ? 3 : 2 : 1 );
				if( debug )
					trace("Found solo value: "+v);
				soloValues.push(v);
				str = valueReg.matchedRight();
			}
			else
				break;
		}
	}

	/** Check if `arg` exists among arguments **/
	public inline function hasArg(arg:String) {
		if( arg==null || !ARG_REG.match(arg) )
			throw "Malformed arg: "+arg;
		return args.exists(arg);
	}

	/** Return the N-th `arg` following parameter, `null` if not found **/
	public inline function getArgParam(arg:String, paramIndex=0) : Null<String> {
		if( arg==null || !ARG_REG.match(arg) )
			throw "Malformed arg: "+arg;

		return args.exists(arg) ? args.get(arg)[paramIndex] : null;
	}

	/**
		Get specified solo value.

		A solo value isn't an arg (eg. "-v"), nor an arg parameter.
	**/
	public inline function getSoloValue(index:Int) : Null<String> {
		return soloValues[index];
	}

	/**
		Get 1st solo value, if any.

		A solo value isn't an arg (eg. "-v"), nor an arg parameter.
	**/
	public inline function getFirstSoloValue() : Null<String> {
		return soloValues[0];
	}

	/**
		Get last solo value, if any.

		A solo value isn't an arg (eg. "-v"), nor an arg parameter.
	**/
	public inline function getLastSoloValue() : Null<String> {
		return soloValues[ soloValues.length-1 ];
	}

	/**
		Get a copy of existing solo values.

		A solo value isn't an arg (eg. "-v"), nor an arg parameter.
	**/
	public inline function getAllSoloValues() return soloValues.copy();

	/**
		Return TRUE if any solo value exists

		A solo value isn't an arg (eg. "-v"), nor an arg parameter.
	**/
	public inline function hasAnySoloValue() return soloValues.length>0;


	@:keep
	public function toString() {
		var argsOut = [];
		for(a in args.keyValueIterator())
			argsOut.push(a.key + ( a.value.length>0 ? '(+${a.value.length})' : "" ));
		return 'Args: soloValues=[${soloValues.join(", ")}], args=[${argsOut.join(", ")}]';
	}



	#if deepnightLibsTests
	public static function test() {
		// Checks
		CiAssert.isTrue( new Args("-v=5").hasArg("-v") );
		CiAssert.isTrue( new Args("--v=5").hasArg("--v") );
		CiAssert.isTrue( new Args("-v=5 -i").hasArg("-i") );
		CiAssert.isTrue( new Args("-v=5 --i").hasArg("--i") );
		CiAssert.isFalse( new Args("-v=5 --i").hasArg("-i") );
		CiAssert.isTrue( new Args("-v=5 --i='some string'").hasArg("--i") );
		CiAssert.isTrue( new Args("-v=5 foo --some-var 'some string'").hasArg("--some-var") );

		// Solo values
		CiAssert.equals( new Args("-v=5 foo bar --some-var ").getSoloValue(0), "foo" );
		CiAssert.equals( new Args("-v=5 foo bar --some-var ").getSoloValue(1), "bar" );
		CiAssert.equals( new Args("-v=5 foo bar --some-var ").getSoloValue(2), null );
		CiAssert.equals( new Args('-v=5 foo "bar bar -a" --some-var ').getSoloValue(1), "bar bar -a" );
		CiAssert.equals( new Args("-v=5 foo 'bar bar -a' --some-var ").getSoloValue(1), "bar bar -a" );
		CiAssert.equals( new Args('-v=5 foo "bar bar" --some-var ').getSoloValue(2), null );
		CiAssert.equals( new Args('-v=5 foo bar --some-var').getFirstSoloValue(), "foo" );
		CiAssert.equals( new Args('-v=5 foo bar --some-var').getLastSoloValue(), "bar" );

		// Args with params
		CiAssert.equals( new Args("-v=5").getArgParam("-v"), "5" );
		CiAssert.equals( new Args("-v=5 -i").getArgParam("-i"), null );
		CiAssert.equals( new Args("-v 1 -i", [ "-v"=>2 ]).getArgParam("-v",1), null );
		CiAssert.equals( new Args("-v 1 -i", [ "-v"=>2 ]).hasArg("-i"), true );
		CiAssert.equals( new Args("-v 1 2 -i", [ "-v"=>2 ]).getArgParam("-v",0), "1" );
		CiAssert.equals( new Args("-v 1 2 -i", [ "-v"=>2 ]).getArgParam("-v",1), "2" );
		CiAssert.equals( new Args("-v=5 foo bar", [ "-v"=>2 ]).getSoloValue(0), "bar" );
		CiAssert.equals( new Args("-v:5 foo bar", [ "-v"=>2 ]).getArgParam("-v"), "5" );
	}
	#end
}