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


		function fragment() {
			var pixelSize = vec2(0.05, 0.05); // should use actual pixel UV
			var bounds =
				calculatedUV.x<=pixelSize.x || calculatedUV.x>=1-pixelSize.x ||
				calculatedUV.y<=pixelSize.y || calculatedUV.y>=1-pixelSize.y ? 1 : 0;

			var curColor = texture.get( calculatedUV );
			pixelColor = vec4(
				mix(curColor.r, calculatedUV.x, 0.7),
				mix(curColor.g, calculatedUV.y, 0.7),
				bounds,
				1
			);
		}
	};
}
