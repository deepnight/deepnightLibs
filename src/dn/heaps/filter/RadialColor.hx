package dn.heaps.filter;


class RadialColor extends h2d.filter.Shader<InternalShader> {
	public var innerIntensity(default,set): Float;
	public var outerIntensity(default,set): Float;
	public var threshold(default,set): Float;

	public function new() {
		super( new InternalShader() );
		innerIntensity = 0;
		outerIntensity = 0;
		threshold = 0.5;
		setColor(0x0, 0);
		// setColor(0x00ff00, 0);
	}

	public inline function setColor(c:Col, a=1.0) {
		shader.color = c.withAlpha(a).toShaderVec4();
	}

	inline function set_innerIntensity(v:Float) return innerIntensity = shader.innerIntensity = M.fclamp(v,0,1);
	inline function set_outerIntensity(v:Float) return outerIntensity = shader.outerIntensity = M.fclamp(v,0,1);
	inline function set_threshold(v:Float) {
		threshold = v;
		shader.threshold = M.fmax(v, 0.001);
		return v;
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var texelSize : Vec2;

		@param var color : Vec4;
		@param var innerIntensity : Float;
		@param var outerIntensity : Float;
		@param var threshold : Float;


		function fragment() {
			var uv = input.uv;
			var src : Vec4  = texture.get(uv);
			output.color = mix(
				mix( src, color, innerIntensity ),
				mix( src, color, outerIntensity ),
				clamp( distance(vec2(0.5),uv) / threshold, 0, 1 )
				// clamp( pow( distance(vec2(0.5), uv) / 0.5, 0.4 ), 0, 1 )
				// clamp( threshold * distance( vec2(0.5), uv ) / 0.5, 0, 1 )
			);
		}
	};
}