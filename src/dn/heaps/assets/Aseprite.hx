package dn.heaps.assets;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
#end

#if !heaps-aseprite
#error "Requires haxelib heaps-aseprite"
#end

class Aseprite {
	/**
		Read Aseprite file and creates a dedicated SpriteLib class from it
	**/
	macro public static function convertToSLib(fps:Int, resPath:String) {
		var pos = haxe.macro.Context.currentPos();
		var rawMod = Context.getLocalModule();
		var modPack = rawMod.split(".");
		var modName = modPack.pop();

		// Check file existence
		var fullPath = resPath;
		if( !sys.FileSystem.exists(fullPath) )
			haxe.macro.Context.fatalError('File not found: $fullPath', pos);

		// Turn into "res" relative path
		var fp = FilePath.fromFile(resPath);
		if( fp.getFirstDirectory()=="res" )
			fp.removeFirstDirectory();
		var resPath = fp.full;


		// Parse file to list all tags
		var bytes = sys.io.File.getBytes(fullPath);
		var ase = ase.Ase.fromBytes(bytes);
		var allTags = [];
		final tagMagic = 0x2018;
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(tagMagic) )
				continue;
			var tags : Array<ase.chunks.TagsChunk> = cast f.chunkTypes.get(tagMagic);
			for( tc in tags )
				for(t in tc.tags)
					allTags.push(t.tagName);
		}


		// Create specific SpriteLib class
		var className = ( ~/([^0-9a-z])/gi ).replace( FilePath.fromFile(fullPath).fileName, "_" );
		var parentTypePath : TypePath = { pack:["dn","heaps","slib"], name:"SpriteLib" }
		var aseResExpr = macro hxd.Res.load( $v{resPath} ).to( aseprite.Aseprite );
		var classType : TypeDefinition = {
			pos : pos,
			name : "SpriteLib_"+className,
			pack : modPack,
			kind : TDClass(parentTypePath),
			fields : (macro class {

				override public function new() {
					// Init parent SpriteLib
					var aseRes = $aseResExpr;
					var tile = aseRes.toTile();
					super([tile]);

					// Parse all tags
					for(tag in aseRes.tags) {
						// Read and store frames
						var frames = aseRes.getTag(tag.name);
						if( frames.length==0 )
							continue;

						var baseIndex = frames[0].index;
						for(f in frames) {
							final t = f.tile;
							sliceCustom(
								tag.name,0, f.index-baseIndex,
								t.ix, t.iy, t.iwidth, t.iheight,
								0,0, t.iwidth, t.iheight
							);
						}

						// Define animation
						var animFrames = [];
						for(f in frames) {
							var animFrameCount = dn.M.round( dn.M.fmax(1, $v{fps} * f.duration/1000) );
							for( i in 0...animFrameCount ) // HACK Spritelib anims are frame-based, which is bad :(
								animFrames.push(f.index-baseIndex);
						}
						__defineAnim(tag.name, animFrames);
					}

				}
			}).fields,
		}


		// Build tags dictionary in class
		var dictInits : Array<ObjectField> = [];
		for( t in allTags )
			dictInits.push({
				field: t,
				expr: macro $v{t},
			});

		classType.fields.push({
			name: "all",
			pos: pos,
			access: [ APublic ],
			kind: FVar(null, { expr:EObjectDecl(dictInits), pos:pos }),
		});


		// Register class
		Context.defineModule(rawMod, [classType]);

		// Create SpriteLib instance
		var classPath : TypePath = { pack:classType.pack, name:classType.name }
		return macro new $classPath();
	}
}