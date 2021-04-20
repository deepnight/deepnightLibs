package dn.heaps.assets;

#if !heaps-aseprite
#error "Requires haxelib heaps-aseprite"
#end

class Aseprite {
	/**
		Convert an Aseprite file (provided by heaps-aseprite lib) to a SpriteLib instance.
	**/
	public static function convertToSLib(fps:Int, ase:aseprite.Aseprite) : dn.heaps.slib.SpriteLib {
		var slib = new dn.heaps.slib.SpriteLib([ ase.toTile() ]);
		for(tag in ase.tags) {
			// Read and store frames
			var frames = ase.getTag(tag.name);
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

			// Define animation
			var animFrames = [];
			for(f in frames)
			for( i in 0...M.round(M.fmax(1, fps*f.duration/1000)) )
				animFrames.push(f.index-baseIndex);
			slib.__defineAnim(tag.name, animFrames);
		}

		return slib;
	}
}