package dn.script.tests;

// #if !deepnightLibsTests
// #error "Only available for lib testing"
// #end

class RunnerTests {
	public static function run() {
		var api = new Api();
		var r = new Runner();
		r.log = (str,?col)->{}
		r.rethrowErrors = true;
		r.exposeClassInstance(api, "api", PublicFields);

		var script = "
			var x = 0;
			x++;
			x++;
			trace(x);
		";

		// Check
		CiAssert.noException( "scriptChecking", r.check(script) );
		CiAssert.equals( r.check(script), true );

		// Errors
		CiAssert.throwsException( "Unknown identifier (variable)", r.run("x=1;") );
		CiAssert.throwsException( "Unknown identifier (function)", r.run("unknown();") );
		CiAssert.throwsException( "Unknown identifier (api call)", r.run("api.unknown();") );
		CiAssert.throwsException( "Invalid characters", r.run("var x=1; ù$^!ù;") );
		CiAssert.throwsException( "Incompatible types", r.run("var x=5; x='';") );
		CiAssert.throwsException( "Incompatible arg types", r.run("var x=pow2('a');") );
		CiAssert.throwsException( "Undefined var", r.run("x=1") );

		r.rethrowErrors = false;

		// API calls
		CiAssert.equals( { r.run("var x=pow2(5); x;"); r.output_int; },  25 );
		CiAssert.equals( { r.run("var x=pow2(1.5); x;"); r.output_int; },  2 );
		CiAssert.equals( { r.run("var x=pow2(1.5); x;"); r.output_float; },  2.25 );
		CiAssert.equals( { r.run("var x=inc(1); x;"); r.output_int; },  2 );
		CiAssert.equals( { r.run("var x=1; inc(x); x;"); r.output_int; },  1 );


		// Output: Dynamic
		CiAssert.equals( { r.run(""); r.output; },  null );
		CiAssert.equals( { r.run("null;"); r.output; },  null );
		CiAssert.equals( { r.run("5"); r.output; },  5 );
		CiAssert.equals( { r.run("5.3"); r.output; },  5.3 );
		CiAssert.equals( { r.run("true"); r.output; },  true );
		CiAssert.equals( { r.run("var x=5; x=''; x;"); r.output; },  null );
		CiAssert.equals( { r.run("unknown_var;"); r.output; },  null );

		// Output: Int
		CiAssert.equals( { r.run(""); r.output_int; },  0 );
		CiAssert.equals( { r.run("var x=5; x;"); r.output_int; },  5 );
		CiAssert.equals( { r.run("var x=5; x++;"); r.output_int; },  5 );
		CiAssert.equals( { r.run("var x=5; ++x;"); r.output_int; },  6 );
		CiAssert.equals( { r.run("1.9;"); r.output_int; },  1 );
		CiAssert.equals( { r.run("-1.9;"); r.output_int; },  -1 );
		CiAssert.equals( { r.run("null;"); r.output_int; },  0 );
		CiAssert.equals( { r.run("1/0;"); r.output_int; },  0 );
		CiAssert.equals( { r.run("'hello';"); r.output_int; },  0 );

		// Output: Float
		CiAssert.equals( { r.run(""); r.output_float; },  0 );
		CiAssert.equals( { r.run("var x=5.2; x;"); r.output_float; },  5.2 );
		CiAssert.equals( { r.run("null;"); r.output_float; },  0. );
		CiAssert.equals( { r.run("1/0;"); r.output_float; },  0. );
		CiAssert.equals( { r.run("'hello';"); r.output_float; },  0. );

		// Output: Bool
		CiAssert.equals( { r.run(""); r.output_bool; },  false );
		CiAssert.equals( { r.run("var x=true; x;"); r.output_bool; },  true );
		CiAssert.equals( { r.run("var x=5; x;"); r.output_bool; },  false);
		CiAssert.equals( { r.run("var x='hello'; x;"); r.output_bool; },  false);
		CiAssert.equals( { r.run("null;"); r.output_bool; },  false );
		CiAssert.equals( { r.run("5;"); r.output_bool; },  false );
		CiAssert.equals( { r.run("'hello';"); r.output_bool; },  false );

		// Output: String
		CiAssert.equals( { r.run(""); r.output_str; },  null );
		CiAssert.equals( { r.run("var x=5; x;"); r.output_str; },  "5" );
		CiAssert.equals( { r.run("var x=true; x;"); r.output_str; },  "true" );
		CiAssert.equals( { r.run("var x='hello'; x;"); r.output_str; },  "hello" );
		CiAssert.equals( { r.run("null;"); r.output_str; },  null );
	}
}

@:rtti @:keep
private class Api {
	public function new() {}

	public function pow2(v:Float) return v*v;
	public function inc(v:Float) return v+1;
}
