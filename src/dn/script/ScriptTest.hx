package dn.script;

// #if !deepnightLibsTests
// #error "Only available for lib testing"
// #end

class ScriptTest {
	public static function run() {
		var api = new Api();
		var r = new ScriptRunner();
		r.log = (str,?col)->{}
		r.setApiClass(api);

		CiAssert.equals( { r.run("reset();"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("api.ret(1);"); Api.retValue; },  1 );
		CiAssert.equals( { r.run("ret(1);"); Api.retValue; },  1 );
		CiAssert.equals( { r.run("ret( pow(2) );"); Api.retValue; },  4 );
		CiAssert.equals( { r.run("ret( api.pow(2) );"); Api.retValue; },  4 );

		// Errors
		CiAssert.equals( { r.run("unknown(); ret(1);"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("api.unknown(); ret(1);"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("ù$^!ù; ret(1);"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("var x=5; x=''; ret(1);"); Api.retValue; },  0 );
		CiAssert.equals( { r.run("var x=pow('a'); ret(1);"); Api.retValue; },  0 );
	}
}

@:rtti @:keep
private class Api implements IScriptRunnerApi {
	public static var retValue : Int;
	// JS BUG: for some reason, the script cant't acceess "this.retValue" when using the script "ret(1);".
	// It seems script scope isn't correct in JS.
	// For the tests to work, retValue must be static (no "this" access)

	public function new() {
		reset();
	}
	public function reset() { retValue = 0; }
	public function delay(cb,t) cb();
	public function isRunning() return true;
	public function update(tmod:Float) {}

	public function pow(v:Int) return v*v;
	public function ret(v:Int) retValue = v;
}
