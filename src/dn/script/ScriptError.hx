package dn.script;

class ScriptError extends haxe.Exception {
	public var line(default,null) = -1;
	public var scriptStr(default,null) : Null<String>;

	public function new(msg:String, ?previous:haxe.Exception, ?scriptStr:String) {
		super(msg, previous);
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

	public inline function overrideLine(line:Int) {
		this.line = line;
	}

	public static inline function fromGeneralException(err:haxe.Exception, scriptStr:Null<String>) {
		return new ScriptError(err.message, err, scriptStr);
	}

	@:keep public function getErrorOnly() {
		var reg = ~/:[0-9]+:(.*)/i;
		var err = toString();
		if( reg.match(err) )
			return reg.matched(1);
		else if( err.indexOf(":")>0 )
			return err.substring( err.indexOf(":")+1 );
		else
			return err;
	}

	@:keep override function toString() {
		return 'SCRIPT-ERROR: ${super.toString()}';
	}
}
