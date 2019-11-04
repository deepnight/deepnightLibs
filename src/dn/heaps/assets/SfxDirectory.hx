package dn.heaps.assets;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class SfxDirectory {

	macro public static function load( dir : String ) {
		var p = Context.currentPos();
		var sounds = [];
		var r_names = ~/[^A-Za-z0-9]+/g;
		var n = 0;
		var paths = Context.getClassPath();
		var custResDir = haxe.macro.Context.definedValue("resourcesPath");
		paths.push( (custResDir==null ? "res" : custResDir)+"/" );

		for( cp in paths ) {
			var path = cp+dir;
			if( !sys.FileSystem.exists(path) || !sys.FileSystem.isDirectory(path) )
				continue;

			for( fName in sys.FileSystem.readDirectory(path) ) {
				var ext = fName.split(".").pop().toLowerCase();
				if( ext != "wav" && ext != "mp3" && ext != "ogg" ) continue;

				n++;

				var fStr = { expr:EConst(CString(dir+"/"+fName)), pos:p }
				var newSoundExpr = macro hxd.Res.load($fStr).toSound();
				var newSfxExpr = 	macro new dn.heaps.Sfx($e{newSoundExpr});

				// Create field method
				var tfloat = macro : Null<Float>;
				var f : haxe.macro.Function = {
					ret : null,
					args : [{name:"quickPlayVolume", opt:true, type:tfloat, value:null}],
					expr : macro {
						if( quickPlayVolume!=null ) {
							#if disableSfx
							return $newSfxExpr;
							#else
							var s = $newSfxExpr;
							return s.play(quickPlayVolume);
							#end
						}
						else
							return $newSfxExpr;
					},
					params : [],
				}

				// Add field
				var fieldName = fName.substr(0, fName.length-4); // remove extension
				fieldName = r_names.replace(fieldName,"_"); // cleanup
				var wrapperExpr : Expr = { pos:p, expr:EFunction(FNamed(fieldName), f) }
				sounds.push({ field:fieldName, expr:wrapperExpr });
			}
			if( n>0 ) break;
		}

		if ( n==0 ) Context.error("Invalid directory (not found or empty): " + dir, p);

		return { pos : p, expr : EObjectDecl(sounds) };
	}

}