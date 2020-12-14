package dn.heaps.filter;

class GradientDarkness extends h2d.filter.Shader<InternalShader> {

	/**
		@param lightMap A black & white texture, where black means "in shadows".
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

}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var lightMap : Sampler2D;
		@param var gradientMap : Sampler2D;
		@param var intensity : Float;

		inline function getLum(col:Vec3) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		function fragment() {
			var pixel : Vec4 = texture.get(calculatedUV);
			var lightPixel = lightMap.get(calculatedUV);
			var light = lightPixel.r;

			var lumi = getLum(pixel.rgb);
			var rep = gradientMap.get( vec2(lumi, 0) );

			pixelColor = vec4( pixel.rgb*(1-intensity) + intensity * (pixel.rgb*light + rep.rgb*(1-light)), pixel.a );
		}
	};
}
