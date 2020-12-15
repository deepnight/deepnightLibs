package dn.heaps.filter;

class GradientDarkness extends h2d.filter.Shader<InternalShader> {
	/** Offset (in pixels) for horizontal darkness distorsion. 0 to disable. **/
	public var xDistortOffsetPx = 0.;

	/** Length (in pixels) of the cos wave for darkness distorsion. **/
	public var xDistortWaveLenPx = 16.;

	/** Speed multiplier for darkness distorsion **/
	public var xDistortSpeed = 1.0;


	/** Offset (in pixels) for vertical darkness distorsion. 0 to disable. **/
	public var yDistortOffsetPx = 0.;

	/** Length (in pixels) of the sin wave for darkness distorsion. **/
	public var yDistortWaveLenPx = 16.;

	/** Speed multiplier for darkness distorsion **/
	public var yDistortSpeed = 1.0;

	/** All colors in darkness will be multiplied by this factor. Values lower than 1 will make colors in darkness darker, before applying the gradient map. **/
	public var darknessColorMul  = 1.0;



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

	/** Replace existing **Light map** using a whole new one. Ideally, for perf reasons, the existing `Texture` provided to the constructor should just be updated. **/
	public inline function replaceLightMap(t, disposePrevious=true) {
		if( disposePrevious )
			shader.lightMap.dispose();
		shader.lightMap = t;
	}

	/** Replace existing **Gradient map** using a whole new one. Ideally, for perf reasons, the existing `Texture` provided to the constructor should just be updated. **/
	public inline function replaceGradientMap(t, disposePrevious=true) {
		if( disposePrevious )
			shader.gradientMap.dispose();
		shader.gradientMap = t;
	}

	override function sync(ctx:h2d.RenderContext, s:h2d.Object) {
		super.sync(ctx, s);

		// Update X distorsion values
		shader.xOffset = xDistortOffsetPx * (1/shader.lightMap.width);
		shader.xWaveLen = M.PI2 * shader.lightMap.width / xDistortWaveLenPx;
		shader.xTime = hxd.Timer.frameCount * 0.03 * xDistortSpeed;

		// Update Y distorsion values
		shader.yOffset = yDistortOffsetPx * (1/shader.lightMap.height);
		shader.yWaveLen = M.PI2 * shader.lightMap.height / yDistortWaveLenPx;
		shader.yTime = hxd.Timer.frameCount * 0.03 * yDistortSpeed;

		shader.colorMul = darknessColorMul;
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

		// X darkness distorsion
		@param var xTime: Float = 0;
		@param var xWaveLen: Float = 0;
		@param var xOffset: Float = 0;

		// Y darkness distorsion
		@param var yTime: Float = 0;
		@param var yWaveLen: Float = 0;
		@param var yOffset: Float = 0;


		inline function getLum(col:Vec3) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		function fragment() {
			// Get light intensity
			var lightPow = lightMap.get(calculatedUV).r;

			// Distort (offset UV) in darkness
			calculatedUV.x += intensity * (1-lightPow) * xOffset * sin( calculatedUV.x*xWaveLen + xTime );
			calculatedUV.y += intensity * (1-lightPow) * yOffset * sin( calculatedUV.y*yWaveLen + yTime );

			// Colorize darkness
			var curColor : Vec4 = texture.get(calculatedUV);
			curColor.rgb = mix(curColor.rgb, vec3(0), (1-colorMul)*(1-lightPow));
			var curLuminance = getLum(curColor.rgb);
			var rep = gradientMap.get( vec2(curLuminance, 0) );

			// Final pixel color
			pixelColor = vec4(
				curColor.rgb*(1-intensity) + intensity * (curColor.rgb*lightPow + rep.rgb*(1-lightPow)),
				curColor.a
			);
		}
	};
}
