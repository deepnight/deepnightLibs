package dn.heaps;

import dn.Col;

class Chart extends dn.Process {
	public var wid(default,set) : Int;
	public var hei(default,set) : Int;
	public var refValue(default,set) : Float = 0;
	public var color(default,set) : Col;
	var max = 0.;


	var g : h2d.Graphics;
	var invalidated = true;

	var freqS = 0.5;
	var autoPlotter : Null<Void->Float>;

	var history : haxe.ds.Vector<Float>;
	var curHistIdx = 0;
	var label : String;
	var last : h2d.Text;
	var font : h2d.Font;

	public function new(label="", color:Col=ColdLightGray, ?font:h2d.Font, p:Process) {
		super(p);

		this.color = color;
		this.font = font!=null ? font : hxd.res.DefaultFont.get();
		this.label = label;
		createRootInLayers(p.root, 99999);
		history = new haxe.ds.Vector(100);
		wid = Std.int(history.length*1.5);
		hei = 32;
		initBase();
	}

	public inline function setScale(v) {
		root.setScale(v);
	}

	public inline function setPosition(x,y) {
		root.setPosition(x,y);
	}

	inline function set_color(c) {
		color = c;
		invalidated = true;
		return c;
	}

	inline function set_refValue(v) {
		refValue = v;
		invalidated = true;
		return v;
	}

	inline function set_wid(v) {
		wid = v;
		invalidated = true;
		return v;
	}

	inline function set_hei(v) {
		hei = v;
		invalidated = true;
		return v;
	}

	override function onDispose() {
		super.onDispose();
		g = null;
		history = null;
	}

	function initBase() {
		root.removeChildren();

		var bg = new h2d.Graphics(root);
		bg.beginFill(color.toBlack(0.8));
		bg.lineStyle(1,color.toWhite(0.5));
		bg.drawRect(0,0,wid,hei);

		if( refValue!=0 ) {
			var line = new h2d.Bitmap(h2d.Tile.fromColor(color.toBlack(0.6)), root);
			line.scaleX = wid;
			line.y = getY(refValue);
		}

		var labelTf = new h2d.Text(font, root);
		labelTf.text = label;
		labelTf.textColor = color.toBlack(0.4);
		labelTf.x = 4;
		labelTf.y = hei-labelTf.textHeight-1;

		last = new h2d.Text(font, root);
		last.x = labelTf.x + labelTf.textWidth + 4;
		last.textColor = color.toBlack(0.3);
		if( curHistIdx>0 )
			printLast(history[curHistIdx-1]);

		g = new h2d.Graphics(root);
	}

	inline function printLast(v:Float) {
		last.text = Std.string( M.unit(v) );
		last.y = hei-last.textHeight-1;
	}

	function renderFullChart() {
		g.clear();
		g.lineStyle(1, color);
		g.moveTo( getX(0), getY(history[0]) );

		for(i in 1...curHistIdx)
			g.lineTo( getX(i), getY(history[i]) );
	}

	public function plot(v:Float) {
		updateMax(v);

		history[curHistIdx] = v;

		// Render
		g.lineStyle(1, color);
		if( curHistIdx==1 ) {
			g.moveTo(getX(curHistIdx), getY(v));
			g.lineTo(getX(curHistIdx), getY(v));
		}
		else {
			g.moveTo(getX(curHistIdx-1), getY(history[curHistIdx-1]));
			g.lineTo(getX(curHistIdx), getY(v));
		}

		printLast(v);
		curHistIdx++;

		// Scroll back
		if( curHistIdx>=history.length ) {
			max = 0;
			var chunk = Std.int( history.length*0.33 );
			for(i in chunk...history.length) {
				history[i-chunk] = history[i];
				updateMax( history[i] );
			}

			curHistIdx-=chunk;

			invalidated = true;
		}
	}

	inline function updateMax(v:Float) {
		var old = max;
		max = M.fmax( max, M.fmax(v, refValue)* 1.1 ) ;
		if( old!=max )
			invalidated = true;
	}

	public function autoPlot( valueGetter:Void->Float, freqS:Float ) {
		this.freqS = freqS;
		autoPlotter = valueGetter;
	}

	inline function getX(idx:Int) return idx/history.length * wid;
	inline function getY(v:Float) return hei - v/max*hei;

	override function update() {
		super.update();

		if( autoPlotter!=null ) {
			if( !cd.hasSetS("autoPlot",freqS) )
				plot( autoPlotter() );
		}
	}

	override function postUpdate() {
		super.postUpdate();

		if( invalidated ) {
			initBase();
			renderFullChart();
			invalidated = false;
		}
	}
}