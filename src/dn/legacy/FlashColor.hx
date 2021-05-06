package dn;

import Type;
import dn.Color;


class FlashColor {
	#if flash

	public static inline function getDarkenCT(ratio:Float) {
		var ct = new flash.geom.ColorTransform();
		ct.redMultiplier = ct.greenMultiplier = ct.blueMultiplier = 1-ratio;
		return ct;
	}

	public static inline function getSimpleCT(?col:Col, ?colInt:Int, ?alpha:Null<Float>) {
		if (col==null)
			col = intToRgb(colInt);
		var ct = new flash.geom.ColorTransform();
		ct.redOffset = col.r-127;
		ct.greenOffset = col.g-127;
		ct.blueOffset = col.b-127;
		if(alpha!=null)
			ct.alphaMultiplier = alpha;
		return ct;
	}
	public static inline function getColorizeCT(?col:Col, ?colInt:Int, ratio:Float) {
		if (col==null)
			col = intToRgb(colInt);
		var ct = new flash.geom.ColorTransform();
		ct.redOffset = col.r*ratio;
		ct.greenOffset = col.g*ratio;
		ct.blueOffset = col.b*ratio;
		ct.redMultiplier = 1-ratio;
		ct.greenMultiplier = 1-ratio;
		ct.blueMultiplier = 1-ratio;
		return ct;
	}


	public static inline function getBrightnessFilter(ratio:Float) : flash.filters.ColorMatrixFilter { // -1 -> 1
		var r = 1+ratio;
		var matrix = [
			r,0,0,0, 0,
			0,r,0,0, 0,
			0,0,r,0, 0,
			0,0,0,1, 0,
		];
		return new flash.filters.ColorMatrixFilter(matrix);
	}

	public static inline function getContrastFilter(ratio:Float) : flash.filters.ColorMatrixFilter { // -1 -> 1
		var m = 1+ratio*1.5;
		var o = -64*ratio;
		var matrix = [
			m,0,0,0,o,
			0,m,0,0,o,
			0,0,m,0,o,
			0,0,0,1,0,
		];
		return new flash.filters.ColorMatrixFilter(matrix);
	}


	// Renvoie une matrice pour utiliser avec un ColorMatrixFilter
	static inline function getDesaturateMatrix(?ratio=1.0) {
		// Credit : https://en.wikipedia.org/wiki/Luma_(video)
		var redIdentity		= [1.0, 0, 0, 0, 0];
		var greenIdentity	= [0, 1.0, 0, 0, 0];
		var blueIdentity	= [0, 0, 1.0, 0, 0];
		var alphaIdentity	= [0, 0, 0, 1.0, 0];
		var grayluma		= [RED_LUMA, GREEN_LUMA, BLUE_LUMA, 0, 0];

		var a = new Array();
		a = a.concat( interpolateArrays(redIdentity,	grayluma, ratio) );
		a = a.concat( interpolateArrays(greenIdentity,	grayluma, ratio) );
		a = a.concat( interpolateArrays(blueIdentity,	grayluma, ratio) );
		a = a.concat( alphaIdentity );
		return a;
	}

	public static inline function getSaturationFilter(ratio:Float) : flash.filters.ColorMatrixFilter { // -1 -> 1
		var matrix =
			if(ratio>0)
			[
				1+ratio,-ratio,0,0,0,
				-ratio,1+ratio,0,0,0,
				0,-ratio,1+ratio,0,0,
				0,0,0,1,0,
			];
			else
				getDesaturateMatrix(-ratio);
		return new flash.filters.ColorMatrixFilter(matrix);
	}

	public static inline function getInterpolatedCT(colFrom:Col, colTo:Col, ratio:Float) {
		return getSimpleCT( interpolate(colFrom, colTo, ratio) );
	}

	public static inline function getColorizeFilter(col:Int, ?ratioNewColor=1.0, ?ratioOldColor=1.0) {
		var rgb = intToRgb(col);
		var r = ratioNewColor * rgb.r/255;
		var g = ratioNewColor * rgb.g/255;
		var b = ratioNewColor * rgb.b/255;
		var m = [
			ratioOldColor+r, r, r, 0, 0,
			g, ratioOldColor+g, g, 0, 0,
			b, b, ratioOldColor+b, 0, 0,
			0, 0, 0, 1.0, 0,
		];
		return new flash.filters.ColorMatrixFilter(m);
	}


