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
	public static function println(v:Dynamic) {
		#if js
		js.html.Console.log( Std.string(v) );
		#else
		Sys.println( Std.string(v) );
		#end
	}

	@:noCompletion
	public static inline function printOk(v:Dynamic) {
		println(Std.string(v)+"  <Ok>");
	}

	@:noCompletion
	public static function fail(filePos:{file:String, line:Int}, desc:String, reason:String, ?extraInfos:Array<String>) {
		var desc = Std.string(desc);
		var sep = [ for(i in 0...desc.length+11) "*" ];

		println(sep.join(""));
		println(desc+"  <FAILED!>");
		if( extraInfos!=null )
			for( str in extraInfos )
				println("\t"+str);
		println("ERROR: "+reason);
		println(sep.join(""));

		// Stop
		#if js
		throw new js.lib.Error('Failed in ${filePos.file}');
		#else
		Sys.stderr().writeString('${filePos.file}:${filePos.line}: characters 1-999 : $reason\n');
		Sys.exit(1);
		#end
	}
}