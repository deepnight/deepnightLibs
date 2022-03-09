package dn;

import haxe.macro.Expr;
import haxe.macro.Context;

class MacroTools {
	public static macro function error(err:ExprOf<String>) {
		var pos = haxe.macro.Context.currentPos();
		switch( err.expr ) {
			case EConst(CString(s)) : Context.error(s, pos);
			default :
		}

		return {pos:pos, expr:EBlock([])}
	}

	public static macro function getBuild(pathToBuildFile:ExprOf<String>, preIncrement:ExprOf<Bool>) {
		var pos = Context.currentPos();
		var path = switch( pathToBuildFile.expr ) {
			case EConst(CString(s)) : s;
			default : Context.error("Constant expected here", pathToBuildFile.pos);
		}
		var inc = switch( preIncrement.expr ) {
			case EConst(CIdent(v)) : v=="true";
			default : false;
		}

		try {
			path = try Context.resolvePath(path) catch(e:Dynamic) { Context.error("Build file not found: "+path, pathToBuildFile.pos); }
			var v = sys.io.File.getContent(path);
			if( inc ) {
				v = Std.string( Std.parseInt(v)+1 );
				sys.io.File.saveContent(path, v);
			}
			return {pos:pos, expr:EConst(CInt( v ))}
		}
		catch(e:Dynamic) {
			Context.error("Couldn't read build file: "+path, pathToBuildFile.pos);
			return {pos:pos, expr:EConst(CInt("-1"))}
		}
	}


	@:deprecated("Use getRawBuildDate() or getHumanBuildDate()") @:noCompletion
	public static macro function getBuildDate() {
		return { pos:Context.currentPos(), expr:EConst( CString( Date.now().toString() ) ) }
	}

	/**
		Return the compilation timestamp in seconds as standard Date string format
	**/
	public static macro function getBuildTimeStampSeconds() {
		return {
			pos : Context.currentPos(),
			expr : EConst(CFloat( Std.string(  haxe.Timer.stamp()  ) )),
		}
	}

	/**
		Return the compilation date as standard Date string format
	**/
	public static macro function getRawBuildDate() {
		return { pos:Context.currentPos(), expr:EConst( CString( Date.now().toString() ) ) }
	}

	/**
		Return a version String containing various info about current build: platform, steam, debug, 32/64bits etc.
		Example: "2021-10-01-21-39-53--hldx-steam-debug-64"
	**/
	public static macro function getBuildInfo(?separator:ExprOf<String>) {
		var sep = switch separator.expr {
			case null, EConst(CIdent("null")) : "-";
			case EConst(CString(s, _)): s;
			case _: Context.fatalError("Unexpected value "+separator.expr, separator.pos);
		}

		var parts = [ (~/[^a-z0-9]/gi).replace( Date.now().toString(), sep ) ];
		parts.push("");
		if( Context.defined("js") ) parts.push("js");
		if( Context.defined("neko") ) parts.push("neko");

		if( Context.defined("hldx") ) parts.push("hldx");
		else if( Context.defined("hlsdl") ) parts.push("hlsdl");
		else if( Context.defined("hl") ) parts.push("hl");

		if( Context.defined("hlsteam") ) parts.push("steam");
		if( Context.defined("debug") ) parts.push("debug");

		var base : Expr = {
			pos: Context.currentPos(),
			expr: EConst( CString(parts.join(sep)) ),
		}
		if( Context.defined("hl") ) {
			return macro $base + ( hl.Api.is64() ? $v{sep}+"64" : $v{sep}+"32 ");
		}
		else
			return base;
	}

	/** Return the compilation date as a human-readable format: "Month XXth (HH:MM)" **/
	public static macro function getHumanBuildDate() {
		var d = Date.now();
		var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
		var str = months[ d.getMonth() ] + DateTools.format(d, " %d (%H:%M)");
		return { pos:Context.currentPos(), expr:EConst(CString(str)) }
	}


	public static macro function forceClasspathInclude(cp:Array<String>) {
		for(p in cp)
			haxe.macro.Compiler.include(p);
		return macro {}
	}



	#if macro

	/**
		Return relative path to the `res` folder of Heaps
	**/
	public static function getResPath() {
		var resPath = Context.definedValue("resourcesPath");
		if( resPath==null )
			resPath = "res";
		if( !sys.FileSystem.exists(resPath) )
			Context.fatalError("Res dir not found: "+resPath, Context.currentPos());
		return resPath;
	}

	/**
	Try to resolve a `hxd.Res` expression (eg. hxd.Res.dir.myFile) to an actual file path (eg. "res/dir/myFile.aseprite").
	The approach is a bit dirty but it should work in 99% non-exotic cases.
	**/
	public static function resolveResToPath(resExpr:Expr) : Null<String> {
		switch resExpr.expr {
			case EField(_):
			case _:
			Context.fatalError("Expected Resource identifier (eg. hxd.Res.myResource)", resExpr.pos);
		}

		// Turn Res expression to a string (eg. "hxd.Res.dir.myFile")
		var idents = new haxe.macro.Printer("").printExpr( resExpr ).split(".");
		if( idents[0]=="hxd" )
			idents.shift(); // remove hxd package
		if( idents.length==0 || !( ~/^_*[A-Z]/g ).match(idents[0]) )
			Context.fatalError("Expected Resource identifier (eg. hxd.Res.myResource)", resExpr.pos);
		idents.shift(); // remove Res class, whatever it is called
		if( idents.length==0 )
			Context.fatalError("Expected Resource identifier (eg. hxd.Res.myResource)", resExpr.pos);

		// Guess "res" dir
		var resPath = Context.definedValue("resourcesPath");
		if( resPath==null )
			resPath = "res";
		if( !sys.FileSystem.exists(resPath) )
			Context.fatalError("Res dir not found: "+resPath, Context.currentPos());

		// Look for file
		for(ext in [ "ase", "aseprite" ]) {
			var path = resPath+"/"+idents.join("/")+"."+ext;
			if( sys.FileSystem.exists(path) )
				return path;
		}

		// If everything fails, check if Res ident was renamed due to duplicate names
		var path = resPath+"/"+idents.join("/");
		var extensionReg = ~/(.+)_([a-z0-9]*)$/gi;
		extensionReg.replace(path,"$1.$2");
		if( sys.FileSystem.exists(path) )
			return path;

		Context.fatalError("Couldn't locate file for resource: "+idents.join("."), resExpr.pos);
		return null;
	}

	#end
}
