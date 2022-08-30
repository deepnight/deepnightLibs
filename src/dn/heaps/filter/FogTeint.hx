package dn.heaps.filter;

class FogTeint extends h2d.filter.Shader<InternalShader> {
	/** Fog intensity (0-1) **/
	public var intensity(default,set) : Float;
		inline function set_intensity(v) return shader.intensity = M.fclamp(v,0,1);

	/** Fog color (RGB) **/
	public var color(default,set) : Col;
		inline function set_color(c:Col) { shader.fog.setColor(c); return c; }

	public function new(col:Col, intensity=1.0) {
		super( new InternalShader() );
		this.color = col;
		this.intensity = intensity;
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var fog : Vec3;
		@param var intensity : Float;

		inline function getLum(col:Vec3) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		function fragment() {
			var src : Vec4 = texture.get(calculatedUV);

			if( intensity>0 && src.a>0 ) {
				var l = getLum(src.rgb);
				pixelColor = mix( src.rgba, vec4(fog.rgb, src.a), intensity );
			}
			else
				pixelColor = src;
		}
	};
}
