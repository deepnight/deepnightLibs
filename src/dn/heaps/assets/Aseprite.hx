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
				trace("slice "+tag.name+": "+t.ix+","+t.iy);
				slib.sliceCustom(
					tag.name,0, f.index-baseIndex,
					t.ix, t.iy, t.iwidth, t.iheight,
					0,0, t.iwidth, t.iheight
				);
			}

			// Define animation
			if( frames.length>1 ) {
				var animFrames = [];
				for(f in frames) {
					var animFrameCount = dn.M.round( dn.M.fmax(1, $v{fps} * f.duration/1000) );
					for( i in 0...animFrameCount ) // HACK Spritelib anims are frame-based, which is bad :(
						animFrames.push(f.index-baseIndex);
				}
				slib.__defineAnim(tag.name, animFrames);
			}
		}

		return slib;
	}
	#end


	/**
		Build an anonymous object containing all unique "tags" found in given Aseprite file. Example:
		```haxe
			var allAnims = Aseprite.extractDictionary("assets/myCharacter.aseprite");
			// ...will look like:
			{ run:"run", idle:"idle", attackA:"attackA" }
		```
	**/
	macro public static function extractDictionary(asepritePath:String) {
		var pos = Context.currentPos();

		// Check file existence
		if( !sys.FileSystem.exists(asepritePath) )
			haxe.macro.Context.fatalError('File not found: $asepritePath', pos);

		// Parse file to list all tags
		var bytes = sys.io.File.getBytes(asepritePath);
		var ase = ase.Ase.fromBytes(bytes);
		var allTags : Map<String,Bool> = new Map();
		final tagMagic = 0x2018;
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(tagMagic) )
				continue;
			var tags : Array<ase.chunks.TagsChunk> = cast f.chunkTypes.get(tagMagic);
			for( tc in tags )
				for(t in tc.tags)
					allTags.set(t.tagName, true);
		}

		// Create anonymous object
		var dictInits : Array<ObjectField> = [];
		for( tag in allTags.keys() )
			dictInits.push({ field: tag,  expr: macro $v{tag} });

		return { expr:EObjectDecl(dictInits), pos:pos }
	}
}