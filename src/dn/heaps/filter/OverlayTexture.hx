package dn.heaps.filter;

enum BevelType {
	Classic;
	Soft;
	Top;
	Deep;
}

// --- Filter -------------------------------------------------------------------------------
class OverlayTexture extends h2d.filter.Shader<OverlayBlendShader> {
	public var alpha(get,set) : Float;
	public var bevelSize(default,set) : Int;
	public var bevelType(default,set) : BevelType;

	var overlayTex : hxsl.Types.Sampler2D;
	var invalidated = true;

	public function new(?type:BevelType, ?size=2) {
		super( new OverlayBlendShader() );
		alpha = 1;
		bevelType = type==null ? Classic : type;
		bevelSize = size;
	}

	public inline function invalidate() invalidated = true;

	inline function set_bevelSize(v) {
		if( bevelSize!=v )
			invalidate();
		return bevelSize = v;
	}

	inline function set_bevelType(v) {
		if( bevelType!=v )
			invalidate();
		return bevelType = v;
	}
	inline function set_alpha(v) return shader.alpha = v;
	inline function get_alpha() return shader.alpha;

	override function sync(ctx:h2d.RenderContext, s:h2d.Object) {
		super.sync(ctx, s);

		if( !Std.is(s, h2d.Scene) )
			throw "OverlayTextureFilter should only be attached to a 2D Scene";

		if( invalidated ) {
			invalidated = false;
			render(ctx.scene.width, ctx.scene.height);
		}
	}

	function render(screenWid:Float, screenHei:Float) {
		// Cleanup
		if( overlayTex!=null )
			overlayTex.dispose();

		// Init overlay texture
		var bd = new hxd.BitmapData(bevelSize,bevelSize);
		bd.clear(0xFF808080);
		switch bevelType {
			case Classic:
				for(x in 0...bevelSize-1) {
					bd.setPixel(x, 0, 0xFFffffff);
					bd.setPixel(x+1, bevelSize-1, 0xFF000000);
				}
				for(y in 0...bevelSize-1) {
					bd.setPixel(0, y, 0xffffffff);
					bd.setPixel(bevelSize-1, y+1, 0xff333333);
				}

			case Soft:
				for(x in 0...bevelSize-1) {
					bd.setPixel(x, 0, 0xFFffffff);
					bd.setPixel(x+1, bevelSize-1, 0xff666666);
				}
				for(y in 0...bevelSize-1) {
					bd.setPixel(0, y, 0xFFffffff);
					bd.setPixel(bevelSize-1, y+1, 0xff666666);
				}

			case Top:
				for(x in 0...bevelSize-1) {
					bd.setPixel(x,0, 0xFFffffff);
					bd.setPixel(x,bevelSize-1, 0xFF000000);
				}

			case Deep:
				for(pad in 0...2) {
					for(x in pad...bevelSize-1-pad) {
						bd.setPixel(x, pad, 0xFFffffff);
						bd.setPixel(x+1, bevelSize-1-pad, 0xFF000000);
					}
					for(y in pad...bevelSize-1-pad) {
						bd.setPixel(pad, y, 0xffffffff);
						bd.setPixel(bevelSize-1-pad, y+1, 0xff333333);
					}
				}

		}
		overlayTex = hxsl.Types.Sampler2D.fromBitmap(bd);
		overlayTex.filter = Nearest;
		overlayTex.wrap = Repeat;

		// Update shader
		shader.overlay = overlayTex;
		shader.uvScale = new hxsl.Types.Vec( screenWid / overlayTex.width, screenHei / overlayTex.width );
	}
}


// --- Shader -------------------------------------------------------------------------------
private class OverlayBlendShader extends h3d.shader.ScreenShader {

	static var SRC = {
		@param var texture : Sampler2D;
		@param var overlay : Sampler2D;

		@param var alpha : Float;
		@param var uvScale : Vec2;

		function blendOverlay(base:Vec3, blend:Vec3) : Vec3 {
			return mix(
				1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
				2.0 * base * blend,
				step( base, vec3(0.5) )
			);
		}

		function fragment() {
			var sourceColor = texture.get(input.uv);
			var overlayColor = mix( vec4(0.5), overlay.get(input.uv*uvScale), alpha );

			pixelColor.rgba = vec4(
				blendOverlay( sourceColor.rgb, overlayColor.rgb ),
				sourceColor.a
			);
		}

	};
}
