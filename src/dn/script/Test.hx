package dn.script;

// #if !deepnightLibsTests
// #error "Only available for lib testing"
// #end

class Test {
	public static function run() {
		var api = new Api();
		var r = new Runner();
		r.log = (str,?col)->{}
		r.throwErrors = true;
		r.exposeClassInstance("api", api, true);

		var script = "
			var x = 0;
			x++;
			x++;
			trace(x);
		";
		CiAssert.noException( "scriptChecking", r.check(script) );

		// Function calls
		CiAssert.equals( { Api.retValue=-1; r.run("reset();"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("api.ret(1);"); Api.retValue; },  1 );
		CiAssert.equals( { r.run("ret(1);"); Api.retValue; },  1 );
		CiAssert.equals( { r.run("ret( pow(2) );"); Api.retValue; },  4 );
		CiAssert.equals( { r.run("ret( api.pow(2) );"); Api.retValue; },  4 );

		// Output
		CiAssert.equals( { r.run(""); r.output; },  null );
		CiAssert.equals( { r.run(""); r.output_int; },  0 );
		CiAssert.equals( { r.run(""); r.output_float; },  0 );
		CiAssert.equals( { r.run(""); r.output_bool; },  false );
		CiAssert.equals( { r.run(""); r.output_str; },  null );

		CiAssert.equals( { r.run("var x=5; x;"); r.output_int; },  5 );
		CiAssert.equals( { r.run("var x=5; x++;"); r.output_int; },  5 );
		CiAssert.equals( { r.run("var x=5; ++x;"); r.output_int; },  6 );

		CiAssert.equals( { r.run("var x=5; x;"); r.output_float; },  5 );

		CiAssert.equals( { r.run("var x=true; x;"); r.output_bool; },  true );
		CiAssert.equals( { r.run("var x=5; x;"); r.output_bool; },  false);
		CiAssert.equals( { r.run("var x='hello'; x;"); r.output_bool; },  false);

		CiAssert.equals( { r.run("var x=5; x;"); r.output_str; },  "5" );
		CiAssert.equals( { r.run("var x=true; x;"); r.output_str; },  "true" );
		CiAssert.equals( { r.run("var x='hello'; x;"); r.output_str; },  "hello" );

		// Errors
		CiAssert.throwsException( "Unknown identifier 1", r.run("unknown();") );
		CiAssert.throwsException( "Unknown identifier 2", r.run("api.unknown();") );
		CiAssert.throwsException( "Invalid characters", r.run("var x=1; ù$^!ù;") );
		CiAssert.throwsException( "Incompatible types", r.run("var x=5; x='';") );
		CiAssert.throwsException( "Incompatible arg types", r.run("var x=pow('a');") );
		CiAssert.throwsException( "Undefined var", r.run("x=1") );
	}
}

@:rtti @:keep
private class Api {
	public static var retValue : Int;
	// JS BUG: for some reason, the script cant't acceess "this.retValue" when using the script "ret(1);".
	// It seems script scope isn't correct in JS.
	// For the tests to work, retValue must be static (no "this" access)

	public function new() {
		reset();
	}
	public function reset() retValue = 0;
	public function pow(v:Int) return v*v;
	public function ret(v:Int) retValue = v;
}
