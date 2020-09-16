package dn;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.TypeTools;
#end

class CiAssert {
	public static macro function isTrue(code:Expr) {
		return macro {
			if( ${buildIsTrueExpr(code)} )
				dn.CiAssert.printOk( $v{printCode(code)} );
			else {
				dn.CiAssert.printFailure( $v{printCode(code)}, "This expression should be TRUE");
				dn.CiAssert.die();
			}
		};
	}

	public static macro function isFalse(code:Expr) {
		return macro {
			if( !${buildIsTrueExpr(code)} )
				dn.CiAssert.printOk( $v{printCode(code)} );
			else {
				dn.CiAssert.printFailure( $v{printCode(code)}, "This expression should be FALSE");
				dn.CiAssert.die();

			}
		};
	}

	public static macro function noException(desc:String, code:Expr) {
		return macro {
			try {
				$code;
				dn.CiAssert.printOk($v{printWithPrefix(desc)} );
			}
			catch(e:Dynamic) {
				dn.CiAssert.printFailure( $v{printWithPrefix(desc)}, "This expression should thrown NO exception (caught \""+e+"\")");
				dn.CiAssert.die();
			}
		};
	}

	public static macro function isNotNull(code:Expr) {
		return macro {
			if( ($code) != null )
				dn.CiAssert.printOk( $v{printCode(code)} );
			else {
				dn.CiAssert.printFailure( $v{printCode(code)}, "This expression should NOT be NULL");
				dn.CiAssert.die();
			}
		};
	}


	#if macro
	// Build expr of: "code==true"
	static function buildIsTrueExpr(code:Expr) : Expr {
		var eCheck : Expr = {
			expr: EBinop(OpEq, code, macro true),
			pos: Context.currentPos(),
		}

		// Does "code" actually returns a Bool?
		try Context.typeExpr(eCheck)
		catch(err:Dynamic) {
			Context.fatalError('$err (this assertion should return a Bool)', code.pos);
		}

		return eCheck;
	}

	// Print code expr in human-readable fashion
	static function printCode(code:Expr) : String {
		var printer = new haxe.macro.Printer();
		var codeStr = printer.printExpr(code);
		if( codeStr.length>=90 )
			codeStr = codeStr.substr(0,10)+"... ..."+codeStr.substr(-80);

		var build = Context.defined("js") ? "JS"
			: Context.defined("hl") ? "HL"
			: Context.defined("neko") ? "Neko"
			: "Unknown";
		return '[$build|${Context.getLocalModule()}] $codeStr';
	}

	static function printWithPrefix(str:String) : String {
		var build = Context.defined("js") ? "JS"
			: Context.defined("hl") ? "HL"
			: Context.defined("neko") ? "Neko"
			: "Unknown";

		return '[$build|${Context.getLocalModule()}] "$str"';
	}
	#end


	@:noCompletion
	public static function die() {
		print("Stopped.");
		print("");

		#if js
		throw new js.lib.Error("Failed");
		#else
		Sys.exit(1);
		#end
	}

	@:noCompletion
	public static function print(v:Dynamic) {
		#if js
		js.html.Console.log( Std.string(v) );
		#else
		Sys.println( Std.string(v) );
		#end
	}

	@:noCompletion
	public static inline function printOk(v:Dynamic) {
		print(Std.string(v)+"  <Ok>");
	}

	@:noCompletion
	public static inline function printFailure(v:Dynamic, reason:String) {
		var v = Std.string(v);
		var sep = [ for(i in 0...v.length+11) "*" ];

		print(sep.join(""));
		print(v+"  <FAILED!>");
		print("ERROR: "+reason);
		print(sep.join(""));
	}
}