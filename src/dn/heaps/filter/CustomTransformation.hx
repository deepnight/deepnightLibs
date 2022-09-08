package dn.heaps.filter;


class CustomTransformation extends h2d.filter.Shader<InternalShader> {
	public var scaleX(default,set): Float;
	public var scaleY(default,set): Float;
	public var scalePivotX(default,set): Float;
	public var scalePivotY(default,set): Float;

	public var skewScaleLeft(default,set) : Float;
	public var skewScaleRight(default,set) : Float;
	public var skewScaleTop(default,set) : Float;
	public var skewScaleBottom(default,set) : Float;

	public var rectangularZoom(default,set) : Float;


	public function new() {
		super( new InternalShader() );

		reset();
	}

	public function reset() {
		setScale(1);
		setScalePivots(0,0);
		rectangularZoom = 0;
		resetSkews();
	}

	public inline function resetSkews() {
		skewScaleLeft = 1;
		skewScaleRight = 1;
		skewScaleTop = 1;
		skewScaleBottom = 1;
	}

	public inline function setScale(s:Float) {
		scaleX = scaleY = s;
	}

	public inline function setScalePivots(px:Float, py:Float) {
		scalePivotX = px;
		scalePivotY = py;
	}

	inline function set_scaleX(v:Float) return shader.scaleX = v;
	inline function set_scaleY(v:Float) return shader.scaleY = v;
	inline function set_scalePivotX(v:Float) return shader.scalePivotX = v;
	inline function set_scalePivotY(v:Float) return shader.scalePivotY = v;

	inline function set_skewScaleLeft(v:Float) return shader.skewScaleLeft = v;
	inline function set_skewScaleRight(v:Float) return shader.skewScaleRight = v;
	inline function set_skewScaleTop(v:Float) return shader.skewScaleTop = v;
	inline function set_skewScaleBottom(v:Float) return shader.skewScaleBottom = v;

	inline function set_rectangularZoom(v:Float) return shader.rectangularZoom = v;

	override function sync(ctx : h2d.RenderContext, s : h2d.Object) {
		super.sync(ctx, s);
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

		@param var scaleX : Float;
		@param var scaleY : Float;
		@param var scalePivotX : Float;
		@param var scalePivotY : Float;

		@param var skewScaleLeft : Float;
		@param var skewScaleRight : Float;
		@param var skewScaleTop : Float;
		@param var skewScaleBottom : Float;

		@param var rectangularZoom : Float;

		@param var ramps : Float;


		inline function getLum(col:Vec3) : Float {
			return max(col.r, max(col.g, col.b));
		}

		/** Get source texture color at given UV, clamping out-of-bounds positions **/
		inline function getSrcColor(uv:Vec2) : Vec4 {
			return texture.get(uv)
				* vec4( step(0, uv.x) * step(0, 1-uv.x) )
				* vec4( step(0, uv.y) * step(0, 1-uv.y) );

		}

		function fragment() {
			var uv = calculatedUV;

			// Base scaling
			uv.x = uv.x / scaleX + scalePivotX - scalePivotX/scaleX;
			uv.y = uv.y / scaleY + scalePivotY - scalePivotY/scaleY;

			// Skew scaling
			var skewScale = skewScaleLeft + uv.x * ( skewScaleRight - skewScaleLeft );
			uv.y = uv.y / skewScale  +  0.5  -  0.5/skewScale;
			skewScale = skewScaleTop + uv.y * ( skewScaleBottom - skewScaleTop );
			uv.x = uv.x / skewScale  +  0.5  -  0.5/skewScale;

			// Zoom scale
			if( rectangularZoom!=0 ) {
				var centerU = 0.5;
				var centerV = 0.45;
				var distX = ( uv.x - centerU ) * 0.7;
				var distY = ( uv.y - centerV ) * 0.7;
				uv.x = uv.x + abs(distX) * distX * -rectangularZoom;
				uv.y = uv.y + abs(distY) * distY * -rectangularZoom;
				output.color = texture.get(uv);
			}
			else
				output.color = getSrcColor(uv);

		}
	};
}