	public static inline function getGammaFilter(ratio:Float) { // not exactly a gamma
		var matrix = [
			1+ratio, 0, 0, 0, 0,
			0, 1+ratio, 0, 0, 0,
			0, 0, 1+ratio, 0, 0,
			0, 0, 0, 1, 0,
		];
		return new flash.filters.ColorMatrixFilter(matrix);
	}

	private static inline function interpolateArrays(ary1:Array<Float>, ary2:Array<Float>, t:Float){
		// Credit : http://www.senocular.com/flash/source/?id=0.169
		var result = new Array();
		for (i in 0...ary1.length)
			result[i] = ary1[i] + (ary2[i] - ary1[i])*t;
		return result;
	}

	public static inline function replaceChannel(bd:flash.display.BitmapData, r:Bool, g:Bool, b:Bool, colInt:Int, ?brightness=1.5) {
		var pt = new flash.geom.Point(0,0);
		var r_chan = if (r) extractChannel( bd, r, false, false ) else null;
		var g_chan = if (g) extractChannel( bd, false, g, false ) else null;
		var b_chan = if (b) extractChannel( bd, false, false, b ) else null;

		var diff : flash.display.BitmapData = null;

		var fl_2channels = r && g || r && b || g && b;

		if (fl_2channels) {
			// remplacement avec 2 channels
			diff = extractChannel( bd, r, g, b );
			if (r)	compareBitmaps(diff, r_chan);
			if (g)	compareBitmaps(diff, g_chan);
			if (b)	compareBitmaps(diff, b_chan);
		}
		else {
			// remplacemetn avec 1 seul channel
			if (r) diff = r_chan;
			if (g) diff = g_chan;
			if (b) diff = b_chan;
		}

		// on remplace le canal demandé
		var col = intToRgb(colInt);
		var fact = if (fl_2channels) 0.5 else 1;
		var r_ratio = fact * col.r/255 * brightness;
		var g_ratio = fact * col.g/255 * brightness;
		var b_ratio = fact * col.b/255 * brightness;
		var rint = r?1:0;
		var gint = g?1:0;
		var bint = b?1:0;
		var matrix = [
			rint*r_ratio, gint*r_ratio, bint*r_ratio, 0,0,
			rint*g_ratio, gint*g_ratio, bint*g_ratio, 0,0,
			rint*b_ratio, gint*b_ratio, bint*b_ratio, 0,0,
			0,0,0,1,0,
		];
		diff.applyFilter(diff, diff.rect, pt,
			new flash.filters.ColorMatrixFilter(matrix));
		bd.draw(diff);

		if(r_chan!=null) r_chan.dispose();
		if(g_chan!=null) g_chan.dispose();
		if(b_chan!=null) b_chan.dispose();
		diff.dispose();
	}

	private static inline function extractChannel(bd:flash.display.BitmapData, r:Bool, g:Bool, b:Bool) {
		var chan = bd.clone();
		var mask : Col32 = { a:0, r:(r?0:1)*255, g:(g?0:1)*255, b:(b?0:1)*255 };
		chan.threshold(chan, chan.rect, new flash.geom.Point(0, 0),
			">", 0x00000000, 0x00000000, Color.rgbaToInt(mask));
		return chan;
	}

	private static inline function compareBitmaps(target:flash.display.BitmapData, bd:flash.display.BitmapData) {
		var comp : Dynamic = target.compare(bd);
		target.fillRect(target.rect, 0x0);
		if (Type.typeof(comp)!=TInt) {
			target.fillRect(target.rect, 0x0);
			var comp : flash.display.BitmapData = comp;
			target.draw(comp);
			comp.dispose();
		}
	}

	public static inline function getChannelMask(r:Int,g:Int,b:Int) { // 0-1
		var c : Col32 = { a:0, r:r*255, g:g*255, b:b*255 }
		return rgbaToInt(c);
	}

