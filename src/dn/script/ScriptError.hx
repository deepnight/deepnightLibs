package dn.script;

class ScriptError extends haxe.Exception {
	public var line(default,null) = -1;
	public var scriptStr(default,null) : Null<String>;

	public function new(msg:String, ?scriptStr:String) {
		super( msg );
		this.scriptStr = scriptStr;
	}

	public static inline function fromHScriptError(err:hscript.Expr.Error, scriptStr:Null<String>) {
		#if hscriptPos
			var e = new ScriptError(err.toString(), scriptStr);
			e.line = err.line;
			return e;
		#else
			return new ScriptError(hscript.Printer.errorToString(err), scriptStr);
		#end
	}

	public static inline function fromGeneralException(err:haxe.Exception, scriptStr:Null<String>) {
		return new ScriptError(err.message, scriptStr);
	}

	@:keep override function toString() {
		return 'SCRIPT-ERROR: ${super.toString()}';
	}
}
