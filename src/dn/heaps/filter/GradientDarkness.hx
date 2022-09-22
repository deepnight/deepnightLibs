package dn.heaps.filter;

class GradientDarkness extends h2d.filter.Shader<InternalShader> {
	/** Enhance edges in darkness: 0=no enhancement (default), 1=only show edges in darkness **/
	public var darknessEdgeEnhance = 0.;

	/** Max distance  (in pixels) for horizontal darkness distorsion. 0 to disable. **/
	public var xDistortPx = 0.;

	/** Length (in pixels) of the cos wave for darkness distorsion. **/
	public var xDistortWaveLenPx = 16.;

	/** Speed multiplier for darkness distorsion **/
	public var xDistortSpeed = 1.0;

	/** Keep this value updated to compensate camera X scrolling, making distortion relative to camera instead of window **/
	public var xDistortCameraPx = 0.;



	/** Max distance (in pixels) for vertical darkness distorsion. 0 to disable. **/
	public var yDistortPx = 0.;

	/** Length (in pixels) of the sin wave for darkness distorsion. **/
	public var yDistortWaveLenPx = 16.;

	/** Speed multiplier for darkness distorsion **/
	public var yDistortSpeed = 1.0;

	/** All colors in darkness will be multiplied by this factor. Values lower than 1 will make colors in darkness darker, before applying the gradient map. **/
	public var darknessColorMul  = 1.0;

	/** Keep this value updated to compensate camera Y scrolling, making distortion relative to camera instead of window **/
	public var yDistortCameraPx = 0.;


	/**
		Add this filter to a display object, like a Scene, or a game wrapper) to colorize it (and optionally distort it), based on a lightning map.

		@param lightMap A black & white texture, where black means "in shadows". It should have the exact same size as the object affected by the filter.
		@param shadowGradientMap The gradient map to apply to areas in darkness.
		@param gradientIntensity The intensity of the gradient map applied to dark areas (0-1)
	**/
	public function new(lightMap:h3d.mat.Texture, shadowGradientMap:h3d.mat.Texture, gradientIntensity=1.0) {
		var s = new InternalShader();
		s.lightMap = lightMap;
		s.gradientMap = shadowGradientMap;
		s.intensity = M.fclamp(gradientIntensity,0,1);

		super(s);
	}

	/** Replace existing **Light map** using a whole new one. Ideally, for perf reasons, the existing `Texture` provided to the constructor should be updated directly. **/
	public inline function replaceLightMap(t, disposePrevious=true) {
		if( disposePrevious )
			shader.lightMap.dispose();
		shader.lightMap = t;
	}

	/** Replace existing **Gradient map** using a whole new one. Ideally, for perf reasons, the existing `Texture` provided to the constructor should be updated directly. **/
	public inline function replaceGradientMap(t, disposePrevious=true) {
		if( disposePrevious )
			shader.gradientMap.dispose();
		shader.gradientMap = t;
	}

	override function draw(ctx:h2d.RenderContext, t:h2d.Tile):h2d.Tile {
		// Update X distorsion values
		var texelSize = (1/shader.lightMap.width);
		shader.xDist = xDistortPx * texelSize;
		shader.xWaveLen = M.PI2 * shader.lightMap.width / xDistortWaveLenPx;
		shader.xTime = hxd.Timer.frameCount * 0.03 * xDistortSpeed;
		shader.xCam = xDistortCameraPx * texelSize;

		// Update Y distorsion values
		texelSize = (1/shader.lightMap.height);
		shader.yDist = yDistortPx * texelSize;
		shader.yWaveLen = M.PI2 * shader.lightMap.height / yDistortWaveLenPx;
		shader.yTime = hxd.Timer.frameCount * 0.03 * yDistortSpeed;
		shader.yCam = yDistortCameraPx * texelSize;

		shader.colorMul = darknessColorMul;
		shader.notEdgeMul = 1 - M.fclamp(darknessEdgeEnhance,0,1);
		shader.texelSize.set( 1/t.width, 1/t.height );

		return super.draw(ctx, t);
	}

}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var lightMap : Sampler2D;
		@param var gradientMap : Sampler2D;
		@param var intensity : Float;
		@param var colorMul : Float = 1.0;
		@param var texelSize : Vec2;
		@param var notEdgeMul : Float;

		// X darkness distorsion
		@param var xDist: Float = 0;
		@param var xTime: Float = 0;
		@param var xWaveLen: Float = 0;
		@param var xCam: Float = 0;

		// Y darkness distorsion
		@param var yTime: Float = 0;
		@param var yWaveLen: Float = 0;
		@param var yDist: Float = 0;
		@param var yCam: Float = 0;


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
			return step( 1.5, getContrast(cur, c) );
		}


		function fragment() {
			var uv = calculatedUV;

			// Get light intensity
			var lightPow = lightMap.get(uv).r;

			/** DISTORSION ******************************/

			uv.x += intensity * (1-lightPow) * xDist * sin( (uv.x + xCam) * xWaveLen + xTime );
			uv.y += intensity * (1-lightPow) * yDist * sin( (uv.y + yCam) * yWaveLen + yTime );

			var curColor : Vec4 = texture.get(uv);



			/** EDGE DETECTION ******************************/

			if( notEdgeMul<1 ) {
				// Read nearby texels
				var above = texture.get( vec2(uv.x, uv.y-texelSize.y) );
				var below = texture.get( vec2(uv.x, uv.y+texelSize.y) );
				var left = texture.get( vec2(uv.x-texelSize.x, uv.y) );
				var right = texture.get( vec2(uv.x+texelSize.x, uv.y) );

				// This value 1 if current texel is detected as an edge
				var edge = max(
					max( hasContrast(curColor,above), hasContrast(curColor,below) ),
					max( hasContrast(curColor,left), hasContrast(curColor,right) )
				);

				curColor.rgb *= mix(max( edge, notEdgeMul ), 1, lightPow );
			}


			/** DARKNESS GRADIENT MAPPING ******************************/

			// Apply darkness mul
			curColor.rgb = mix(curColor.rgb, vec3(0), (1-colorMul)*(1-lightPow));

			// Gradient map
			var rep = gradientMap.get( vec2(getLum(curColor), 0) );


			/** FINAL TEXEL COLOR ******************************/

			pixelColor = vec4(
				curColor.rgb*(1-intensity) // Original color
					+ intensity * (
						curColor.rgb*lightPow // color in light
						+ rep.rgb*(1-lightPow) // color in darkness
					),
				curColor.a
			);
		}
	};
}
