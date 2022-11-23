/**
	Color abstract type.
	Based on the work from Domagoj Štrekelj (https://code.haxe.org/category/abstract-types/color.html)
**/

package dn;

import dn.M;

enum abstract ColorEnum(Int) to Int to Col {
	var Red = 0xff0000;
	var Green = 0x00ff00;
	var Blue = 0x0000ff;

	var White = 0xffffff;
	var Black = 0x0;
	var MidGray = 0x808080;

	var ColdLightGray = 0xadb4cc;
	var ColdMidGray = 0x6a6e80;
	var WarmLightGray = 0xccc3b8;
	var WarmMidGray = 0x807a73;

	var Orange = 0xff8800;
	var Yellow = 0xffcc00;
	var Pink = 0xff00ff;
	var Lime = 0xCAFF00;
}

abstract Col(Int) from Int to Int {
	public inline function new(rgb:Int) {
		this = rgb;
	}


	public static inline function white(withAlpha=false) return _colorEnumWithAlpha(White, withAlpha);
	public static inline function black(withAlpha=false) return _colorEnumWithAlpha(Black, withAlpha);

	public static inline function midGray(withAlpha=false) return _colorEnumWithAlpha(MidGray, withAlpha);
	public static inline function coldLightGray(withAlpha=false) return _colorEnumWithAlpha(ColdLightGray, withAlpha);
	public static inline function coldMidGray(withAlpha=false) return _colorEnumWithAlpha(ColdMidGray, withAlpha);
	public static inline function warmLightGray(withAlpha=false) return _colorEnumWithAlpha(WarmLightGray, withAlpha);
	public static inline function warmMidGray(withAlpha=false) return _colorEnumWithAlpha(WarmMidGray, withAlpha);

	public static inline function red(withAlpha=false) return _colorEnumWithAlpha(Red, withAlpha);
	public static inline function green(withAlpha=false) return _colorEnumWithAlpha(Green, withAlpha);
	public static inline function blue(withAlpha=false) return _colorEnumWithAlpha(Blue, withAlpha);

	public static inline function pink(withAlpha=false) return _colorEnumWithAlpha(Pink, withAlpha);
	public static inline function yellow(withAlpha=false) return _colorEnumWithAlpha(Yellow, withAlpha);
	public static inline function lime(withAlpha=false) return _colorEnumWithAlpha(Lime, withAlpha);

	static inline function _colorEnumWithAlpha(c:ColorEnum, withAlpha:Bool) : Col {
		return withAlpha ? cast(c, Col).withAlpha(1) : c;
	}


	/** Create a gray Col from a single float value (0.0 = black  =>  0.5 = mid gray =>  1.0 = white)  **/
	@:from public static inline function gray(v:Float) : Col {
		return fromRGBf(v,v,v);
	}

	/** Create a "warm" gray Col from a single float value (0.0 = black  =>  0.5 = mid warm gray =>  1.0 = white)  **/
	public static inline function warmGray(lightness:Float) {
		return lightness>=0.5
			? warmMidGray(false).toWhite( (lightness-0.5)/0.5 )
			: warmMidGray(false).toBlack( 1-lightness/0.5 );
	}

	/** Create a "cold" gray Col from a single float value (0.0 = black  =>  0.5 = mid cold gray =>  1.0 = white)  **/
	public static inline function coldGray(lightness:Float) {
		return lightness>=0.5
			? coldMidGray(false).toWhite( (lightness-0.5)/0.5 )
			: coldMidGray(false).toBlack( 1-lightness/0.5 );
	}


	/** Return a new instance of the same color **/
	public inline function clone() return new Col(this);

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

	@:from public static inline function fromColorEnum(c:ColorEnum) : Col {
		return c;
	}




	#if macro
	static function _failToInlineHex(e:haxe.macro.Expr) {
		haxe.macro.Context.fatalError("This expression should be a constant or conditions with constants.", e.pos);
	}

	static function _parseAndInlineHex(hex:String, pos:haxe.macro.Expr.Position) : Int {
		var colInt = try parseHex(hex) catch(_) haxe.macro.Context.fatalError("Malformed hex color", pos);
		if( colInt==-1 )
			haxe.macro.Context.fatalError("Malformed color code (expected: #rrggbb, #rgb or #v)", pos);
		return colInt;
	}

	static function _inlineIfExpr(eTern:haxe.macro.Expr) {
		switch eTern.expr {
			case ETernary(econd, eif, eelse), EIf(econd, eif, eelse):
				_inlineBlockExpr(eif);
				_inlineBlockExpr(eelse);

			case _:
				_failToInlineHex(eTern);

		}
	}

	static function _inlineBlockExpr(eblock:haxe.macro.Expr) {
		switch eblock.expr {
			case EConst(CString(str,_)):
				// Inline constant string
				eblock.expr = ( macro $v{ _parseAndInlineHex(str, eblock.pos) } ).expr;

			case ETernary(_), EIf(_):
				// Inline another IF recursively
				_inlineIfExpr(eblock);

			case EConst(CIdent(id)):
				var startsWithCapReg = ~/^_*[A-Z]/g;
				if( startsWithCapReg.match(id) ) {
					// Assume that identifiers are ColorEnums. If proven wrongn, this will just fail later.
					var identExpr : haxe.macro.Expr = {
						expr: EConst(CIdent(id)),
						pos: eblock.pos,
					}
					eblock.expr = ( macro Col.fromColorEnum($identExpr) ).expr;
				}
				else
					_failToInlineHex(eblock);

			case EConst(CInt(_)):
				// Keep integer constant as-is

			case EMeta(_):
				// This can happen when using implicit String to Col cast, with a nested condition
				// Ex: `myMethodThatExpectsCol( i==0 ? Red : "#fc0" );`
				//   The "#fc0" cannot be implicitely inlined.
				haxe.macro.Context.fatalError("Use `Col.inlineHex()` here: this String constant could not be automatically inlined.", eblock.pos);

			case _:
				// Unknown!
				_failToInlineHex(eblock);
		}
	}
	#end



	/**
		Parse a "#RRGGBB"/"#RGB"/"#V" constant string at compilation time and inline the result. This method supports nested conditions. Examples:

		```haxe
		Col.inlineHex("#fc0");
			// becomes: 16763904
		Col.inlineHex( i==0 ? "#fc0" : i==1 ? "#00f" : "#000" )
			// becomes: if(i==0) 16763904 else if( i==1 ) 255 else 0
		```
	**/
	@:from public static macro function inlineHex(e:haxe.macro.Expr.ExprOf<String>) : ExprOf<Col> {
		_inlineBlockExpr(e);
		return macro cast($e, Col);
	}


	/** Return a "[#]RRGGBB" string **/
	public inline function toHex(withSharp=true) : String {
		return withSharp ? "#"+StringTools.hex(this, 6) : StringTools.hex(this, 6);
	}
	@:to public static inline function toString(c:Col) : String {
		return c.toHex(true);
	}


	/** Explicit Int cast **/
	public inline function toInt() : Int {
		return this;
	}

	/** HXSL Vec4 **/
	#if heaps
	public inline function toShaderVec4() : hxsl.Types.Vec {
		return hxsl.Types.Vec.fromColor(this);
	}
	#end
	/** HXSL Vec4 **/
	#if heaps
	public inline function toShaderVec3() : hxsl.Types.Vec {
		return hxsl.Types.Vec.fromColor( withoutAlpha() );
	}
	#end


	// Hex parser cache
	static var SHARP = "#".charCodeAt(0);
	static var HEX_CHARS = "0123456789ABCDEFabcdef".split("").map( c->c.charCodeAt(0) );
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
		Convert a hex String to Int. Supported formats are #aarrggbb, #rrggbb, #argb, #rgb and #v. "#" is optional.

		Because this methods works with String objects (slow and has memory allocations), it's HIGHLY recommended to use Col.inlineHex() when working with constant Strings.

		This method returns -1 if parsing failed.
	*/
	public static inline function parseHex(hex:String) : Col {
		if( hex.length==0 )
			return -1;

		var start = StringTools.fastCodeAt(hex,0)==SHARP ? 1 : 0;
		var l = hex.length-start;

		if( l==6 || l==8 ) {
			// "#123456" or "#aa123456" formats
			#if js
			// In JS, the js.Lib.parseInt returns UInt.
			var v : UInt = Std.parseInt( "0x" + ( start>0 ? hex.substr(start) : hex ) );
			var out : Int = (cast v :Int) & 0xffffffff;
			return out;
			#else
			return Std.parseInt( "0x" + ( start>0 ? hex.substr(start) : hex ) );
			#end
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


	/** Return some approximate RGB distance (0-1) between current color and another one **/
	public inline function getDistanceRgb(target:Col) : Float {
		return ( M.fabs(target.rf-rf) + M.fabs(target.gf-gf) + M.fabs(target.bf-bf) ) / 3;
	}




	public inline function toLab() : dn.struct.FixedArray<Float> {
		var r = (rf > 0.04045) ? Math.pow((rf + 0.055) / 1.055, 2.4) : rf / 12.92;
		var g = (gf > 0.04045) ? Math.pow((gf + 0.055) / 1.055, 2.4) : gf / 12.92;
		var b = (bf > 0.04045) ? Math.pow((bf + 0.055) / 1.055, 2.4) : bf / 12.92;

		var x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
		var y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;
		var z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

		x = (x > 0.008856) ? Math.pow(x, 1/3) : (7.787 * x) + 16/116;
		y = (y > 0.008856) ? Math.pow(y, 1/3) : (7.787 * y) + 16/116;
		z = (z > 0.008856) ? Math.pow(z, 1/3) : (7.787 * z) + 16/116;

		var lab = new dn.struct.FixedArray(3);
		lab.push( (116*y) - 16 );
		lab.push( 500*(x-y) );
		lab.push( 200*(y-z) );
		return lab;
	}


	public inline function getDistanceLab(target:Col) : Float {
		var from = toLab();
		var to = target.toLab();
		return Math.sqrt( M.pow(from.get(0)-to.get(0), 2)  +  M.pow(from.get(1)-to.get(1), 2)  +  M.pow(from.get(2)-to.get(2), 2) );
	}

	/** Return color with given alpha (0-1) **/
	public inline function withAlpha(a:Float) : Col {
		return M.round(a*255) << 24 | withoutAlpha();
	}

	/** Return color with either the given alpha value (0-1), or the current color alpha, if it is not zero. **/
	public inline function withAlphaIfMissing(a=1.0) : Col {
		return af!=0 ? clone() : withAlpha(a);
	}

	/** Return color without alpha **/
	public inline function withoutAlpha() : Col {
		return this & 0xffffff;
	}

	/** Remove alpha channel of given color **/
	public static inline function removeAlpha(c:Col) : Col {
		return c.withoutAlpha();
	}

	/** Get alpha channel as Float **/
	public static inline function getAlphaf(c:Col) : Float {
		return c.af;
	}


	public inline function multiplyRGB(f:Float) {
		var c = clone();
		c.rf*=f;
		c.gf*=f;
		c.bf*=f;
		return c;
	}

	public inline function incRGB(v:Float) {
		var c = clone();
		c.rf = M.fclamp( c.rf + v, 0, 1 );
		c.gf = M.fclamp( c.gf + v, 0, 1 );
		c.bf = M.fclamp( c.bf + v, 0, 1 );
		return c;
	}


	/** Return a variation of this color using HSL **/
	public inline function adjustHsl(deltaH:Float, deltaS:Float, deltaL:Float) : Col {
		var c = clone();
		var a = c.af; // preserve alpha

		c.hue += deltaH;
		c.saturation += deltaS;
		c.lightness += deltaL;

		c.af = a;
		return c;
	}


	public inline function adjustBrightness(delta:Float) : Col {
		var c = clone();
		var a = c.af; // preserve alpha

		if( delta<0 ) {
			// Darken
			var l = c.lightness;
			l = M.fmax(l+delta, 0);
			c.lightness = l;
		}
		else {
			// Brighten
			var l = c.lightness;
			var maxDist = 1-l;
			if( maxDist>delta )
				l += delta;
			else {
				l = 1;
				var s = c.saturation;
				s -= delta-maxDist;
				if( s<0 ) s = 0;
				c.saturation = s;
			}
			c.lightness = l;
		}
		c.af = a;
		return c;
	}


	/** Hue value (0-1, from HSL format) **/
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


	/** Saturation value (0-1, from HSL format) **/
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


	/** Lightness value (0-1, from HSL format) **/
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


	/** Return an inverted version of current color **/
	public inline function invert() : Col {
		return fromRGBf(1-rf, 1-gf, 1-bf, af);
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

	/** Interpolate to given color, at % ratio (this method is an alias of `Col.interpolate()`) **/
	public inline function to(to:Col, ratio:Float) return interpolate(to,ratio);

	/** Interpolate to given color, at % ratio **/
	public inline function interpolate(to:Col, ratio:Float) : Col {
		return
			( M.round( M.lerp( ai, to.ai, ratio ) ) << 24 ) |
			( M.round( M.lerp( ri, to.ri, ratio ) ) << 16 ) |
			( M.round( M.lerp( gi, to.gi, ratio ) ) << 8 ) |
			( M.round( M.lerp( bi, to.bi, ratio ) ) );
	}


	/** Return an interpolated color from min->med->max, using given ratio **/
	public static inline function graduate(ratio:Float, min:Col, med:Col, max:Col) {
		return ratio<0.5 ? min.interpolate( med, ratio/0.5 ) : med.interpolate( max, (ratio-0.5)/0.5 );
	}


	/**
		Return current color teinted to `target`, approximately preserving luminance of original color.
	**/
	public inline function teint(target:Col, ratio:Float, customLum=-1.) : Col {
		var l = customLum<0 ? fastLuminance : customLum;
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

	/** Apply color to a Drawable using its Vector color **/
	public inline function colorizeH2dDrawable(e:h2d.Drawable, ratio=1.0) {
		e.color.setColor( withAlpha(ratio) );
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

	/** Create a `h2d.Bitmap` of the given color **/
	public static inline function makeBitmap(col:Col, wid:Float, hei:Float, xr=0., yr=0., ?p:h2d.Object) : h2d.Bitmap {
		var t = h2d.Tile.fromColor(col);
		t.setCenterRatio(xr,yr);
		var b = new h2d.Bitmap(t, p);
		b.scaleX = wid;
		b.scaleY = hei;
		return b;
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
		CiAssert.equals(c, Col.parseHex("#ff8000"));
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
		var h = "#ab123456"; CiAssert.equals( Col.parseHex(h), 0xab123456 );
		var h = "#a123"; CiAssert.equals( Col.parseHex(h), 0xaa112233 );
		var h = "#123456"; CiAssert.equals( Col.parseHex(h), 0x123456 );
		var h = "#123"; CiAssert.equals( Col.parseHex(h), 0x112233 );
		var h = "#1"; CiAssert.equals( Col.parseHex(h), 0x111111 );

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

		CiAssert.equals( Col.graduate(0.0, Red, Green, Blue), Red );
		CiAssert.equals( Col.graduate(0.5, Red, Green, Blue), Green );
		CiAssert.equals( Col.graduate(1.0, Red, Green, Blue), Blue );
		CiAssert.equals( Col.graduate(0.25, Red, Green, Blue), 0x808000 );

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
		c = 0xff0000; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.55 );
		c = 0x00ff00; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.77 );
		c = 0x0000ff; CiAssert.equals( M.pretty(c.getGrayscaleFactor(),2), 0.34 );

		c = 0xff0000; CiAssert.equals( c.toGrayscale(), 0x8b8b8b );
		c = 0x00ff00; CiAssert.equals( c.toGrayscale(), 0xc3c3c3 );
		c = 0x0000ff; CiAssert.equals( c.toGrayscale(), 0x565656 );

		c = 0x000000; CiAssert.equals( c.toGrayscale(), 0x000000 );
		c = 0x444444; CiAssert.equals( c.toGrayscale(), 0x444444 );
		c = 0x808080; CiAssert.equals( c.toGrayscale(), 0x808080 );
		c = 0xaaaaaa; CiAssert.equals( c.toGrayscale(), 0xaaaaaa );
		c = 0xffffff; CiAssert.equals( c.toGrayscale(), 0xffffff );

		// Luminance
		CiAssert.equals( M.pretty( Col.fromInt(0x000000).luminance ), 0 );
		CiAssert.equals( M.pretty( Col.fromInt(0xffffff).luminance ), 1 );
		CiAssert.equals( M.pretty( Col.fromInt(0xff0000).luminance, 2 ), 0.55 );
		CiAssert.equals( M.pretty( Col.fromInt(0x00ff00).luminance, 2 ), 0.77 );
		CiAssert.equals( M.pretty( Col.fromInt(0x0000ff).luminance, 2 ), 0.34 );

		CiAssert.equals( M.pretty( Col.fromInt(0x000000).fastLuminance ), 0 );
		CiAssert.equals( M.pretty( Col.fromInt(0xffffff).fastLuminance ), 1 );
		CiAssert.equals( M.pretty( Col.fromInt(0xff0000).fastLuminance, 2 ), 0.3 );
		CiAssert.equals( M.pretty( Col.fromInt(0x00ff00).fastLuminance, 2 ), 0.59 );
		CiAssert.equals( M.pretty( Col.fromInt(0x0000ff).fastLuminance, 2 ), 0.11 );

		CiAssert.equals( Col.fromInt(0x0).invert(), 0xffffff );
		CiAssert.equals( Col.fromInt(0xffffff).invert(), 0x0 );
		CiAssert.equals( Col.fromInt(0x00ff00).invert(), 0xff00ff );

		// Alpha
		CiAssert.equals( Col.fromInt(0x112233).withAlpha(1), 0xff112233);
		CiAssert.equals( Col.fromInt(0x112233).withAlpha(0.5), 0x80112233);
		CiAssert.equals( Col.fromInt(0xff112233).withoutAlpha(), 0x112233);
		CiAssert.equals( Col.fromInt(0x112233).withoutAlpha(), 0x112233);
		CiAssert.equals( Col.removeAlpha(0xaa112233), 0x112233);
		CiAssert.equals( Col.removeAlpha(0x112233), 0x112233);
		CiAssert.equals( Col.getAlphaf(0x112233), 0);
		CiAssert.equals( M.pretty(Col.getAlphaf(0x80112233),1), 0.5);
		CiAssert.equals( Col.getAlphaf(0xff112233), 1);

		// Enum
		CiAssert.equals( Red, 0xff0000 );
		CiAssert.equals( Green, 0x00ff00 );
		CiAssert.equals( Blue, 0x0000ff );
		CiAssert.equals( Col.fromColorEnum(Red), Col.parseHex("#ff0000") );
		CiAssert.equals( Col.fromColorEnum(Green), Col.parseHex("#00ff00") );
		CiAssert.equals( Col.fromColorEnum(Blue), Col.parseHex("#0000ff") );
		CiAssert.equals( Col.fromColorEnum(White), Col.parseHex("#fff") );
		CiAssert.equals( Col.fromColorEnum(Black), Col.parseHex("#000") );

		// Inlining of constants
		var i = 0;
		CiAssert.equals( Col.inlineHex(i==0 ? "#f00" : "#fc0"), 0xff0000 );
		CiAssert.equals( Col.inlineHex(i==0 ? Red : "#fc0"), 0xff0000 );
		CiAssert.equals( Col.inlineHex(i==0 ? 0xff0000 : "#fc0"), 0xff0000 );

		CiAssert.equals( Col.inlineHex(i==2 ? "#00f" : i==1 ? "#fc0" : "#f00" ), 0xff0000 );
		CiAssert.equals( Col.inlineHex(i==2 ? "#00f" : i==1 ? Yellow : "#f00" ), 0xff0000 );
		CiAssert.equals( Col.inlineHex(i==2 ? 0x0000ff : i==1 ? Yellow : "#f00" ), 0xff0000 );
	}
}
#end