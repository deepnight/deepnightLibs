package dn.heaps.filter;


/**
	Add a 1px pixel-perfect outline around h2d.Object
**/
class PixelOutline extends h2d.filter.Shader<InternalShader> {
	/** Outline color (0xRRGGBB) **/
	public var color(default, set) : Int;
	public var alpha(default, set) : Float;

	/** If TRUE, the original object pixels are discarded, and only the outline remains **/
	public var knockOut(default,set) : Bool;

	/** Add a pixel-perfect outline around a h2d.Object using a shader filter **/
	public function new(color=0x0, ?a=1.0, knockOut=false) {
		super( new InternalShader() );
		this.color = color;
		alpha = a;
		smooth = false;
		this.knockOut = knockOut;
	}

	inline function set_color(v:Int) {
		color = v;
		shader.outlineColor = hxsl.Types.Vec.fromColor(color);
		shader.outlineColor.a = alpha;
		return v;
	}

	inline function set_alpha(v:Float) {
		alpha = v;
		shader.outlineColor.a = v;
		return v;
	}

	inline function set_knockOut(v) {
		knockOut = v;
		shader.knockOutMul = knockOut ? 0 : 1;
		return v;
	}

	override function sync(ctx : h2d.RenderContext, s : h2d.Object) {
		super.sync(ctx, s);
		boundsExtend = 1;
	}

	override function draw(ctx : h2d.RenderContext, t : h2d.Tile) {
		shader.texelSize.set( 1/t.width, 1/t.height );
		return super.draw(ctx,t);
	}
}


// --- Shader -------------------------------------------------------------------------------
private class InternalShader extends h3d.shader.ScreenShader {
	static var SRC = {
		@param var texture : Sampler2D;
		@param var texelSize : Vec2;
		@param var outlineColor : Vec4;
		@const var knockOutMul : Int;

		function fragment() {
			var curColor : Vec4 = texture.get(input.uv);

			var onEdge = ( // Get outline color multiplier based on transparent surrounding pixels
				( 1-curColor.a ) * max(
					texture.get( vec2(input.uv.x+texelSize.x, input.uv.y) ).a, // left outline
					max(
						texture.get( vec2(input.uv.x-texelSize.x, input.uv.y) ).a, // right outline
						max(
							texture.get( vec2(input.uv.x, input.uv.y+texelSize.y) ).a, // top outline
							texture.get( vec2(input.uv.x, input.uv.y-texelSize.y) ).a // bottom outline
						)
					)
				)
			);

			// Apply color, including outline alpha
			var a = max(onEdge*outlineColor.a, curColor.a);
			output.color = vec4(
				mix( curColor.rgb, outlineColor.rgb, onEdge )*a,
				a
			);
		}
	};
}