	public static inline function makeNicePalette(col:Int, ?dark=0x0, ?light:Null<Int>, ?addAlpha=false) : PalInt {
		var col = intToRgb(col);
		if (light==null)
			light = rgbToInt( offsetColor(col, 100) );
		var dark = intToRgb(dark);
		var light = intToRgb(light);
		var pal : PalInt = new Array();
		var lightLimit = 200;
		var lightRange = 256-lightLimit;
		for (i in 0...256) {
			if (i<lightLimit)
				pal[i] = rgbToInt( interpolate(dark, col, i/lightLimit) );
			else
				pal[i] = rgbToInt( interpolate(col, light, (i-lightLimit)/lightRange) );
			if (addAlpha)
				pal[i] = 0xff<<24 | pal[i];
		}
		return pal;
	}

	public static inline function makePaletteLinear(colors:Array<Int>, ?len=256) : PalInt { // du sombre au clair
		var pal : PalInt = [];
		var stepLength = len/(colors.length-1);
		for (i in 0...len) {
			var step = i/stepLength;
			var col0 = colors[Std.int(step)];
			var col1 = colors[Std.int(step)+1];
			pal[i] = interpolateInt(col0, col1, step-Std.int(step));
		}
		return pal;
	}

	public static inline function makePaletteCustom(colors:Array<{ratio:Float, col:Int}>) : PalInt { // du sombre au clair
		if( colors.length<2 )
			return throw "makePaletteCustom: not enough colors";

		var pal : PalInt = [];
		var idx = 0;
		var colors = colors.map( function(c) return {idx:M.round(c.ratio*256), col:c.col} );
		colors.sort(function(a,b) return Reflect.compare(a.idx, b.idx));
		if( colors[0].idx!=0 )
			colors.insert(0, {idx:0, col:colors[0].col});

		if( colors[colors.length-1].idx!=256 )
			colors.push({ idx:256, col:colors[colors.length-1].col });

		var cidx = 0;
		do {
			var from = colors[cidx];
			var to = colors[cidx+1];
			var subPal = makePaletteLinear([from.col, to.col], to.idx-from.idx);
			pal = pal.concat(subPal);
			cidx++;
		} while( cidx+1<colors.length );
		return pal;
	}


	public static function getFastPalette(r:PalInt, g:PalInt, b:PalInt, yellow:PalInt, pink:PalInt, cyan:PalInt) {
		var ba = new flash.utils.ByteArray();
		for (i in 0...256)	ba.writeUnsignedInt(0xff000000|0x0); // canaux 0,0,0
		for (c in r)		ba.writeUnsignedInt(0xff000000|c);
		for	(c in g)		ba.writeUnsignedInt(0xff000000|c);
		for	(c in yellow)	ba.writeUnsignedInt(0xff000000|c);
		for	(c in b)		ba.writeUnsignedInt(0xff000000|c);
		for	(c in pink)		ba.writeUnsignedInt(0xff000000|c);
		for (c in cyan)		ba.writeUnsignedInt(0xff000000|c);
		for (i in 0...256)	ba.writeUnsignedInt(0x0); // canaux 1,1,1
		ba.position = 0;
		return ba;
	}


	public static function paintBitmapFast(bd:flash.display.BitmapData, pal:flash.utils.ByteArray) {
		var bounds = if (bd.transparent) bd.getColorBoundsRect(0xff000000, 0x00000000, false) else bd.rect;
		var buffer = bd.getPixels(bounds);
		var palAddr = buffer.position;
		buffer.writeBytes(pal);
		buffer.position = 0;
		flash.Memory.select(buffer);
		var pos : UInt = 0;
		var palLength = 256*4;
		while (pos<palAddr) {
			var a = flash.Memory.getByte(pos);
			if ( a == 0 ) { pos += 4; continue; }
			var r = flash.Memory.getByte(pos+1);
			var g = flash.Memory.getByte(pos+2);
			var b = flash.Memory.getByte(pos+3);
			var idx = ( ((r>0)?1:0) | ((g>0)?2:0) | ((b>0)?4:0) );
			flash.Memory.setI32(pos, (flash.Memory.getI32(palAddr + (((idx<<8) + (r | g | b)) << 2)) & 0xFFFFFF00) | a);
			pos+=4;
		}
		bd.setPixels(bounds, buffer);
	}


