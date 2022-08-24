package dn.heaps.filter;

// --- Filter -------------------------------------------------------------------------------
class Crt extends h2d.filter.Shader<InternalShader> {
	/** Scanline texture color (RGB format, defaults to 0xffffff) **/
	public var scanlineColor(default,set) : Col;

	/** Scanline texture opacity (0-1) (defaults to 1.0) **/
	public var scanlineAlpha(get,set) : Float;

	/** Horizontal screen distorsion intensity (0-1), defaults to 0.5 **/
	public var curvatureH(default,set) : Float;

	/** Verticval screen distorsion intensity (0-1), defaults to 0.5 **/
	public var curvatureV(default,set) : Float;

	/** Dark vignetting intensity (0-1), defaults to 0.5 **/
	public var vignetting(default,set) : Float;

	/** Height of the scanlines **/
	public var scanlineSize(default,set) : Int;

	/** Set this method to automatically update scanline size based on your own criterions. It should return the new scanline size. **/
	public var autoUpdateSize: Null< Void->Int > = null;

	var scanlineTex : hxsl.Types.Sampler2D;
	var invalidated = true;

	/**
		@param scanlineSize Height of the scanline overlay texture blocks
	**/
	public function new(scanlineSize=2, scanlineColor:Col=0xffffff, alpha=1.0) {
		super( new InternalShader() );
		this.scanlineAlpha = alpha;
		this.scanlineSize = scanlineSize;
		this.scanlineColor = scanlineColor;
		curvatureH = 0.5;
		curvatureV = 0.5;
	}

	/** Force re-creation of the overlay texture (not to be called often!) **/
	inline function invalidate() {
		invalidated = true;
	}

	inline function set_curvatureH(v:Float) {
		return shader.curvature.y = v<=0 ?  99  :  2 + (1-v) * 10;
	}

	inline function set_curvatureV(v:Float) {
		return shader.curvature.x = v<=0 ?  99  :  2 + (1-v) * 10;
	}

	inline function set_vignetting(v:Float) {
		return shader.vignetting = v;
	}

	inline function set_scanlineSize(v) {
		if( scanlineSize!=v )
			invalidate();
		return scanlineSize = v;
	}

	inline function set_scanlineColor(v) {
		if( scanlineColor!=v )
			invalidate();
		return scanlineColor = v;
	}

	inline function set_scanlineAlpha(v:Float) return shader.alpha = v;
	inline function get_scanlineAlpha() return shader.alpha;

	override function sync(ctx:h2d.RenderContext, s:h2d.Object) {
		super.sync(ctx, s);

		if( !Std.isOfType(s, h2d.Scene) )
			throw "CRT filter should only be attached to a 2D Scene";

		if( invalidated ) {
			invalidated = false;
			initTexture(ctx.scene.width, ctx.scene.height);
		}

		if( autoUpdateSize!=null && scanlineSize!=autoUpdateSize() ) {
			scanlineSize = autoUpdateSize();
			// The invalidation re-render will only occur during next frame, to make sure scene width/height is properly set
		}

	}

	function initTexture(screenWid:Float, screenHei:Float) {
		// Cleanup
		if( scanlineTex!=null )
			scanlineTex.dispose();

		// Init texture
		final neutral = 0xFF808080;
		var bd = new hxd.BitmapData(scanlineSize,scanlineSize);
		bd.clear(neutral);
		for(x in 0...bd.width)
			bd.setPixel(x, 0, scanlineColor);

		scanlineTex = hxsl.Types.Sampler2D.fromBitmap(bd);
		scanlineTex.filter = Nearest;
		scanlineTex.wrap = Repeat;

		// Update shader
		shader.scanline = scanlineTex;
		shader.texelSize.set( 1/screenWid, 1/screenHei );
		shader.uvScale = new hxsl.Types.Vec( screenWid / scanlineTex.width, screenHei / scanlineTex.width );
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {

	static var SRC = {
		@param var texture : Sampler2D;
		@param var scanline : Sampler2D;

		@param var curvature : Vec2;
		@param var vignetting : Float;
		@param var alpha : Float;
		@param var uvScale : Vec2;
		@param var texelSize : Vec2;

		function blendOverlay(base:Vec3, blend:Vec3) : Vec3 {
			return mix(
				1.0 - 2.0 * (1.0 - base) * (1.0 - blend),
				2.0 * base * blend,
				step( base, vec3(0.5) )
			);
		}

		function curve(uv:Vec2) : Vec2 {
			var out = uv*2 - 1;

			var offset = abs(out.yx) / curvature;
			out = out + out * offset * offset;

			out = out*0.5 + 0.5;
			return out;
		}

		function vignette(uv:Vec2) : Float {
			var off = max( abs(uv.y*2-1) / 4,  abs(uv.x*2-1) / 4 );
			return 300 * off*off*off*off*off;
		}

		function fragment() {
			// Distortion
			var uv = curve( input.uv );

			// Scanlines texture
			var sourceColor = texture.get(uv);
			var scanlineColor = mix( vec4(0.5), scanline.get(input.uv*uvScale), alpha );
			pixelColor.rgba = vec4(
				blendOverlay( sourceColor.rgb, scanlineColor.rgb ),
				sourceColor.a
			);

			// Vignetting
			pixelColor.rgb *= 1 - vignetting * vignette(input.uv);

			// Clear out-of-bounds pixels
			pixelColor.rgba *=
				step(0, uv.x) * step(uv.x, 1) * // x
				step(0, uv.y) * step(uv.y, 1); // y
		}

	};
}
