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
				dn.CiAssert.print( $v{printCode(code)}+" == true... Ok");
			else {
				dn.CiAssert.print( $v{printCode(code)}+" == true ... FAILED!");
				dn.CiAssert.die();
			}
		};
	}

	public static macro function isFalse(code:Expr) {
		return macro {
			if( !${buildIsTrueExpr(code)} )
				dn.CiAssert.print( $v{printCode(code)}+" ... Ok");
			else {
				dn.CiAssert.print( $v{printCode(code)}+" == false ... FAILED!");
				dn.CiAssert.die();

			}
		};
	}

	public static macro function isNotNull(code:Expr) {
		return macro {
			if( ${buildIsNotNullExpr(code)} )
				dn.CiAssert.print( $v{printCode(code)}+" != null... Ok");
			else {
				dn.CiAssert.print( $v{printCode(code)}+" != null ... FAILED!");
				dn.CiAssert.die();
			}
		};
	}


	#if macro
	// Build expr of: "code==true"
	static function buildIsTrueExpr(code:Expr) {
		var eCheck : Expr = {
			expr: EBinop(OpEq, code, macro true),
			pos: Context.currentPos(),
		}

		// Does "code" actually returns a Bool?
		try Context.typeExpr(eCheck)
		catch(e:Dynamic) {
			Context.fatalError("Parameter should return a Bool value", code.pos);
		}

		return eCheck;
	}
	// Build expr of: "code==true"
	static function buildIsNotNullExpr(code:Expr) {
		var eCheck : Expr = {
			expr: EBinop(OpNotEq, code, macro null),
			pos: Context.currentPos(),
		}

		return eCheck;
	}

	// Print code expr in human-readable fashion
	static function printCode(code:Expr) : String {
		var printer = new haxe.macro.Printer();
		var codeStr = printer.printExpr(code);
		return "[" + Context.getLocalModule() + "] \"" + codeStr + "\"";
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
}