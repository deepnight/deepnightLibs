package dn.heaps.filter;


class CustomTransformation extends h2d.filter.Shader<InternalShader> {
	/** Horizontal translation in pixels **/
	public var offsetX(default,set): Float;
	/** Vertical translation in pixels **/
	public var offsetY(default,set): Float;

	/** Global X scale factor (defaults to 1) **/
	public var scaleX(default,set): Float;
	/** Global Y scale factor (defaults to 1) **/
	public var scaleY(default,set): Float;
	/** Horizontal "coordinate" used for X scaling (defaults to 0) **/
	public var scalePivotX(default,set): Float;
	/** Vertical "coordinate" used for Y scaling (defaults to 0) **/
	public var scalePivotY(default,set): Float;

	/** Left side skew factor (defaults to 1) **/
	public var skewScaleLeft(default,set) : Float;
	/** Right side skew factor (defaults to 1) **/
	public var skewScaleRight(default,set) : Float;
	/** Upper side skew factor (defaults to 1) **/
	public var skewScaleTop(default,set) : Float;
	/** Lower side skew factor (defaults to 1) **/
	public var skewScaleBottom(default,set) : Float;

	/** Rectangular X zoom factor (defaults to 0) **/
	public var rectangularZoomX(default,set) : Float;

	/** Rectangular Y zoom factor (defaults to 0) **/
	public var rectangularZoomY(default,set) : Float;

	public var rectangularZoom(never,set) : Float;

	/** Pivot coordinate (U) for rectangular zoom (defaults to 0.5) **/
	public var rectangularZoomCenterU(default,set) : Float;

	/** Pivot coordinate (V) for rectangular zoom (defaults to 0.5) **/
	public var rectangularZoomCenterV(default,set) : Float;


	public function new() {
		super( new InternalShader() );

		reset();
	}

	public function reset() {
		offsetX = offsetY = 0;
		setScale(1);
		setScalePivots(0,0);
		resetSkews();
		rectangularZoomX = 0;
		rectangularZoomY = 0;
		rectangularZoomCenterU = 0.5;
		rectangularZoomCenterV = 0.5;
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

	inline function set_offsetX(v:Float) return offsetX = shader.offsetX = v;
	inline function set_offsetY(v:Float) return offsetY = shader.offsetY = v;

	inline function set_scaleX(v:Float) return scaleX = shader.scaleX = v;
	inline function set_scaleY(v:Float) return scaleY = shader.scaleY = v;
	inline function set_scalePivotX(v:Float) return scalePivotX = shader.scalePivotX = v;
	inline function set_scalePivotY(v:Float) return scalePivotY = shader.scalePivotY = v;

	inline function set_skewScaleLeft(v:Float) return skewScaleLeft = shader.skewScaleLeft = v;
	inline function set_skewScaleRight(v:Float) return skewScaleRight = shader.skewScaleRight = v;
	inline function set_skewScaleTop(v:Float) return skewScaleTop = shader.skewScaleTop = v;
	inline function set_skewScaleBottom(v:Float) return skewScaleBottom = shader.skewScaleBottom = v;

	inline function set_rectangularZoom(v:Float) return rectangularZoomX = rectangularZoomY = v;
	inline function set_rectangularZoomX(v:Float) return rectangularZoomX = shader.rectangularZoomX = v;
	inline function set_rectangularZoomY(v:Float) return rectangularZoomY = shader.rectangularZoomY = v;
	inline function set_rectangularZoomCenterU(v:Float) return rectangularZoomCenterU = shader.rectangularZoomCenterU = v;
	inline function set_rectangularZoomCenterV(v:Float) return rectangularZoomCenterV = shader.rectangularZoomCenterV = v;

	override function sync(ctx : h2d.RenderContext, s : h2d.Object) {
		super.sync(ctx, s);
	}

	override function draw(ctx:h2d.RenderContext, t:h2d.Tile):h2d.Tile {
		shader.texelSize.set( 1/t.width, 1/t.height );

		return super.draw(ctx, t);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var texelSize : Vec2;

		@param var offsetX : Float;
		@param var offsetY : Float;

		@param var scaleX : Float;
		@param var scaleY : Float;
		@param var scalePivotX : Float;
		@param var scalePivotY : Float;

		@param var skewScaleLeft : Float;
		@param var skewScaleRight : Float;
		@param var skewScaleTop : Float;
		@param var skewScaleBottom : Float;

		@param var rectangularZoomX : Float;
		@param var rectangularZoomY : Float;
		@param var rectangularZoomCenterU : Float;
		@param var rectangularZoomCenterV : Float;


		/** Get source texture color at given UV, clamping out-of-bounds positions **/
		inline function getSrcColor(uv:Vec2) : Vec4 {
			return texture.get(uv)
				* vec4( step(0, uv.x) * step(0, 1-uv.x) )
				* vec4( step(0, uv.y) * step(0, 1-uv.y) );

		}

		function fragment() {
			var uv = calculatedUV;

			// Offsets
			uv.x -= offsetX * texelSize.x;
			uv.y -= offsetY * texelSize.y;

			// Base scaling
			uv.x = uv.x / scaleX + scalePivotX - scalePivotX/scaleX;
			uv.y = uv.y / scaleY + scalePivotY - scalePivotY/scaleY;

			// Skew scaling
			var skewScale = skewScaleLeft + uv.x * ( skewScaleRight - skewScaleLeft );
			uv.y = uv.y / skewScale  +  0.5  -  0.5/skewScale;
			skewScale = skewScaleTop + uv.y * ( skewScaleBottom - skewScaleTop );
			uv.x = uv.x / skewScale  +  0.5  -  0.5/skewScale;

			// Zoom scale
			if( rectangularZoomX*rectangularZoomY!=0 ) {
				var distX = ( uv.x - rectangularZoomCenterU ) * 0.7;
				var distY = ( uv.y - rectangularZoomCenterV ) * 0.7;
				uv.x = uv.x + abs(distX) * distX * -rectangularZoomX;
				uv.y = uv.y + abs(distY) * distY * -rectangularZoomY;
			}

			output.color = getSrcColor(uv);
		}
	};
}
