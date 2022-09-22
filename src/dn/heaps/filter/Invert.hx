package dn.heaps.filter;


class Invert extends h2d.filter.Shader<InternalShader> {
	public function new() {
		super( new InternalShader() );
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;

		function fragment() {
			var col = texture.get(input.uv);
			col.r = 1-col.r;
			col.g = 1-col.g;
			col.b = 1-col.b;
			col.rgb *= col.a;
			output.color = col;
		}
	};
}