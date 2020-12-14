package dn.heaps.filter;

enum GradientMapMode {
	Full;
	OnlyLights;
	OnlyShadows;
}

// --- Filter -------------------------------------------------------------------------------
class GradientMap extends h2d.filter.Shader<InternalShader> {
	public function new(tex:h3d.mat.Texture, intensity=1.0, mode:GradientMapMode=Full) {
		var s = new InternalShader();
		s.gradientMap = tex;
		s.intensity = intensity;
		s.mode = mode.getIndex();

		super(s);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var gradientMap : Sampler2D;
		@param var intensity : Float;
		@param var mode : Int;

		inline function getLum(col:Vec3) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		function fragment() {
			var pixel : Vec4 = texture.get(calculatedUV);
			if( intensity>0 ) {
				var lum = getLum(pixel.rgb);
				var rep = gradientMap.get( vec2(lum, 0) );
				if( mode==0 )
					pixelColor = vec4( mix(pixel.rgb, rep.rgb, intensity ), pixel.a);
				else if( mode==1 )
					pixelColor = vec4( mix(pixel.rgb, rep.rgb, intensity*lum ), pixel.a);
				else
					pixelColor = vec4( mix(pixel.rgb, rep.rgb, intensity*(1-lum) ), pixel.a);
			}
			else
				pixelColor = pixel;

		}
	};
}
