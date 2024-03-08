package dn.heaps;

class Skewable extends h2d.Object {
	public var skewBottom(never,set) : Float; inline function set_skewBottom(v:Float) return skewX = v;
	public var skewRight(never,set) : Float; inline function set_skewRight(v:Float) return skewY = v;

	var skewX = 0.;
	var skewY = 0.;

	var tmpAA = 0.;
	var tmpAB = 0.;
	var tmpAC = 0.;
	var tmpAD = 0.;
	var tmpAX = 0.;
	var tmpAY = 0.;
	var tmpBB = 0.;
	var tmpBC = 0.;

	public function new(?p) {
		super(p);
	}

	public function skewPx(xPixels:Float, yPixels:Float, thisWid:Float, thisHei:Float) {
		skewBottom = Math.atan(xPixels/thisHei);
		skewRight = Math.atan(yPixels/thisWid);
	}

	override function calcAbsPos() {
		super.calcAbsPos();

		if( skewX!=0 || skewY!=0 ) {
			tmpAA = matA;
			tmpAB = matB;
			tmpAC = matC;
			tmpAD = matD;
			tmpAX = absX;
			tmpAY = absY;
			tmpBB = Math.tan(skewY);
			tmpBC = Math.tan(skewX);

			matA = tmpAA + tmpAB * tmpBC;
			matB = tmpAA * tmpBB + tmpAB;
			matC = tmpAC + tmpAD * tmpBC;
			matD = tmpAC * tmpBB + tmpAD;
			absX = tmpAX + tmpAY * tmpBC;
			absY = tmpAX * tmpBB + tmpAY;
		}
	}
}