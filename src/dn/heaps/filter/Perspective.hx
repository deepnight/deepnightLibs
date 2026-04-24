package dn.heaps.filter;

// --- Filter -------------------------------------------------------------------------------

class Perspective extends h2d.filter.Shader<InternalShader> {
	/** Top edge horizontal scale. 1=no change, 2=double width, 0.5=half width **/
	public var topScale(default,set) : Float;

	/** Bottom edge horizontal scale. 1=no change, 2=double width, 0.5=half width **/
	public var bottomScale(default,set) : Float;

	/** Top edge horizontal offset, in pixels **/
	public var topOffset(default,set) : Float;

	/** Bottom edge horizontal offset, in pixels **/
	public var bottomOffset(default,set) : Float;

	public function new(topScale=1.0, bottomScale=1.0, topOffset=0.0, bottomOffset=0.0) {
		super( new InternalShader() );

		autoBounds = false;

		this.topScale = topScale;
		this.bottomScale = bottomScale;
		this.topOffset = topOffset;
		this.bottomOffset = bottomOffset;
	}

	inline function set_topScale(v:Float) {
		if( v<0.0001 )
			v = 0.0001;

		shader.topScale = v;
		return topScale = v;
	}

	inline function set_bottomScale(v:Float) {
		if( v<0.0001 )
			v = 0.0001;

		shader.bottomScale = v;
		return bottomScale = v;
	}

	inline function set_topOffset(v:Float) {
		shader.topOffset = v;
		return topOffset = v;
	}

	inline function set_bottomOffset(v:Float) {
		shader.bottomOffset = v;
		return bottomOffset = v;
	}

	override function getBounds(s:h2d.Object, bounds:h2d.col.Bounds, scale:h2d.col.Point) {
		s.getBounds(s, bounds);

		final x0 = bounds.xMin * scale.x;
		final y0 = bounds.yMin * scale.y;
		final x1 = bounds.xMax * scale.x;
		final y1 = bounds.yMax * scale.y;

		final wid = x1 - x0;
		final hei = y1 - y0;

		if( wid<=0 || hei<=0 ) {
			bounds.set(x0, y0, 0, 0);
			return;
		}

		final topWid = wid * topScale;
		final botWid = wid * bottomScale;

		final topX0 = x0 + topOffset * scale.x + (wid-topWid)*0.5;
		final botX0 = x0 + bottomOffset * scale.x + (wid-botWid)*0.5;

		final topX1 = topX0 + topWid;
		final botX1 = botX0 + botWid;

		// Important: always include original bounds, or the filter texture gets clipped.
		final outX0 = Math.min(x0, Math.min(topX0, botX0));
		final outX1 = Math.max(x1, Math.max(topX1, botX1));
		final outWid = outX1 - outX0;

		bounds.set(outX0, y0, outWid, hei);

		shader.src.set(
			(x0-outX0) / outWid,
			0,
			wid / outWid,
			1
		);

		shader.topOffset = topOffset * scale.x / wid;
		shader.bottomOffset = bottomOffset * scale.x / wid;
	}
}

// --- Shader -------------------------------------------------------------------------------

private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;

		// Original object rect inside the expanded filter texture:
		// x,y = min uv, z,w = size uv
		@param var src : Vec4;

		@param var topScale : Float;
		@param var bottomScale : Float;

		// Normalized to original object width
		@param var topOffset : Float;
		@param var bottomOffset : Float;

		function fragment() {
			var p = input.uv;

			var local = (p - src.xy) / src.zw;

			var y = local.y;
			var sx = mix(topScale, bottomScale, y);
			var ox = mix(topOffset, bottomOffset, y);

			var uv = vec2(
				(local.x - 0.5 - ox) / sx + 0.5,
				y
			);

			if( uv.x<0.0 || uv.x>1.0 || uv.y<0.0 || uv.y>1.0 )
				pixelColor = vec4(0.0, 0.0, 0.0, 0.0);
			else
				pixelColor = texture.get(src.xy + uv * src.zw);
		}
	};
}