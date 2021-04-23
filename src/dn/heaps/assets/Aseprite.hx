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
}