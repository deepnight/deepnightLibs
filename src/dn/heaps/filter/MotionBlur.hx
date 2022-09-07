package dn.heaps.filter;


class MotionBlur extends h2d.filter.Shader<InternalShader> {
	/** If TRUE, the outline may be drawn outside of the bounds of the object texture, increasing its size. **/
	public var extendBounds = false;

	public var blurX(default,set): Float;
	public var blurY(default,set): Float;
	public var isZoomBlur(default,set): Bool;
	public var ramps(default,set): Int;
	public var zoomBlurOriginU(default,set): Float;
	public var zoomBlurOriginV(default,set): Float;

	/** Add a pixel-perfect outline around a h2d.Object using a shader filter **/
	public function new(xBlurPx:Float, yBlurPx:Float, ramps=4) {
		super( new InternalShader() );
		this.blurX = xBlurPx;
		this.blurY = yBlurPx;
		this.isZoomBlur = false;
		zoomBlurOriginU = 0.5;
		zoomBlurOriginV = 0.5;
		this.ramps = ramps;
	}

	inline function set_ramps(v:Int) {
		shader.ramps = v;
		return v;
	}
	inline function set_blurX(v:Float) {
		shader.blurX = v;
		return v;
	}

	inline function set_blurY(v:Float) {
		shader.blurY = v;
		return v;
	}

	inline function set_zoomBlurOriginU(v:Float) {
		shader.zoomBlurOriginU = v;
		return v;
	}

	inline function set_zoomBlurOriginV(v:Float) {
		shader.zoomBlurOriginV = v;
		return v;
	}

	inline function set_isZoomBlur(v:Bool) {
		shader.isZoomBlur = v ? 1 : 0;
		return v;
	}

	override function sync(ctx : h2d.RenderContext, s : h2d.Object) {
		super.sync(ctx, s);
		boundsExtend = extendBounds ? M.fmax( M.fabs(blurX),M.fabs(blurY) ) : 0;
	}

	override function draw(ctx : h2d.RenderContext, t : h2d.Tile) {
		shader.texelSize.set( 1/t.width, 1/t.height );
		return super.draw(ctx,t);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var texelSize : Vec2;

		@param var blurX : Float;
		@param var blurY : Float;

		@param var isZoomBlur : Int;
		@param var zoomBlurOriginU : Float;
		@param var zoomBlurOriginV : Float;

		@param var ramps : Float;


		inline function getLum(col:Vec3) : Float {
			return max(col.r, max(col.g, col.b));
		}

		function fragment() {
			var curColor : Vec4 = texture.get(input.uv);

			for(i in 0...int(ramps)) {
				var iLocal = i; // force local copy
				var r : Float = (iLocal+1) / ramps;

				if( isZoomBlur==1 ) {
					// Zoom blur
					var ang = atan(input.uv.y-zoomBlurOriginV, input.uv.x-zoomBlurOriginU);
					var dist = distance( input.uv, vec2(zoomBlurOriginU, zoomBlurOriginV) );
					var neighColor = texture.get(
						input.uv +
						vec2(
							texelSize.x * -blurX * dist/0.6 * (0.2+0.8*r) * cos(ang),
							texelSize.x * -blurY * dist/0.6 * (0.2+0.8*r) * sin(ang)
						)
					);
					curColor = mix( curColor, neighColor, 0.1+0.9*(1-r) );
				}
				else {
					// X/Y blurs
					var neighColor = texture.get( input.uv + vec2(texelSize.x*-blurX*(r*r-0.5), texelSize.y*-blurY*(r*r-0.5) ) );
					curColor = mix( curColor, neighColor, 0.1+0.9*(1-r) );
				}
			}

			// Increase importance of original pixels
			if( isZoomBlur==0 ) {
				var original : Vec4 = texture.get(input.uv);
				var lum = getLum(original.rgb);
				curColor = mix( curColor, original, 0.8*lum );
			}

			output.color = curColor;
		}
	};
}