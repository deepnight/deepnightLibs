package dn.script;

private enum ErrorContext {
	Parse;
	Check;
	Execution;
}

class ScriptError extends haxe.Exception {
	public var context : ErrorContext;
	public var line(default,null) = -1;
	public var scriptStr(default,null) : Null<String>;

	public function new(ctx:ErrorContext, msg:String, ?scriptStr:String) {
		super( msg );
		context = ctx;
		this.scriptStr = scriptStr;
	}

	public static inline function fromHScriptError(ctx:ErrorContext, err:hscript.Expr.Error, scriptStr:Null<String>) {
		#if hscriptPos
		var e = new ScriptError(ctx, err.toString(), scriptStr);
		e.line = err.line;
		#else
		var e = new ScriptError(ctx, Std.string(err), scriptStr);
		#end
		throw e;
	}

	@:keep override function toString() {
		return 'ERROR [$context]: ${super.toString()}';
	}
}
