/**
	Color abstract type.
	Based on the work from Domagoj Štrekelj (https://code.haxe.org/category/abstract-types/color.html)
**/

package dn;

import dn.M;

enum abstract ColorEnum(Int) to Int {
	var Red = 0xff0000;
	var Green = 0x00ff00;
	var Blue = 0x0000ff;

	var White = 0xffffff;
	var Black = 0x0;
	var MidGray = 0x808080;

	var Yellow = 0xffcc00;
	var Pink = 0xff00ff;
	var Lime = 0xCAFF00;
}

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
		if( s==0 )
			return Col.gray(h);
		else {
			h*=6;
			var i = M.floor(h);
			var c1 = l * (1-s);
			var c2 = l * (1-s * (h-i));
			var c3 = l * (1-s * (1-(h-i)));

			if( i==0 || i==6 )	return fromRGBf(l, c3, c1);
			else if( i==1 )		return fromRGBf(c2, l, c1);
			else if( i==2 )		return fromRGBf(c1, l, c3);
			else if( i==3 )		return fromRGBf(c1, c2, l);
			else if( i==4 )		return fromRGBf(c3, c1, l);
			else 				return fromRGBf(l, c1, c2);
		}
	}

	@:from public static inline function fromColorEnum(c:ColorEnum) {
		return new Col(c);
	}

	/**
		Parse a "#RRGGBB" string.
		If the argument is a constant and not a variable, this call generates no allocation, as an Int value is directly inlined by the macro call itself.
	**/
	@:from public static macro function fromHex(e:haxe.macro.Expr.ExprOf<String>) : ExprOf<Col> {
		function _warnOptim(e:haxe.macro.Expr) {
			haxe.macro.Context.warning("String constant could probably be inlined for performance: use Col.fromHex([stringConst]) here.", e.pos);
		}

		function _checkTernary(eTern:haxe.macro.Expr) {
			switch eTern.expr {
				case ETernary(econd, eif, eelse):
					switch eif.expr {
						case EConst(CString(_)): _warnOptim(eif);
						case ETernary(_): _checkTernary(eif);
						case _:
					}
					switch eelse.expr {
						case EConst(CString(_)): _warnOptim(eelse);
						case ETernary(_): _checkTernary(eelse);
						case _:
					}
				case _:
			}
		}

		switch e.expr {
			case EConst(CString(str,_)):
				var colInt = _fastHexToInt(str);
				if( colInt==-1 )
					haxe.macro.Context.fatalError("Malformed color code (expected: #rrggbb, #rgb or #v)", e.pos);
				return macro $v{colInt}

			case ETernary(econd, eif, eelse):
				_checkTernary(e);
				return macro Col.fromInt( Col._fastHexToInt($e) );

			case EMeta(_):
				_warnOptim(e);
				return macro Col.fromInt( Col._fastHexToInt($e) );

			case _:
				return macro Col.fromInt( Col._fastHexToInt($e) );
		}
	}
	/** Return a "#RRGGBB" string **/
	public inline function toHex(withSharp=true) : String {
		return withSharp ? "#"+StringTools.hex(this, 6) : StringTools.hex(this, 6);
	}
	@:to public static inline function toString(c:Col) : String {
		return c.toHex(true);
	}



	// Hex parser cache
	static var SHARP = "#".charCodeAt(0);
	static var HEX_CHARS = "0123456789ABCDEFabcdef".split("").map( c->c.charCodeAt(0) );
	static var SINGLE_HEX_VALUES = {
		var m = new Map();
		for(hc in HEX_CHARS) {
			var h = String.fromCharCode(hc);
			m.set(hc, Std.parseInt("0x"+h) );
		}
		m;
	}
	static var DOUBLE_HEX_VALUES = {
		var m = new Map();
		for(hc in HEX_CHARS) {
			var h = String.fromCharCode(hc);
			m.set(hc, Std.parseInt("0x"+h+h) );
		}
		m;
	}
	static var TRIPLE_HEX_VALUES = {
		var m = new Map();
		for(hc in HEX_CHARS) {
			var h = String.fromCharCode(hc);
			m.set(hc, Std.parseInt("0x"+ h+h + h+h + h+h) );
		}
		m;
	}

	/**
		Convert a hex String to Int. Supported formats are #aa123456, #123456, #123 and #1. "#" is optional.
		Return -1 if parsing failed
	*/
	@:noCompletion
	public static inline function _fastHexToInt(hex:String) : Int {
		if( hex.length==0 )
			return -1;

		var start = StringTools.fastCodeAt(hex,0)==SHARP ? 1 : 0;
		var l = hex.length-start;

		if( l==6 || l==8 ) {
			// "#123456" or "#aa123456" formats
			var i = 0;
			var out = 0;
			while( i<hex.length-start ) {
				out |= SINGLE_HEX_VALUES.get( StringTools.fastCodeAt(hex, hex.length-1-i) ) << i*4;
				i++;
			}
			return out;
		}
		else if( l==3 ) {
			// "#123" format
			return fromRGBi(
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start) ),
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start+1) ),
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start+2) )
			);
		}
		else if( l==4 ) {
			// "#a123" format
			return fromRGBi(
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start+1) ),
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start+2) ),
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start+3) ),
				DOUBLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start) )
			);
		}
		else if( l==1 ) {
			// "#1" format
			return TRIPLE_HEX_VALUES.get( StringTools.fastCodeAt(hex,start) );
		}
		else
			return -1;
	}


	/** Create a gray Col from a single float value (0.0 = black  =>  0.5 = mid gray =>  1.0 = white)  **/
	@:from public static inline function gray(v:Float) : Col {
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

			return h%1;
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

		var max = r>=g && r>=b ? r : g>=b ? g : b;
		if( max>0 )
			return ( max - ( r<=g && r<=b ? r : g<=b ? g : b ) )  /  max;
		else
			return 0;
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
		return this = fromHsl(hue, saturation, v);
	}


	/** Pad given string value with leading zeros **/
	static inline function pad(s:String, zeros=2) {
		while( s.length<zeros )
			s="0"+s;
		return s;
	}

	/** Perceived luminance (0-1) of given color, based on W3C algorithm. Result is less precise than `luminance`. **/
	public var fastLuminance(get,never) : Float;
	static inline var RED_LUMAi = 299;
	static inline var GREEN_LUMAi = 587;
	static inline var BLUE_LUMAi = 114;
	inline function get_fastLuminance() {
		return ( RED_LUMAi*ri + GREEN_LUMAi*gi + BLUE_LUMAi*bi ) / 1000 / 255;
	}

	/** Perceived luminance (0-1) of given color. Result is better than `fastLuminance`, but slower. **/
	public var luminance(get,never) : Float;
	static inline var RED_LUMAf = 0.299;
	static inline var GREEN_LUMAf = 0.587;
	static inline var BLUE_LUMAf = 0.114;
	inline function get_luminance() {
		return Math.sqrt( RED_LUMAf*(ri*ri) + GREEN_LUMAf*(gi*gi) + BLUE_LUMAf*(bi*bi) ) / 255;
	}


	/** Return White if current color is dark, Black otherwise. **/
	public var autoContrast(get,never) : Col;
	inline function get_autoContrast() {
		return fastLuminance<=0.38 ? White : Black;
	}


	/** Get gray value (0-1), if the color was turned to grayscale using luminance. **/
	public inline function getGrayscaleFactor() : Float {
		return luminance;
	}

	/** Return the grayscale equivalent of current color **/
	public inline function toGrayscale() : Col {
		var f = getGrayscaleFactor();
		return fromRGBf(f,f,f, af);
	}


	/** Return an interpolation to Black, at % ratio **/
	public inline function toBlack(ratio:Float) : Col {
		return
			( ai<<24 ) |
			( M.round(ri*(1-ratio))<<16 ) |
			( M.round(gi*(1-ratio))<<8 ) |
			M.round(bi*(1-ratio));
	}

	/** Interpolate to White, at % ratio **/
	public inline function toWhite(ratio:Float) : Col {
		var r = ri;
		var g = gi;
		var b = bi;
		return
			( ai<<24 ) |
			( M.round(r + (255-r)*ratio)<<16 ) |
			( M.round(g + (255-g)*ratio)<<8 ) |
			( M.round(b + (255-b)*ratio) );
	}

	/** Interpolate to given color, at % ratio **/
	public inline function interpolate(to:Col, ratio:Float) : Col {
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
		var l = fastLuminance;
		if( l<0.65 )
			return interpolate( target.toBlack(1-l/0.65), ratio );
		else
			return interpolate( target.toWhite((l-0.65)/0.35), ratio );
	}


	#if( !macro && heaps )
	/** Apply color to a `h2d.BatchElement` **/
	public inline function colorizeH2dBatchElement(e:h2d.SpriteBatch.BatchElement, ratio=1.0) {
		e.r = M.lerp( 0xffffff, rf, ratio );
		e.g = M.lerp( 0xffffff, gf, ratio );
		e.b = M.lerp( 0xffffff, bf, ratio );
	}

	/** Return a h3d.Matrix to colorize an object **/
	public inline function getColorizeMatrixH2d(ratioNewColor=1.0, ?ratioOldColor:Float) : h3d.Matrix {
		if( ratioOldColor==null )
			ratioOldColor = 1-ratioNewColor;

		var r = ratioNewColor * rf;
		var g = ratioNewColor * gf;
		var b = ratioNewColor * bf;
		var m = [
			ratioOldColor+r, g, b, 0,
			r, ratioOldColor+g, b, 0,
			r, g, ratioOldColor+b, 0,
			0, 0, 0, 1,
		];
		return h3d.Matrix.L(m);
	}

	/** Return a ColorMatrix filter based on current color **/
	public inline function getColorizeFilterH2d(?ratioNewColor=1.0, ?ratioOldColor:Float) : h2d.filter.ColorMatrix {
		return new h2d.filter.ColorMatrix( getColorizeMatrixH2d(ratioNewColor, ratioOldColor) );
	}
	#end
}




