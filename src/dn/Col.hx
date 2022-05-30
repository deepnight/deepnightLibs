/**
	Color abstract type.
	Based on the work from Domagoj Štrekelj (https://code.haxe.org/category/abstract-types/color.html)
**/

package dn;

import dn.M;

abstract Col(Int) from Int to Int {
	public inline function new(rgb:Int) {
		this = rgb;
	}

	/** Create a random color using HSL **/
	public static inline function randomHSL(?hue:Float, ?sat:Float, ?lum:Float) : Col {
		return fromHsl(
			hue!=null ? hue : Math.random(),
			sat!=null ? sat : Math.random(),
			lum!=null ? lum : Math.random()
		);
	}

	/** Create a random color using RGB **/
	public static inline function randomRGB(?r:Float, ?g:Float, ?b:Float) : Col {
		return fromRGBf(
			r!=null ? r : Math.random(),
			g!=null ? g : Math.random(),
			b!=null ? b : Math.random()
		);
	}

	public static inline function fromInt(c:Int) : Col {
		return new Col(c);
	}

	/** Create a color from RGB (0-255) values **/
	public static inline function fromRGBi(r:Int, g:Int, b:Int, a=0) : Col {
		return new Col( (a<<24) | (r<<16) | (g<<8) | b );
	}

	/** Create a color from RGB (0-1.0) values **/
	public static inline function fromRGBf(r:Float, g:Float, b:Float, a=0.) : Col {
		return Col.fromRGBi( M.round(r*255), M.round(g*255), M.round(b*255), M.round(a*255) );
	}

	/** Create a color from HSL (0-1.0) values **/
	public static inline function fromHsl(h:Float, s:Float, l:Float) : Col {
		if( l<=0 )
			return new Col(0x0);
		else if( s<=0 )
			return Col.fromFloat(h);
		else {
			var r = 0.;
			var g = 0.;
			var b = 0.;

			h*=6;
			var i = M.floor(h);
			final c1 = l * (1 - s);
			final c2 = l * (1 - s * (h-i));
			final c3 = l * (1 - s * (1 - (h-i)));

			if( i==0 || i==6 )	{ r = l; g = c3; b = c1; }
			else if( i==1 )		{ r = c2; g = l; b = c1; }
			else if( i==2 )		{ r = c1; g = l; b = c3; }
			else if( i==3 )		{ r = c1; g = c2; b = l; }
			else if( i==4 )		{ r = c3; g = c1; b = l; }
			else 				{ r = l; g = c1; b = c2; }

			return fromRGBf(r,g,b);
		}
	}

	/**
		Parse a "#RRGGBB" string.
		If the argument is a constant and not a variable, this call generates no allocation, as an Int value is directly inlined by the macro call itself.
	**/
	@:from public static macro function fromHex(e:haxe.macro.Expr.ExprOf<String>) : ExprOf<Col> {
		switch e.expr {
			case EConst(CString(str,_)):
				var clean = _cleanUpHex(str,false);
				if( clean==null )
					haxe.macro.Context.fatalError("Malformed color code (expected: #rrggbb, #rgb or #v)", e.pos);
				var colInt = Std.parseInt("0x"+clean);
				return macro Col.fromInt( $v{colInt} );

			case _:
				return macro Std.parseInt("0x"+$e.substr(1));
		}
	}
	/** Return a "#RRGGBB" string **/
	@:to public static inline function toHex(c:Col) : String {
		return "#"+StringTools.hex(c, 6);
	}
	/** Turn an hex string to [#]rrggbb format (supports #rrggbb, #rgb and #v formats) **/
	static function _cleanUpHex(hex:String, includeSharp=true) : Null<String> {
		hex = hex==null ? "" : StringTools.trim(hex);
		var reg = ~/^#*([0-9abcdef]{8})|^#*([0-9abcdef]{6})|^#*([0-9abcdef]{3})$|^#*([0-9abcdef]{1})$/gi;
		if( reg.match(hex) ) {
			return
				( includeSharp ? "#" : "" )
				+ ( reg.matched(4)!=null
					? { var c = reg.matched(4); c+c + c+c + c+c; }
					: reg.matched(3)!=null
						? { var c = reg.matched(3); c.charAt(0)+c.charAt(0) + c.charAt(1)+c.charAt(1) + c.charAt(2)+c.charAt(2); }
						: reg.matched(2)!=null
							? reg.matched(2)
							: reg.matched(1)
				);
		}
		else
			return null;
	}


	/** Create a Col from a single float value (0.0 = 0x0  =>  0.5 = 0x7f7f7f  =>  1.0 = 0xffffff)  **/
	@:from public static inline function fromFloat(v:Float) : Col {
		return fromRGBf(v,v,v);
	}




	/** Red channel as Int (0-255) **/
	public var ri(get, set) : Int;
		inline function get_ri() return (this >> 16) & 0xff;
		inline function set_ri(ri:Int) { this = fromRGBi(ri, gi, bi, ai); return ri; }

	/** Green channel as Int (0-255) **/
	public var gi(get, set) : Int;
		inline function get_gi() return (this >> 8) & 0xff;
		inline function set_gi(gi:Int) { this = fromRGBi(ri, gi, bi, ai); return gi; }

	/** Blue channel as Int (0-255) **/
	public var bi(get, set) : Int;
		inline function get_bi() return this & 0xff;
		inline function set_bi(bi:Int) { this = fromRGBi(ri, gi, bi, ai); return bi; }

		/** Alpha channel as Int (0-255) **/
	public var ai(get, set) : Int;
		inline function get_ai() return (this >> 24) & 0xff;
		inline function set_ai(ai:Int) { this = fromRGBi(ri, gi, bi, ai); return ai; }



	/** Red channel as Float (0-1) **/
	public var rf(get, set) : Float;
		inline function get_rf() return ri/255;
		inline function set_rf(rf:Float) { this = fromRGBf(rf, gf, bf, af); return rf; }

	/** Green channel as Float (0-1) **/
	public var gf(get, set) : Float;
		inline function get_gf() return gi/255;
		inline function set_gf(gf:Float) { this = fromRGBf(rf, gf, bf, af); return gf; }

	/** Blue channel as Float (0-1) **/
	public var bf(get, set) : Float;
		inline function get_bf() return bi/255;
		inline function set_bf(bf:Float) { this = fromRGBf(rf, gf, bf, af); return bf; }

	/** Alpha channel as Float (0-1) **/
	public var af(get, set) : Float;
		inline function get_af() return ai/255;
		inline function set_af(af:Float) { this = fromRGBf(rf, gf, bf, af); return af; }


	/** Return color with given alpha (0-1) **/
	public inline function withAlpha(a=1.0) {
		return M.round(a*255) << 24 | withoutAlpha();
	}

	/** Return color without alpha **/
	public inline function withoutAlpha() {
		return this & 0xffffff;
	}


	/** Hue value (from HSL format) **/
	public var hue(get,set) : Float;
	inline function get_hue() {
		var max = rf>=gf && rf>=bf ? rf : gf>=bf ? gf : bf;
		var delta = max - ( rf<=gf && rf<=bf ? rf : gf<=bf ? gf : bf ); // max-min

		if( delta==0 )
			return 0.;
		else {
			var h = 0.;
			var dr = ( (max-rf)/6 + (delta/2) ) / delta;
			var dg = ( (max-gf)/6 + (delta/2) ) / delta;
			var db = ( (max-bf)/6 + (delta/2) ) / delta;

			if( rf==max ) h = db-dg;
			else if( gf==max ) h = 1/3 + dr-db;
			else if( bf==max ) h = 2/3 + dg-dr;

			if( h<0 ) h++;
			if( h>1 ) h--;

			return h;
		}
	}
	inline function set_hue(v) {
		return this = fromHsl(v, saturation, lightness);
	}


	/** Saturation value (from HSL format) **/
	public var saturation(get,set) : Float;
	inline function get_saturation() {
		var r = rf;
		var g = gf;
		var b = bf;

		var min = r<=g && r<=b ? r : g<=b ? g : b;
		var max = r>=g && r>=b ? r : g>=b ? g : b;
		var delta = max-min;

		return max==0 ? 0 : delta/max;
	}
	inline function set_saturation(v:Float) {
		return this = fromHsl(hue, v, lightness);
	}


	/** Lightness value (from HSL format) **/
	public var lightness(get,set) : Float;
	inline function get_lightness() {
		var r = rf;
		var g = gf;
		var b = bf;
		return r>=g && r>=b ? r : g>=b ? g : b;
	}
	inline function set_lightness(v:Float) {
		if( v<=0 )
			return this = 0x0;
		else
			return this = fromHsl(hue, saturation, v);
	}


	/** Pad given string value with leading zeros **/
	static inline function pad(s:String, zeros=2) {
		while( s.length<zeros )
			s="0"+s;
		return s;
	}

	/** Perceived luminance of given color (0-1) **/
	public var luminance(get,never) : Float;
	static final RED_LUMA = 0.299;
	static final GREEN_LUMA = 0.587;
	static final BLUE_LUMA = 0.114;
	inline function get_luminance() return Math.sqrt( RED_LUMA*(ri*ri) + GREEN_LUMA*(gi*gi) + BLUE_LUMA*(bi*bi) ) / 255;


	/** Get gray value (0-1), if the color was turned to grayscale using luminance. **/
	public inline function getGrayscaleFactor() : Float {
		return RED_LUMA*rf + GREEN_LUMA*gf + BLUE_LUMA*bf;
	}

	/** Return the grayscale equivalent of current color **/
	public inline function toGrayscale() : Col {
		var f = getGrayscaleFactor();
		return fromRGBf(f,f,f, af);
	}


	/** Return an interpolation to Black, at % ratio **/
	public inline function toBlack(ratio:Float) : Col {
		if( ratio<=0 )
			return new Col(this);
		else {
			var black = new Col(0x0);
			black.af = af;
			if( ratio>=1 )
				return black;
			else
				return
					( ai<<24 ) |
					( M.round(ri*(1-ratio))<<16 ) |
					( M.round(gi*(1-ratio))<<8 ) |
					M.round(bi*(1-ratio));
		}
	}

	/** Interpolate to White, at % ratio **/
	public inline function toWhite(ratio:Float) : Col {
		var white : Col = 0xffffff;
		white.af = af;
		return interpolate(white, ratio);
	}

	/** Interpolate to given color, at % ratio **/
	public inline function interpolate(to:Col, ratio:Float) : Col {
		if( ratio==0 )
			return new Col(this);
		else if( ratio>=1 )
			return to;
		else
			return
				( M.round( M.lerp( ai, to.ai, ratio ) ) << 24 ) |
				( M.round( M.lerp( ri, to.ri, ratio ) ) << 16 ) |
				( M.round( M.lerp( gi, to.gi, ratio ) ) << 8 ) |
				( M.round( M.lerp( bi, to.bi, ratio ) ) );
	}


	/**
		Return current color teinted to `target`, approximately preserving luminance of original color.
	**/
	public inline function teint(target:Col, ratio:Float) : Col {
		if( ratio==0 )
			return new Col(this);
		else {
			var l = luminance;
			if( l<0.65 )
				target = target.toBlack(1-l/0.65);
			else
				target = target.toWhite((l-0.65)/0.35);
			return interpolate(target, ratio);
		}
	}
}




