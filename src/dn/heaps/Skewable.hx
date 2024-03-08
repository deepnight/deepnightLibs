package dn.heaps;

class Skewable extends h2d.Object {
	public var skewBottom(never,set) : Float; inline function set_skewBottom(v:Float) return skewX = v;
	public var skewRight(never,set) : Float; inline function set_skewRight(v:Float) return skewY = v;

	var skewX = 0.;
	var skewY = 0.;

	public function new(?p) {
		super(p);
	}

	public function skewPx(xPixels:Float, yPixels:Float, thisWid:Float, thisHei:Float) {
		skewBottom = Math.atan(xPixels/thisHei);
		skewRight = Math.atan(yPixels/thisWid);
	}

	override function calcAbsPos() {
		super.calcAbsPos();

		// Does not support rotation(s)
		if( skewX!=0 || skewY!=0 ) {
			matB += matA * Math.tan(skewY);
			matC += matD * Math.tan(skewX);
		}
	}
}