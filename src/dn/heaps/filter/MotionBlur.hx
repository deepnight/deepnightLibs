package dn.heaps.filter;


class MotionBlur extends h2d.filter.Shader<InternalShader> {
	/** If TRUE, the outline may be drawn outside of the bounds of the object texture, increasing its size. **/
	public var extendBounds = false;

	public var blurX(default,set): Float;
	public var blurY(default,set): Float;
	public var ramps(default,set): Int;

	/** Add a pixel-perfect outline around a h2d.Object using a shader filter **/
	public function new(xBlurPx:Float, yBlurPx:Float, ramps=3) {
		super( new InternalShader() );
		this.blurX = xBlurPx;
		this.blurY = yBlurPx;
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
		@param var ramps : Float;

		inline function getLum(col:Vec3) : Float {
			return max(col.r, max(col.g, col.b));
		}

		function fragment() {
			var curColor : Vec4 = texture.get(input.uv);

			for(i in 0...int(ramps)) {
				var iLocal = i; // force local copy
				var r : Float = (iLocal+1) / ramps;
				var neighColor = texture.get( input.uv + vec2(texelSize.x*-blurX*(r*r-0.5), texelSize.y*-blurY*(r*r-0.5) ) );
				curColor = mix( curColor, neighColor, 0.1+0.9*(1-r) );
			}

			var original : Vec4 = texture.get(input.uv);
			var lum = getLum(original.rgb);
			curColor = mix( curColor, original, 0.8*lum );

			output.color = curColor;
		}
	};
}