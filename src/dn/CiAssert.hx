package dn;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.TypeTools;
#end

class CiAssert {
	/** If FALSE, only errors are printed **/
	public static var VERBOSE = false;

	public static macro function isTrue(code:Expr) {
		return macro {
			if( ${buildIsTrueExpr(code)} )
				dn.CiAssert.printOk( $v{getCodeStr(code)} );
			else
				dn.CiAssert.fail( $v{getFilePos()}, $v{getCodeStr(code)}, "This expression should be TRUE");
		};
	}

	public static macro function equals(codeA:Expr, codeB:Expr) {
		var eCheck : Expr = {
			expr: EBinop(OpEq, codeA, codeB),
			pos: Context.currentPos(),
		}

		return macro {
			if( $eCheck )
				dn.CiAssert.printOk( $v{getCodeStr(eCheck)} );
			else {
				dn.CiAssert.fail(
					$v{getFilePos()},
					$v{getCodeStr(eCheck)},
					"These 2 expressions should be EQUAL",
					[ $codeA+" != "+$codeB ]
				);
			}
		};
	}

	public static macro function isFalse(code:Expr) {
		return macro {
			if( !${buildIsTrueExpr(code)} )
				dn.CiAssert.printOk( $v{getCodeStr(code)} );
			else
				dn.CiAssert.fail( $v{getFilePos()}, $v{getCodeStr(code)}, "This expression should be FALSE");
		};
	}

	public static macro function noException(desc:String, code:Expr) {
		return macro {
			try {
				$code;
				dn.CiAssert.printOk($v{getDescWithPrefix(desc)} );
			}
			catch(e:Dynamic) {
				dn.CiAssert.fail( $v{getFilePos()}, $v{getDescWithPrefix(desc)}, "This expression should thrown NO exception (caught \""+e+"\")");
			}
		};
	}
	public static macro function throwsException(desc:String, code:Expr) {
		return macro {
			var thrown = false;
			try {
				$code;
			}
			catch(e:Dynamic) {
				thrown = true;
			}

			if( thrown )
				dn.CiAssert.printOk($v{getDescWithPrefix(desc)} );
			else
				dn.CiAssert.fail( $v{getFilePos()}, $v{getDescWithPrefix(desc)}, "This expression should throw an exception" );
		};
	}

	public static macro function isNotNull(code:Expr) {
		return macro {
			if( ($code) != null )
				dn.CiAssert.printOk( $v{getCodeStr(code)} );
			else
				dn.CiAssert.fail( $v{getFilePos()}, $v{getCodeStr(code)}, "This expression should NOT be NULL");
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
	static function getCodeStr(code:Expr, prefix=true) : String {
		var printer = new haxe.macro.Printer();
		var codeStr = printer.printExpr(code);
		codeStr = StringTools.replace(codeStr,"\n","");
		codeStr = StringTools.replace(codeStr,"\t"," ");
		if( codeStr.length>=90 )
			codeStr = codeStr.substr(0,10)+"... ..."+codeStr.substr(-80);

		var build = Context.defined("js") ? "JS"
			: Context.defined("hl") ? "HL"
			: Context.defined("neko") ? "Neko"
			: "Unknown";

		return prefix
			? '[$build|${Context.getLocalModule()}] $codeStr'
			: codeStr;
	}

	static function getDescWithPrefix(str:String) : String {
		var build = Context.defined("js") ? "JS"
			: Context.defined("hl") ? "HL"
			: Context.defined("neko") ? "Neko"
			: "Unknown";

		return '[$build|${Context.getLocalModule()}] "$str"';
	}
	#end

	#if macro
	static function getFilePos() {
		var pos = Context.getPosInfos( Context.currentPos() );
		var fi = sys.io.File.read(pos.file);
		var line = fi.readString(pos.min).split("\n").length;
		fi.close();
		return { file:pos.file, line:line }
	}
	#end

	@:noCompletion
	public static inline function printOk(v:Dynamic) {
		if( VERBOSE )
			Lib.println(Std.string(v)+"  <Ok>");
	}

	public static inline function printIfVerbose(v:Dynamic) {
		if( VERBOSE )
			Lib.println(v);
	}

	@:noCompletion
	public static function fail(filePos:{file:String, line:Int}, desc:String, reason:String, ?extraInfos:Array<String>) {
		var desc = Std.string(desc);
		var sep = [ for(i in 0...desc.length+11) "*" ];

		Lib.println(sep.join(""));
		Lib.println(desc+"  <FAILED!>");
		if( extraInfos!=null )
			for( str in extraInfos )
				Lib.println("\t"+str);
		Lib.println("ERROR: "+reason);
		Lib.println(sep.join(""));

		// Stop
		#if js
		throw new js.lib.Error('Failed in ${filePos.file}');
		#elseif flash
		throw reason;
		#else
		Sys.stderr().writeString('${filePos.file}:${filePos.line}: characters 1-999 : $reason\n');
		Sys.exit(1);
		#end
	}
}