	public static function paintBitmap(bd:flash.display.BitmapData, red:PalInt, green:PalInt, blue:PalInt, ?yellow:PalInt, ?pink:PalInt, ?cyan:PalInt) {
		//var bounds = (bd.transparent ? bd.getColorBoundsRect(0xff000000, 0x00000000, false) : bd.rect);
		var bounds = bd.rect;
		var pixels = bd.getPixels(bounds);
		pixels.position = 0;
		if (pixels.bytesAvailable>0) {
			flash.Memory.select(pixels);

			var pos : UInt = 0;
			var max = pixels.bytesAvailable;
			while (pos<max) {
				if( flash.Memory.getByte(pos)>0 ) { // test alpha
					var r = flash.Memory.getByte(pos+1);
					var g = flash.Memory.getByte(pos+2);
					var b = flash.Memory.getByte(pos+3);

					if(r!=g || g!=b || r!=b) {
						var result =
							if (g==0 && b==0)		red[r];
							else if (r==0 && b==0)	green[g];
							else if (r==0 && g==0)	blue[b];
							else if (r!=0 && g!=0)	yellow[r];
							else if (r!=0 && b!=0)	pink[r];
							else if (g!=0 && b!=0)	cyan[g];
							else 0xff00ff;
						flash.Memory.setByte(pos+1, result>>16);
						flash.Memory.setByte(pos+2, result>>8);
						flash.Memory.setByte(pos+3, result);
					}
				}
				pos+=4;
			}
			bd.setPixels(bounds, pixels);
		}
	}


	public static function paintBitmapGrays(bd:flash.display.BitmapData, pal:PalInt) {
		var bounds = bd.rect;
		var pixels = bd.getPixels(bounds);
		pixels.position = 0;
		if (pixels.bytesAvailable>0) {
			flash.Memory.select(pixels);

			var pos : UInt = 0;
			var max = pixels.bytesAvailable;
			while (pos<max) {
				if( flash.Memory.getByte(pos)>0 ) { // test alpha
					var r = flash.Memory.getByte(pos+1);
					var g = flash.Memory.getByte(pos+2);
					var b = flash.Memory.getByte(pos+3);

					if(r==g && g==b) {
						var result = pal[r];
						flash.Memory.setByte(pos+1, result>>16);
						flash.Memory.setByte(pos+2, result>>8);
						flash.Memory.setByte(pos+3, result);
					}
				}
				pos+=4;
			}
			bd.setPixels(bounds, pixels);
		}
	}


	public static function pickColor(bd:flash.display.BitmapData, rect:flash.geom.Rectangle) : Col32 {
		var ba = bd.getPixels(rect);
		var sum = {a:0., r:0., g:0., b:0.}
		var pos = 0;
		var len : Int = ba.length;
		while( pos < len ) {
			sum.a += ba[pos++];
			sum.r += ba[pos++];
			sum.g += ba[pos++];
			sum.b += ba[pos++];
		}
		var n = rect.width*rect.height;
		var rgba : Col32 = {a:Std.int(sum.a/n), r:Std.int(sum.r/n), g:Std.int(sum.g/n), b:Std.int(sum.b/n)}
		return {a:Std.int(sum.a/n), r:Std.int(sum.r/n), g:Std.int(sum.g/n), b:Std.int(sum.b/n)}
	}

	public static function drawPalette(g:flash.display.Graphics, ?wid=32, ?hei=32, ?aint:Array<Int>, ?acol:Array<Col>) {
		if( aint!=null )
			for(i in 0...aint.length) {
				g.beginFill(aint[i], 1);
				g.drawRect(i*wid, 0, wid,hei);
				g.endFill();
			}
		else
			for(i in 0...acol.length) {
				g.beginFill(rgbToInt(acol[i]), 1);
				g.drawRect(i*wid, 0, wid,hei);
				g.endFill();
			}
	}

	#end
}

