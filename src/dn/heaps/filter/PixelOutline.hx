package dn.heaps.filter;


class PixelOutline extends h2d.filter.Filter {
	/** Outline color (0xRRGGBB) **/
	public var color(default, set) : Int;

	/** If TRUE, the original object pixels are discarded, and only the outline remains **/
	public var knockOut(default,set) : Bool;

	var pass : PixelOutlinePass;

	/** Add a pixel-perfect outline around a h2d.Object using a shader filter **/
	public function new(color=0x0, knockOut=false) {
		super();
		pass = new PixelOutlinePass(color);
		this.color = color;
		smooth = false;
		this.knockOut = knockOut;
	}

	inline function set_color(v:Int) {
		color = v;
		pass.color = color;
		return v;
	}

	inline function set_knockOut(v) {
		knockOut = v;
		pass.knockOut = knockOut;
		return v;
	}

	override function sync(ctx : h2d.RenderContext, s : h2d.Object) {
		boundsExtend = 1;
	}

	override function draw(ctx : h2d.RenderContext, t : h2d.Tile) {
		var out = ctx.textures.allocTileTarget("colorMatrixOut", t);
		pass.apply(t.getTexture(), out);
		return h2d.Tile.fromTexture(out);
	}
}


// --- H3D pass -------------------------------------------------------------------------------
@ignore("shader")
private class PixelOutlinePass extends h3d.pass.ScreenFx<PixelOutlineShader> {
	public var color(default, set) : Int;
	public var knockOut(default, set) : Bool;

	public function new(color=0x0) {
		super(new PixelOutlineShader());
		this.color = color;
		knockOut = false;
	}

	function set_color(c) {
		if( color==c )
			return c;
		return color = c;
	}

	function set_knockOut(v) {
		if( knockOut==v )
			return v;
		return knockOut = v;
	}

	public function apply(src:h3d.mat.Texture, out:h3d.mat.Texture) {
		engine.pushTarget(out);

		shader.texture = src;
		shader.outlineColor.setColor(color);
		shader.pixelSize.set(1/src.width, 1/src.height);
		shader.knockOutMul = knockOut ? 0 : 1;
		render();

		engine.popTarget();
	}

}

// --- Shader -------------------------------------------------------------------------------
private class PixelOutlineShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var pixelSize : Vec2;
		@param var outlineColor : Vec3;
		@param var knockOutMul : Int;

		function fragment() {
			var curColor : Vec4 = texture.get(input.uv);

			output.color =
				curColor * knockOutMul * curColor.a // non transparent pixel
				+ vec4(outlineColor,1)
					* ( // Get outline color multiplier based on transparent surrounding pixels
						( 1-curColor.a ) * max(
							texture.get( vec2(input.uv.x+pixelSize.x, input.uv.y) ).a, // left outline
							max(
								texture.get( vec2(input.uv.x-pixelSize.x, input.uv.y) ).a, // right outline
								max(
									texture.get( vec2(input.uv.x, input.uv.y+pixelSize.y) ).a, // top outline
									texture.get( vec2(input.uv.x, input.uv.y-pixelSize.y) ).a // bottom outline
								)
							)
						)
					);
		}
	};
}