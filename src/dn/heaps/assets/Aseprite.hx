package dn.heaps.assets;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
#end

#if !heaps-aseprite
#error "Requires 'heaps-aseprite' lib"
#end

class Aseprite {
	static final leadingIdxReg = ~/([a-z0-9_]*?)(_*)([0-9]+)$/i;


	#if !macro
	public static function convertToSLib(fps:Int, aseRes:aseprite.Aseprite) {
		var slib = new dn.heaps.slib.SpriteLib([ aseRes.toTile() ]);

		// Parse all tags
		for(tag in aseRes.tags) {
			// Read and store frames
			var frames = aseRes.getTag(tag.name);
			if( frames.length==0 )
				continue;

			var baseIndex = frames[0].index;
			for(f in frames) {
				final t = f.tile;
				slib.sliceCustom(
					tag.name,0, f.index-baseIndex,
					t.ix, t.iy, t.iwidth, t.iheight,
					0,0, t.iwidth, t.iheight
				);
			}

			// Define animation from timeline
			var animFrames = [];
			for(f in frames) {
				var animFrameCount = dn.M.round( dn.M.fmax(1, $v{fps} * f.duration/1000) );
				for( i in 0...animFrameCount ) // HACK Spritelib anims are frame-based, which is bad :(
					animFrames.push(f.index-baseIndex);
			}
			slib.__defineAnim(tag.name, animFrames);
		}

		// Parse all slices
		for(slice in aseRes.slices) {
			var s = aseRes.getSlice(slice.name, 0);
			var t = s.tile;

			// Slice using original name
			slib.sliceCustom(
				slice.name,0, 0,
				t.ix, t.iy, t.iwidth, t.iheight,
				0,0, t.iwidth, t.iheight
			);

			// Slice using trimmed name (ie. without leading number)
			if( leadingIdxReg.match(slice.name) ) {
				slib.sliceCustom(
					leadingIdxReg.matched(1),0,  Std.parseInt(leadingIdxReg.matched(3)),
					t.ix, t.iy, t.iwidth, t.iheight,
					0,0, t.iwidth, t.iheight
				);
			}
		}

		return slib;
	}
	#end



	/**
		Generate a typed dictionnary containing all slice names found in given Aseprite file.

		The style of the generated dictionnary depends on `advancedDict` argument:

		- **FALSE** => generates an anonymous object like: `{  mySlice:"mySlice",  grass1:"grass1",  stoneBlock:"stoneBlock"  }`
		- **TRUE** => generates an `AsepriteDict` instance with various helper methods. In this case, you **must** initialize the dictionnary instance with a valid SpriteLib before using it: `myDict.initWithLib( mySpriteLib )`
	**/
	macro public static function getDict(asepriteRes:ExprOf<hxd.res.Resource>, advancedDict:Bool=false) {
		var path = dn.MacroTools.resolveResToPath(asepriteRes);
		return macro dn.heaps.assets.Aseprite.getDictFromFile($v{path}, $v{advancedDict});
	}