#if !macro
@:noCompletion
class UnitTest {
	public static function _test() {
		var c : Col = 0x12ff7f;

		// Implicit casts
		dn.CiAssert.equals( c, "#12ff7f" );
		dn.CiAssert.equals( c, 1245055 );

		// Hex parsers
		dn.CiAssert.equals( Col.fromHex("#ab123456"), 0xab123456 );
		dn.CiAssert.equals( Col.fromHex("#123456"), 0x123456 );
		dn.CiAssert.equals( Col.fromHex("#123"), 0x112233 );
		dn.CiAssert.equals( Col.fromHex("#1"), 0x111111 );

		// ARGB getters
		c = "#11aabbcc";
		dn.CiAssert.equals( c.ai, 0x11 );
		dn.CiAssert.equals( c.ri, 0xaa );
		dn.CiAssert.equals( c.gi, 0xbb );
		dn.CiAssert.equals( c.bi, 0xcc );
		dn.CiAssert.equals( c.af, 0x11/255 );
		dn.CiAssert.equals( c.rf, 0xaa/255 );
		dn.CiAssert.equals( c.gf, 0xbb/255 );
		dn.CiAssert.equals( c.bf, 0xcc/255 );

		// ARGB setters
		c = "#11aabbcc";
		c.af = 0.0; dn.CiAssert.equals( c, "#aabbcc" );
		c.af = 0.5; dn.CiAssert.equals( c, "#80aabbcc" );
		c.af = 1.0; dn.CiAssert.equals( c, "#ffaabbcc" );
		c = "#11aabbcc";
		c.rf = 0.0; dn.CiAssert.equals( c, "#1100bbcc" );
		c.rf = 0.5; dn.CiAssert.equals( c, "#1180bbcc" );
		c.rf = 1.0; dn.CiAssert.equals( c, "#11ffbbcc" );
		c = "#11aabbcc";
		c.gf = 0.0; dn.CiAssert.equals( c, "#11aa00cc" );
		c.gf = 0.5; dn.CiAssert.equals( c, "#11aa80cc" );
		c.gf = 1.0; dn.CiAssert.equals( c, "#11aaffcc" );
		c = "#11aabbcc";
		c.bf = 0.0; dn.CiAssert.equals( c, "#11aabb00" );
		c.bf = 0.5; dn.CiAssert.equals( c, "#11aabb80" );
		c.bf = 1.0; dn.CiAssert.equals( c, "#11aabbff" );

		// HSL
		dn.CiAssert.equals( { c="#ff0000"; c.hue; }, 0 );
		dn.CiAssert.equals( { c="#00ffff"; c.hue; }, 0.5 );

		dn.CiAssert.equals( { c="#000000"; c.saturation; }, 0 );
		dn.CiAssert.equals( { c="#00ff00"; c.saturation; }, 1 );

		dn.CiAssert.equals( { c="#000000"; c.lightness; }, 0 );
		dn.CiAssert.equals( { c="#ff0000"; c.lightness; }, 1 );

		// Interpolate
		var def : Col = 0xff0000;
		c = def; dn.CiAssert.equals( c.interpolate(0x00ff00, 0.0), 0xff0000 );
		c = def; dn.CiAssert.equals( c.interpolate(0x00ff00, 0.5), 0x808000 );
		c = def; dn.CiAssert.equals( c.interpolate(0x00ff00, 1.0), 0x00ff00 );

		c = def; dn.CiAssert.equals( c.toBlack(0.0), 0xff0000 );
		c = def; dn.CiAssert.equals( c.toBlack(0.5), 0x800000 );
		c = def; dn.CiAssert.equals( c.toBlack(1.0), 0x000000 );

		c = def; dn.CiAssert.equals( c.toWhite(0.0), 0xff0000 );
		c = def; dn.CiAssert.equals( c.toWhite(0.5), 0xff8080 );
		c = def; dn.CiAssert.equals( c.toWhite(1.0), 0xffffff );

		// Luminance
		c = 0x000000; dn.CiAssert.equals( M.pretty(c.luminance,2), 0 );
		c = 0x808080; dn.CiAssert.equals( M.pretty(c.luminance,2), 0.5 );
		c = 0xffffff; dn.CiAssert.equals( M.pretty(c.luminance,2), 1 );
		c = 0xff0000; dn.CiAssert.equals( M.pretty(c.luminance,2), 0.55 );
		c = 0x00ff00; dn.CiAssert.equals( M.pretty(c.luminance,2), 0.77 );
		c = 0x0000ff; dn.CiAssert.equals( M.pretty(c.luminance,2), 0.34 );

		// Grayscale
		c = 0x000000; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0 );
		c = 0x808080; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.5 );
		c = 0xffffff; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 1 );
		c = 0xff0000; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.30 );
		c = 0x00ff00; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.59 );
		c = 0x0000ff; dn.CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.11 );

		c = 0x000000; dn.CiAssert.equals( c.toGrayscale(), 0x000000 );
		c = 0xff0000; dn.CiAssert.equals( c.toGrayscale(), 0x4c4c4c );
		c = 0x00ff00; dn.CiAssert.equals( c.toGrayscale(), 0x969696 );
		c = 0x0000ff; dn.CiAssert.equals( c.toGrayscale(), 0x1d1d1d );
	}
}
#end