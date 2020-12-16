package dn.heaps.filter;

class Edge extends h2d.filter.Shader<InternalShader> {
	/**
		Contrast threshold required between 2 colors, to be considered as an edge. Value is in [1-21] range: 1=identical, 1.5=some contrast (default), 21=black vs white.
		See: https://contrast-ratio.com
	**/
	public var contrastThreshold(null,set) : Float;
	// public var notEdgeMultiplier(null,set) : Float;

	public function new() {
		super( new InternalShader() );
	}

	// inline function set_notEdgeMultiplier(v) return shader.notEdgeMul = v;
	inline function set_contrastThreshold(v) return shader.contrastThreshold = v;

	override function draw(ctx:h2d.RenderContext, t:h2d.Tile):h2d.Tile {
		shader.pixelSize = hxsl.Types.Vec.fromArray([ 1/t.width, 1/t.height ]);
		return super.draw(ctx, t);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var pixelSize : Vec2;
		// @param var notEdgeMul : Float = 0.66;
		@param var contrastThreshold : Float = 1.5;

		/** Get color luminance **/
		inline function getLum(col:Vec4) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		/** Get contrast ratio between 2 colors in range [1-21] **/
		inline function getContrast(c1:Vec4, c2:Vec4) : Float {
			var lum1 = getLum(c1);
			var lum2 = getLum(c2);
			return ( max(lum1,lum2) + 0.05 ) / ( min(lum1,lum2) + 0.05 );
		}

		/** Return 1 if cur is contrasted with c, and cur is brighter. 0 otherwise.**/
		inline function hasContrast(cur:Vec4, c:Vec4) : Float {
			return
				step( getLum(c), getLum(cur) ) // 1 if "cur" is brighter than "c"
				* step( contrastThreshold, getContrast(cur, c) );
		}


		function fragment() {
			var uv = calculatedUV;
			var curColor = texture.get(uv);

			var above = texture.get( vec2(uv.x, uv.y-pixelSize.y) );
			var below = texture.get( vec2(uv.x, uv.y+pixelSize.y) );
			var left = texture.get( vec2(uv.x-pixelSize.x, uv.y) );
			var right = texture.get( vec2(uv.x+pixelSize.x, uv.y) );

			// This value 1 if current texel is detected as an edge
			var edge = max(
				max( hasContrast(curColor,above), hasContrast(curColor,below) ),
				max( hasContrast(curColor,left), hasContrast(curColor,right) )
			);

			pixelColor = vec4( curColor.rgb*edge, curColor.a );
		}
	};
}
