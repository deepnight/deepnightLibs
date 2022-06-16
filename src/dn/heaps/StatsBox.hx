package dn.heaps;

import hxd.Key as K;
import dn.Col;

/**
	Stats box for Heaps (shows current FPS & FPS history chart).
	Press ALT-S to hide temporarily.
**/
class StatsBox extends dn.Process {
	/** Screen X location of Stats (0=left -> 1=right) **/
	public var anchorRatioX(default,set) : Float = 1;
	inline function set_anchorRatioX(v) return anchorRatioX = M.fclamp(v,0,1);

	/** Screen Y location of Stats (0=top -> 1=bottom) **/
	public var anchorRatioY(default,set) : Float = 1;
		inline function set_anchorRatioY(v) return anchorRatioY = M.fclamp(v,0,1);

	public var wid(default,set) : Int;

	var anchor : h2d.col.Point;
	var flow : h2d.Flow;
	public var updateFreqS(default,set) = 0.25;

	var components : Array<{ f:h2d.Flow, update:(f:h2d.Flow)->Void}> = [];
	var charts : Array<Chart> = [];

	public var font : Null<h2d.Font>;


	public function new(parent:dn.Process) {
		super(parent);

		if( parent.root==null )
			throw "Need to be attached to a Process with a root!";

		createRootInLayers(parent.root, 99999);

		anchor = new h2d.col.Point();

		flow = new h2d.Flow(root);
		flow.layout = Vertical;
		flow.backgroundTile = h2d.Tile.fromColor(0x0,1,1, 0.7);
		flow.padding = 1;
		flow.horizontalAlign = Right;
		flow.verticalSpacing = 2;

		wid = 100;
		Process.resizeAll();
	}


	function set_wid(v) {
		wid = v;
		flow.minWidth = wid;
		for(c in charts)
			c.wid = wid;
		return wid;
	}

	function set_updateFreqS(v) {
		updateFreqS = v;
		for(c in charts)
			@:privateAccess c.freqS = v;
		return wid;
	}

	inline function getFont() return font==null ? hxd.res.DefaultFont.get() : font;

	/** Add a custom dynamic Flow based component **/
	public function addComponent( update:(f:h2d.Flow)->Void ) {
		var f = new h2d.Flow();
		flow.addChildAt(f,0);
		f.layout = Horizontal;
		components.push({ f:f, update:update });
	}

	/** Add a dynamic text field **/
	public function addText( update:Void->String ) {
		var f = new h2d.Flow();
		flow.addChildAt(f,0);
		f.layout = Horizontal;
		var tf = new h2d.Text(getFont(), f);
		components.push({ f:f, update:(_)->{
			tf.text = update();
		}});
	}

	/**
		Add a chart tracking an arbitrary value
		@param refValue If not zero, this will display a reference horizontal line at given value
		@param maxValue If not zero, defines the max value of the chart
	 **/
	public function addCustomChart( label="", ?color:Col, valueGetter:Void->Float, refValue=0., maxValue=0.) : Chart {
		var c = new Chart(label, color, getFont(), this);
		flow.addChild(c.root);
		c.wid = wid;
		c.hei = 24;
		c.refValue = refValue;
		c.maxValue = maxValue;
		c.autoPlot( valueGetter, updateFreqS);
		charts.push(c);
		return c;
	}

	/** Add a chart tracking **FPS** **/
	public function addFpsChart(refFps=60) {
		var c = addCustomChart("FPS", Yellow, ()->hxd.Timer.fps(), refFps, refFps*2.5);
		c.precision = 0;
		return c;
	}

	#if heaps
	/** Add a chart tracking **Draw Calls** **/
	public function addDrawCallsChart() {
		return addCustomChart("DrawC", Col.fromColorEnum(Red).toWhite(0.4), ()->engine.drawCalls);
	}
	/** Add a chart tracking **Triangles Count** **/
	public function addTrianglesChart() {
		return addCustomChart("Trg", Red, ()->engine.drawTriangles);
	}
	#end

	public inline function addArrayChart<T>(label:String, ?col:Col, arr:Array<T>) {
		return addCustomChart(label, col, ()->arr.length);
	}

	#if hl
	/** Add a chart tracking **Memory Usage** (per seconds or total) **/
	public function addMemoryChart(showValuePerSec=true) {
		var c = addCustomChart("MEM", Col.fromColorEnum(Blue).toWhite(0.4), ()->dn.Gc.getCurrentMem());
		c.precision = 2;
		c.showValuePerSec = showValuePerSec;
		if( showValuePerSec )
			c.valuePrinter = (v,p)->M.unitMega(v,p)+"/s";
		return c;
	}

	/** Add a chart tracking **GC Allocation Count** **/
	public function addGcAllocChart() {
		return addCustomChart("GCa", Col.fromColorEnum(Blue).toWhite(0.4), ()->dn.Gc.getAllocationCount());
	}

	/** Add a chart tracking **GC Total Allocated** **/
	public function addGcTotalAlloc(showValuePerSec=true) {
		var c = addCustomChart("GCt", Col.fromColorEnum(Blue).toWhite(0.4), ()->dn.Gc.getTotalAllocated());
		c.showValuePerSec = showValuePerSec;
		c.precision = 2;
		return c;
	}
	#end

	/** Remove every components and charts**/
	public function removeAllComponents() {
		for(c in components)
			c.f.remove();
		components = [];

		for(c in charts)
			c.destroy();
		charts = [];
	}

	override function onResize() {
		super.onResize();
		var s = Scaler.bestFit_i(wid*6, 1);
		root.setScale(s);
	}

	public inline function show() {
		root.visible = true;
	}
	public inline function hide() {
		root.visible = false;
	}
	public inline function toggle() {
		root.visible = !root.visible;
	}


	override function postUpdate() {
		super.postUpdate();

		if( root.visible ) {
			anchor.set( w()*anchorRatioX, h()*anchorRatioY );
			root.globalToLocal(anchor);
			flow.x = anchor.x - flow.outerWidth * anchorRatioX;
			flow.y = anchor.y - flow.outerHeight * anchorRatioY;
		}

		for(c in components)
			c.update(c.f);
	}


	override function update() {
		super.update();

		if( K.isPressed(K.S) && K.isDown(K.ALT) )
			toggle();
	}
}