package dn.heaps.filter;


class Monochrome extends h2d.filter.Shader<InternalShader> {
	public var dark(default,set) : Col;
	public var light(default,set) : Col;
	public var threshold(default,set) : Float;

	public function new(dark:Col=0x0, light:Col=0xffffff, threshold=0.28) {
		super( new InternalShader() );
		this.dark = dark;
		this.light = light;
		this.threshold = threshold;
	}

	inline function set_dark(v:Col) {
		dark = v;
		shader.dark = v.withoutAlpha().toShaderVec3();
		return v;
	}

	inline function set_light(v:Col) {
		light = v;
		shader.light = v.withoutAlpha().toShaderVec3();
		return v;
	}

	inline function set_threshold(v:Float) {
		return shader.threshold = threshold = v;
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var dark : Vec3;
		@param var light : Vec3;
		@param var threshold : Float;

		inline function getLum(col:Vec4) : Float {
			return col.rgb.dot( vec3(0.2126, 0.7152, 0.0722) );
		}

		function fragment() {
			var col : Vec4 = texture.get(input.uv);
			var isLight = step( threshold, getLum(col) );
			col.rgb = (1-isLight)*dark + isLight*light;
			col.rgb *= col.a;
			output.color = col;
		}
	};
}