	/**
		Generate a typed dictionnary containing all slice names found in given Aseprite file.

		The style of the generated dictionnary depends on `advancedDict` argument. See `getDict()` for more info.
	**/
	macro public static function getDictFromFile(pathToAsepriteFile:ExprOf<String>, advancedDict:Bool=false) {
		var pos = Context.currentPos();
		var path = switch pathToAsepriteFile.expr {
			case EConst( CString(v) ): v;
			case _: Context.fatalError("Path should be a constant string", pathToAsepriteFile.pos);
		}

		// Try to find file in class paths if not found as-is
		if( !sys.FileSystem.exists(path) ) {
			path = dn.MacroTools.locateFileInClassPath(path);
			if( !sys.FileSystem.exists(path) )
				Context.fatalError("Aseprite file not found: "+path, pathToAsepriteFile.pos);
		}

		var keys : Array<String> = null;

		Context.registerModuleDependency(Context.getLocalModule(), path);

		// Check cache
		var mtime = Std.string( sys.FileSystem.stat(path).mtime.getTime() );
		var cacheRawPath = MacroTools.getResPath()+"/.tmp/aseprite_cache/"+cleanUpIdentifier(path);
		var cacheFp = FilePath.fromFile(cacheRawPath);
		if( sys.FileSystem.exists(cacheFp.full) ) {
			var rawCache = sys.io.File.getContent(cacheFp.full);
			var chk = rawCache.substr(0, rawCache.indexOf("\n"));
			if( chk==mtime ) {
				// Read keys from file cache
				keys = rawCache.split("\n");
				keys.shift();
			}
		}

		// Read Aseprite file (no cache)
		if( keys==null ) {
			var all:Map<String, Bool> = new Map(); // "Map" type avoids duplicates
			var ase = readAseprite(path);

			// List all slices
			final magicId = 0x2022;
			for (f in ase.frames) {
				if (!f.chunkTypes.exists(magicId))
					continue;
				var chunk:Array<ase.chunks.SliceChunk> = cast f.chunkTypes.get(magicId);
				for (s in chunk) {
					all.set(s.name, true);
					if( leadingIdxReg.match(s.name) && Std.parseInt(leadingIdxReg.matched(3))==0 )
						all.set( leadingIdxReg.matched(1), true );
				}
			}

			// List all tags
			final magicId = 0x2018;
			for (f in ase.frames) {
				if (!f.chunkTypes.exists(magicId))
					continue;

				var tags:Array<ase.chunks.TagsChunk> = cast f.chunkTypes.get(magicId);
				for (tc in tags)
					for (t in tc.tags)
						all.set(t.tagName, true);
			}

			// Create keys array
			keys = [];
			for(e in all.keys())
				keys.push( cleanUpIdentifier(e) );
		}

		// Cache keys
		sys.FileSystem.createDirectory(cacheFp.directory);
		sys.io.File.saveContent(cacheFp.full, mtime+"\n" + keys.join("\n"));


		if( !advancedDict ) {
			// Create anonymous structure fields
			var fields:Array<ObjectField> = [];
			for( k in keys )
				fields.push({  field:k,  expr:macro $v{k}  });
			return { expr: EObjectDecl(fields), pos: pos }
		}
		else {
			// Create an instance of AsepriteDict
			var rawMod = Context.getLocalModule();
			var modPack = rawMod.split(".");
			var modName = modPack.pop();

			// Class field initializers for the `initWithLib` method
			var initExprs : Array<Expr> = [];
			for(k in keys) {
				initExprs.push({
					pos: pos,
					expr: EBinop(OpAssign, {pos:pos, expr:EField(macro this, k)}, macro new dn.heaps.assets.Aseprite.AsepriteDictEntry(slib, $v{k})),
				});
			}

			// Create class definition
			var dictClass : TypeDefinition = {
				pos : pos,
				name : "AsepriteDict_"+FilePath.extractFileName(path),
				doc: "Dictionnary of "+FilePath.extractFileWithExt(path),
				pack : modPack,
				kind : TDClass(),
				fields : (macro class {
					public function new() {}

					public function initWithLib(slib:dn.heaps.slib.SpriteLib) {
						$a{initExprs}
					}
				}).fields,
			}

			// Populate class with entry fields
			for( k in keys )
				dictClass.fields.push({
					name: k,
					pos: pos,
					access: [APublic],
					kind: FVar(  macro : dn.heaps.assets.Aseprite.AsepriteDictEntry  ),
				});

			// Register class
			Context.defineModule(Context.getLocalModule(), [dictClass]);

			// Create constructor
			var typePath : TypePath = { pack:modPack, name:dictClass.name}
			return macro new $typePath();
		}
	}




  #if macro

	/**
		Cleanup a string to make a valid Haxe identifier
	**/
	static inline function cleanUpIdentifier(v:String) {
		return (~/[^a-z0-9_]/gi).replace(v, "_");
	}


	/**
		Parse Aseprite file from path
	**/
	static function readAseprite(filePath:String):ase.Ase {
		var pos = Context.currentPos();

		// Check file existence
		if (!sys.FileSystem.exists(filePath))
			filePath = try Context.resolvePath(filePath) catch (_) haxe.macro.Context.fatalError('File not found: $filePath', pos);

		// Create a dependency to break compilation cache if file changes
		Context.registerModuleDependency(Context.getLocalModule(), filePath);

		// Parse file
		var bytes = sys.io.File.getBytes(filePath);
		var ase = try ase.Ase.fromBytes(bytes) catch (err:Dynamic) Context.fatalError("Failed to read Aseprite file: " + err, pos);
		return ase;
	}

	#end

}



#if !macro
class AsepriteDict {}

class AsepriteDictEntry {
	var lib : dn.heaps.slib.SpriteLib;
	public var id(default,null) : String;
	public var frames(default,null) : Int;

	/** Allocate a new `h2d.Tile` **/
	public var tile(get,never) : h2d.Tile;
		inline function get_tile() return getTile();


	public function new(lib:dn.heaps.slib.SpriteLib, id:String) {
		this.lib = lib;
		this.id = id;
		frames = lib.countFrames(id);
	}

	@:keep public inline function toString() return id;

	/** Allocate a Tile **/
	public inline function getTile(frame=0, xr=0., yr=0.) : h2d.Tile {
		return lib.getTile(id, frame, xr,yr);
	}

	/** Allocate a random Tile **/
	public inline function getTileRandom(xr=0., yr=0.) : h2d.Tile {
		return lib.getTileRandom(id, xr,yr);
	}

	/** Allocate a HSprite **/
	public inline function getHsprite(frame=0, xr=0., yr=0.) : dn.heaps.slib.HSprite {
		return lib.h_get(id, frame, xr,yr);
	}

	/** Allocate a HSpriteBE **/
	public inline function getHspriteBE(sb:dn.heaps.slib.HSpriteBatch, frame=0, xr=0., yr=0.) : dn.heaps.slib.HSpriteBE {
		return lib.hbe_get(sb, id, frame, xr,yr);
	}

	/** Allocate a Bitmap **/
	public inline function getBitmap(frame=0, xr=0., yr=0., ?p:h2d.Object) : h2d.Bitmap {
		return new h2d.Bitmap( getTile(frame,xr,yr), p );
	}
}
#end