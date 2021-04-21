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
			var animFrames = [];
			for(f in frames) {
				var animFrameCount = dn.M.round( dn.M.fmax(1, $v{fps} * f.duration/1000) );
				for( i in 0...animFrameCount ) // HACK Spritelib anims are frame-based, which is bad :(
					animFrames.push(f.index-baseIndex);
			}
			slib.__defineAnim(tag.name, animFrames);
		}

		return slib;
	}
	#end


	/**
		Build an anonymous object containing all "tags" and "slices" found in given Aseprite file. Example:
		```haxe
			var dict = Aseprite.extractDictionary("assets/myCharacter.aseprite");
			// ...will look like:
			{
				_slices: { mySlice:"mySlice" }, // all your slices
				_tags: { run:"run", idle:"idle" }, // all your tags
				run:"run", idle:"idle", mySlice:"mySlice" // everything mixed
			}
		```
	**/
	macro public static function extractDictionary(asepritePath:String) {
		var pos = Context.currentPos();

		// Check file existence
		if( !sys.FileSystem.exists(asepritePath) )
			haxe.macro.Context.fatalError('File not found: $asepritePath', pos);

		// Break cache if file changes
		Context.registerModuleDependency(Context.getLocalModule(), asepritePath);

		// Parse file
		var bytes = sys.io.File.getBytes(asepritePath);
		var ase = ase.Ase.fromBytes(bytes);

		inline function cleanUpIdentifier(v:String) {
			return ( ~/[^a-z0-9_]/gi ).replace(v, "_");
		}

		// List all tags
		var allTags : Map<String,Bool> = new Map();
		final magicId = 0x2018;
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(magicId) )
				continue;
			var tags : Array<ase.chunks.TagsChunk> = cast f.chunkTypes.get(magicId);
			for( tc in tags )
				for(t in tc.tags)
					allTags.set(t.tagName, true);
		}

		// List all slices
		var allSlices : Map<String,Bool> = new Map();
		final magicId = 0x2022;
		for(f in ase.frames) {
			if( !f.chunkTypes.exists(magicId) )
				continue;
			var slices : Array<ase.chunks.SliceChunk> = cast f.chunkTypes.get(magicId);
			for(s in slices)
				allSlices.set(s.name, true);
		}


		var done = new Map(); // avoid duplicates
		var aggregatedFields : Array<ObjectField> = []; // contains both tags & slices

		// Create "tags" anonymous structure
		var tagFields : Array<ObjectField> = [];
		for( tag in allTags.keys() ) {
			if( !done.exists(tag) ) {
				done.set(tag,true);
				aggregatedFields.push({ field: cleanUpIdentifier(tag),  expr: macro $v{tag} });
			}
			tagFields.push({ field: cleanUpIdentifier(tag),  expr: macro $v{tag} });
		}
		aggregatedFields.push({ field:"_tags", expr: { expr:EObjectDecl(tagFields), pos:pos } });

		// Create "slices" anonymous structure
		var sliceFields : Array<ObjectField> = [];
		for( slice in allSlices.keys() ) {
			if( !done.exists(slice) ) {
				done.set(slice,true);
				aggregatedFields.push({ field: cleanUpIdentifier(slice),  expr: macro $v{slice} });
			}
			sliceFields.push({ field: cleanUpIdentifier(slice),  expr: macro $v{slice} });
		}
		aggregatedFields.push({ field:"_slices", expr: { expr:EObjectDecl(sliceFields), pos:pos } });

		// Return anonymous structure
		return { expr:EObjectDecl(aggregatedFields), pos:pos }
	}

}