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
		Build an anonymous object containing all "slices" names found in given Aseprite file.
		Example: `{  mySlice:"mySlice",  grass1:"grass1",  stoneBlock:"stoneBlock"  }`
	**/
	macro public static function getDict(asepriteRes:ExprOf<hxd.res.Resource>) {
		var path = dn.MacroTools.resolveResToPath(asepriteRes);
		return macro dn.heaps.assets.Aseprite.getDictFromFile($v{path});
	}



	/**
		Build an anonymous object containing all "slices" names found in given Aseprite file.
		Example: `{  mySlice:"mySlice",  grass1:"grass1",  stoneBlock:"stoneBlock"  }`
	**/
	macro public static function getDictFromFile(pathToAsepriteFile:ExprOf<String>) {
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


		// Create anonymous structure fields
		var fields:Array<ObjectField> = [];
		for( k in keys )
			fields.push({  field:k,  expr:macro $v{k}  });
		return { expr: EObjectDecl(fields), pos: pos }
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