#if !macro
@:noCompletion
class UnitTest {
	public static function _test() {
		var c : Col = 0x12ff7f;

		// Implicit casts
		CiAssert.equals( c, "#12ff7f" );
		CiAssert.equals( c, 1245055 );

		// Import methods
		c = 0xff8000;
		CiAssert.equals(c, Col.fromHex("#ff8000"));
		CiAssert.equals(c, Col.fromHsl(30/360,1,1));
		CiAssert.equals(c, Col.fromInt(0xff8000));
		CiAssert.equals(c, Col.fromRGBf(1, 0.5, 0));
		CiAssert.equals(c, Col.fromRGBi(255, 128, 0));

		CiAssert.equals(Col.gray(0), 0x0);
		CiAssert.equals(Col.gray(0), Black);
		CiAssert.equals(Col.gray(0.5), 0x808080);
		CiAssert.equals(Col.gray(0.5), MidGray);
		CiAssert.equals(Col.gray(1), 0xffffff);
		CiAssert.equals(Col.gray(1), White);

		// Hex parsers
		var h = "#ab123456"; CiAssert.equals( Col.fromHex(h), 0xab123456 );
		var h = "#a123"; CiAssert.equals( Col.fromHex(h), 0xaa112233 );
		var h = "#123456"; CiAssert.equals( Col.fromHex(h), 0x123456 );
		var h = "#123"; CiAssert.equals( Col.fromHex(h), 0x112233 );
		var h = "#1"; CiAssert.equals( Col.fromHex(h), 0x111111 );

		// ARGB getters
		c = "#11aabbcc";
		CiAssert.equals( c.ai, 0x11 );
		CiAssert.equals( c.ri, 0xaa );
		CiAssert.equals( c.gi, 0xbb );
		CiAssert.equals( c.bi, 0xcc );
		CiAssert.equals( c.af, 0x11/255 );
		CiAssert.equals( c.rf, 0xaa/255 );
		CiAssert.equals( c.gf, 0xbb/255 );
		CiAssert.equals( c.bf, 0xcc/255 );

		// ARGB setters
		c = "#11aabbcc";
		c.af = 0.0; CiAssert.equals( c, "#aabbcc" );
		c.af = 0.5; CiAssert.equals( c, "#80aabbcc" );
		c.af = 1.0; CiAssert.equals( c, "#ffaabbcc" );
		c = "#11aabbcc";
		c.rf = 0.0; CiAssert.equals( c, "#1100bbcc" );
		c.rf = 0.5; CiAssert.equals( c, "#1180bbcc" );
		c.rf = 1.0; CiAssert.equals( c, "#11ffbbcc" );
		c = "#11aabbcc";
		c.gf = 0.0; CiAssert.equals( c, "#11aa00cc" );
		c.gf = 0.5; CiAssert.equals( c, "#11aa80cc" );
		c.gf = 1.0; CiAssert.equals( c, "#11aaffcc" );
		c = "#11aabbcc";
		c.bf = 0.0; CiAssert.equals( c, "#11aabb00" );
		c.bf = 0.5; CiAssert.equals( c, "#11aabb80" );
		c.bf = 1.0; CiAssert.equals( c, "#11aabbff" );

		// HSL
		CiAssert.equals( { c="#ff0000"; c.hue; }, 0 );
		CiAssert.equals( { c="#00ffff"; c.hue; }, 0.5 );

		CiAssert.equals( { c="#000000"; c.saturation; }, 0 );
		CiAssert.equals( { c="#00ff00"; c.saturation; }, 1 );

		CiAssert.equals( { c="#000000"; c.lightness; }, 0 );
		CiAssert.equals( { c="#ff0000"; c.lightness; }, 1 );

		// Interpolate
		var def : Col = 0xff0000;
		c = def; CiAssert.equals( c.interpolate(0x00ff00, 0.0), 0xff0000 );
		c = def; CiAssert.equals( c.interpolate(0x00ff00, 0.5), 0x808000 );
		c = def; CiAssert.equals( c.interpolate(0x00ff00, 1.0), 0x00ff00 );

		c = def; CiAssert.equals( c.toBlack(0.0), 0xff0000 );
		c = def; CiAssert.equals( c.toBlack(0.5), 0x800000 );
		c = def; CiAssert.equals( c.toBlack(1.0), 0x000000 );

		c = def; CiAssert.equals( c.toWhite(0.0), 0xff0000 );
		c = def; CiAssert.equals( c.toWhite(0.5), 0xff8080 );
		c = def; CiAssert.equals( c.toWhite(1.0), 0xffffff );

		// Luminance
		c = 0x000000; CiAssert.equals( M.pretty(c.luminance,2), 0 );
		c = 0x808080; CiAssert.equals( M.pretty(c.luminance,2), 0.5 );
		c = 0xffffff; CiAssert.equals( M.pretty(c.luminance,2), 1 );
		c = 0xff0000; CiAssert.equals( M.pretty(c.luminance,2), 0.55 );
		c = 0x00ff00; CiAssert.equals( M.pretty(c.luminance,2), 0.77 );
		c = 0x0000ff; CiAssert.equals( M.pretty(c.luminance,2), 0.34 );

		// Grayscale
		c = 0x000000; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0 );
		c = 0x808080; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.5 );
		c = 0xffffff; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 1 );
		c = 0xff0000; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.30 );
		c = 0x00ff00; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.59 );
		c = 0x0000ff; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.11 );

		c = 0x000000; CiAssert.equals( c.toGrayscale(), 0x000000 );
		c = 0xff0000; CiAssert.equals( c.toGrayscale(), 0x4c4c4c );
		c = 0x00ff00; CiAssert.equals( c.toGrayscale(), 0x969696 );
		c = 0x0000ff; CiAssert.equals( c.toGrayscale(), 0x1d1d1d );

		// Alpha
		CiAssert.equals( Col.fromInt(0x112233).withAlpha(), 0xff112233);
		CiAssert.equals( Col.fromInt(0x112233).withAlpha(0.5), 0x80112233);
		CiAssert.equals( Col.fromInt(0xff112233).withoutAlpha(), 0x112233);
		CiAssert.equals( Col.fromInt(0x112233).withoutAlpha(), 0x112233);

		// Enum
		c = "#ff0000"; CiAssert.equals(Red, c);
		c = "#00ff00"; CiAssert.equals(Green, c);
		c = "#0000ff"; CiAssert.equals(Blue, c);
		c = 0xffffff; CiAssert.equals(White, c);
		c = 0x0; CiAssert.equals(Black, c);
	}
}
#end