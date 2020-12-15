package dn.heaps.filter;


/** Just paint over the affected object an ugly gradient **/
class Debug extends h2d.filter.Shader<InternalShader> {
	public function new() {
		var s = new InternalShader();
		super(s);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		var pixelSize : Vec2;

		function fragment() {
			pixelColor = vec4(
				calculatedUV.x,
				calculatedUV.y,
				0,
				1
			);
		}
	};
}
