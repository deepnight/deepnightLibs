package dn.heaps.assets;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
#end

class SfxDirectory {
	#if !macro
	public static var _CACHE : Map<String,hxd.res.Sound> = new Map();
	#end



	/**
		`resSubDir` should be a folder found inside Heaps res folder (defaults to `res/`). For example: `res/sfx`.
		If `useCache` is true, the Heaps resource loading method will only be called once per sound file. Every subsequent call will use a cached instance of the hxd.res.Sound.

		NOTE: if a sound file name is terminated by 0 or 1, the importer will try to lookup for a sequence of similar numbered files (eg. mySound1.wav, mySound2.wav etc.). If such a sequence is found, a `RandomSfxList` class will also be created in the returned structure, to allow for quick random sound picking among the detected serie (in the previous example, "mySound").

		USAGE:
		```haxe
		static var allSounds = SfxDirectory.load("res/sfx", true);
		allSounds.someSound(1); // play at 1.0 volume (ie. 100%)
		var s = allSounds.someSound(); // just return sound without playing it
		s.play(1);
		```
	**/
	macro public static function load( resSubDir:String, useCache:Bool ) {
		var pos = Context.currentPos();

		// Guess Heaps res dir
		var resDir = haxe.macro.Context.definedValue("resourcesPath");
		if( resDir==null )
			resDir = "res";

		// Check dir
		var dirFp = FilePath.fromDir( resSubDir.indexOf(resDir)!=0 ? resDir+"/"+resSubDir : resSubDir );
		if( !sys.FileSystem.exists(dirFp.full) || !sys.FileSystem.isDirectory(dirFp.full) )
			Context.fatalError("Folder "+dirFp.full+" is not valid! Make sure to provide a valid path inside Heaps res folder.", pos);

		var allCache = [];
		var randomSerieReg = ~/(.*?)([01])+(\.[a-z]+)$/gi;

		function addFilesFromDir(path:String) : Array<ObjectField> {
			var randomSeries : Map<String, { baseName:String, startIdx:Int, ext:String }> = new Map();
			var fields : Array<ObjectField> = [];
			for( fName in sys.FileSystem.readDirectory(path) ) {

				// Checks
				var fileFp = FilePath.fromFile(path+"/"+fName);
				if( sys.FileSystem.isDirectory(fileFp.full) ) {
					var subFields = addFilesFromDir(fileFp.full);
					fields.push({
						field: cleanUpIdentifier("_"+fName),
						expr: { pos:pos, expr:EObjectDecl(subFields) },
					});
					continue;
				}

				if( fileFp.extension==null )
					continue;

				var ext = fileFp.extension.toLowerCase();
				if( ext != "wav" && ext != "mp3" && ext != "ogg" )
					continue;


				// Detect possible random series
				if( randomSerieReg.match(fileFp.fileWithExt) ) {
					var baseName = randomSerieReg.matched(1);
					var startIdx = Std.parseInt( randomSerieReg.matched(2) );
					var ext = randomSerieReg.matched(3);

					if( !randomSeries.exists(baseName) )
						randomSeries.set(baseName, { startIdx:startIdx, baseName:baseName, ext:ext });
					else if( randomSeries.get(baseName).startIdx > startIdx )
						randomSeries.get(baseName).startIdx = startIdx;
				}

				// Init expressions
				var resRelPath = fileFp.clone().removeFirstDirectory().full;
				#if placeholderSfx
				resRelPath = Context.getDefines().get("placeholderSfx");
				#end
				var resSoundExpr = macro hxd.Res.load( $v{resRelPath} ).toSound();

				allCache.push(
					macro dn.heaps.assets.SfxDirectory._CACHE.set( $v{resRelPath} , $resSoundExpr )
				);

				// Create quickPlay method
				var f : haxe.macro.Function = {
					ret : null,
					args : [{name:"quickPlayVolume", opt:true, type:macro :Null<Float>, value:null}],
					expr : macro {

						// Instanciate hxd.res.Sound
						var snd = !$v{useCache}
							? $resSoundExpr
							: {
								// Cache
								if( !dn.heaps.assets.SfxDirectory._CACHE.exists( $v{resRelPath} ) )
									dn.heaps.assets.SfxDirectory._CACHE.set( $v{resRelPath} , $resSoundExpr );
								dn.heaps.assets.SfxDirectory._CACHE.get( $v{resRelPath} );
							}

						// Instanciate Sfx
						if( quickPlayVolume!=null ) {
							#if disableSfx
							return new dn.heaps.Sfx(snd);
							#else
							var s = new dn.heaps.Sfx(snd);
							return s.play(quickPlayVolume);
							#end
						}
						else
							return new dn.heaps.Sfx(snd);

					},
					params : [],
				}

				// Add field
				var fieldName = fName.substr(0, fName.length-4); // remove extension
				fieldName = cleanUpIdentifier(fieldName);
				var wrapperExpr : Expr = { pos:pos, expr:EFunction(FNamed(fieldName), f) }
				fields.push({ field:fieldName, expr:wrapperExpr });
			}

			// Create random-series getters if a follow-up in the supposed sequence exists
			for( r in randomSeries ) {
				var series = [];
				var idx = r.startIdx;
				var fp = FilePath.fromFile(path+"/" + r.baseName + idx + r.ext);
				while( sys.FileSystem.exists(fp.full) ) {
					fp.removeFirstDirectory();
					series.push(fp);
					idx++;
					fp = FilePath.fromFile(path+"/" + r.baseName + idx + r.ext);
				}

				// Found an actual series
				if( series.length>1 ) {
					#if placeholderSfx
					var phPath = Context.getDefines().get("placeholderSfx");
					var pathExprs : Array<Expr> = series.map( fp->macro $v{phPath} );
					#else
					var pathExprs : Array<Expr> = series.map( fp->macro $v{fp.full} );
					#end
					var arrExpr : Expr = { pos:pos, expr: EArrayDecl(pathExprs) }
					fields.push({
						field: r.baseName,
						expr: macro { new dn.heaps.Sfx.RandomSfxList( ${arrExpr} ); },
					});
				}
			}

			return fields;
		}

		var fields = addFilesFromDir(dirFp.full);

		if( fields.length==0 )
			Context.warning("No sound file found in "+dirFp.full, pos);

		// Add "pre-cache everything" method to fill initial cache
		if( useCache ) {
			fields.push({
				field: "_precacheAllSounds",
				expr: macro function() {
					$a{allCache}
				},
			});
		}

		var structExpr : Expr = { pos:pos, expr: EObjectDecl(fields) }
		return structExpr;
	}

	static var CLEANUP_REG = ~/[^A-Za-z0-9_]+/g;
	static var NON_LEADING_NUMBERS = ~/[0-9]+([a-z_])/gi;

	static inline function cleanUpIdentifier(i:String) {
		i = CLEANUP_REG.replace(i,"_");
		i = NON_LEADING_NUMBERS.replace(i, "$1");
		return i;
	}

}