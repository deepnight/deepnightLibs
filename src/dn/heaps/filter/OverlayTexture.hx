package dn.heaps.filter;

enum OverlayTextureStyle {
	/** Classic bevel (white on top-left, black on bottom-right)**/
	Classic;

	/** Low alpha on dark sides **/
	Soft;

	/** Only white at top of block **/
	Top;

	/** 2px wide bevel **/
	Deep;

	/** Horizontal light scanline **/
	ScanlineLight;

	/** Horizontal dark scanline **/
	ScanlineDark;
}

// --- Filter -------------------------------------------------------------------------------
class OverlayTexture extends h2d.filter.Shader<OverlayBlendShader> {
	/** Opacity (0-1) of the overlay texture (defaults to 1.0) **/
	public var alpha(get,set) : Float;

	/** Width / height of texture blocks **/
	public var size(default,set) : Int;

	/** Texture style (see `OverlayTextureStyle` enum)**/
	public var textureStyle(default,set) : OverlayTextureStyle;

	/** Set this method to automatically update texture size based on your own criterions. It should return the expected texture block size (see `size` field). **/
	public var autoUpdateSize: Null< Void->Int > = null;

	var overlayTex : hxsl.Types.Sampler2D;
	var invalidated = true;

	/**
		@param style Style of the overlay texture (Classic, Soft, Top or Deep) ; see `OverlayTextureStyle` enum
		@param sizePx Width & height of the overlay texture blocks
	**/
	public function new(style:OverlayTextureStyle = Classic, sizePx=2) {
		super( new OverlayBlendShader() );
		alpha = 1;
		textureStyle = style;
		size = sizePx;
	}

	/** Force re-creation of the overlay texture (not to be called often!) **/
	inline function invalidate() {
		invalidated = true;
	}

	inline function set_size(v) {
		if( size!=v )
			invalidate();
		return size = v;
	}

	inline function set_textureStyle(v) {
		if( textureStyle!=v )
			invalidate();
		return textureStyle = v;
	}
	inline function set_alpha(v) return shader.alpha = v;
	inline function get_alpha() return shader.alpha;

	override function sync(ctx:h2d.RenderContext, s:h2d.Object) {
		super.sync(ctx, s);

		if( !Std.isOfType(s, h2d.Scene) )
			throw "OverlayTextureFilter should only be attached to a 2D Scene";

		if( invalidated ) {
			invalidated = false;
			renderTexture(ctx.scene.width, ctx.scene.height);
		}

		if( autoUpdateSize!=null && size!=autoUpdateSize() ) {
			size = autoUpdateSize();
			// The invalidation will occur on next frame, to make sure scene width/height is properly set
		}

	}

	function renderTexture(screenWid:Float, screenHei:Float) {
		// Cleanup
		if( overlayTex!=null )
			overlayTex.dispose();

		// Init overlay texture
		var bd = new hxd.BitmapData(size,size);
		bd.clear(0xFF808080);
		switch textureStyle {
			case ScanlineLight:
				for(x in 0...size)
					bd.setPixel(x, 0, 0xFFffffff);

			case ScanlineDark:
				for(x in 0...size)
					bd.setPixel(x, 0, 0xFF000000);

			case Classic:
				for(x in 0...size-1) {
					bd.setPixel(x, 0, 0xFFffffff);
					bd.setPixel(x+1, size-1, 0xFF000000);
				}
				for(y in 0...size-1) {
					bd.setPixel(0, y, 0xffffffff);
					bd.setPixel(size-1, y+1, 0xff333333);
				}

			case Soft:
				for(x in 0...size-1) {
					bd.setPixel(x, 0, 0xFFffffff);
					bd.setPixel(x+1, size-1, 0xff666666);
				}
				for(y in 0...size-1) {
					bd.setPixel(0, y, 0xFFffffff);
					bd.setPixel(size-1, y+1, 0xff666666);
				}

			case Top:
				for(x in 0...size-1) {
					bd.setPixel(x,0, 0xFFffffff);
					bd.setPixel(x,size-1, 0xFF000000);
				}

			case Deep:
				for(pad in 0...2) {
					for(x in pad...size-1-pad) {
						bd.setPixel(x, pad, 0xFFffffff);
						bd.setPixel(x+1, size-1-pad, 0xFF000000);
					}
					for(y in pad...size-1-pad) {
						bd.setPixel(pad, y, 0xffffffff);
						bd.setPixel(size-1-pad, y+1, 0xff333333);
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
