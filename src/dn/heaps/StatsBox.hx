package dn.heaps;

import hxd.Key as K;

/**
	Stats box for Heaps (shows current FPS & FPS history chart).
	Press ALT-S to hide temporarily.
**/

class StatsBox extends dn.Process {
	static final HISTORY_CHUNK = 30;

	/** Ideal FPS for the chart **/
	public var targetFps = 60;

	/** Frequency of updates in seconds **/
	public var updateFrequencyS = 0.4;

	/** Precision of the FPS counter **/
	public var fpsPrecision = 0;

	/** Screen X location of Stats (0=left -> 1=right) **/
	public var anchorRatioX(default,set) : Float = 1;
	inline function set_anchorRatioX(v) return anchorRatioX = M.fclamp(v,0,1);

	/** Screen Y location of Stats (0=top -> 1=bottom) **/
	public var anchorRatioY(default,set) : Float = 1;
		inline function set_anchorRatioY(v) return anchorRatioY = M.fclamp(v,0,1);

	/** FPS chart width in pixels **/
	public var chartWid = 70;

	/** FPS chart height in pixels **/
	public var chartHei = 20;

	var anchor : h2d.col.Point;
	var flow : h2d.Flow;
	var fps : h2d.Text;
	var engineInf : h2d.Text;
	var fpsChart : h2d.Graphics;

	var components : Array<{ f:h2d.Flow, update:(f:h2d.Flow)->Void}> = [];

	var fpsHistory = new haxe.ds.Vector(HISTORY_CHUNK*3);
	var histCursor = 0;

	public var font : Null<h2d.Font>;


	public function new(parent:dn.Process, showFpsChart=true) {
		super(parent);

		if( parent.root==null )
			throw "Need to be attached to a Process with a root!";

		createRootInLayers(parent.root, 99999);

		anchor = new h2d.col.Point();

		flow = new h2d.Flow(root);
		flow.layout = Vertical;
		flow.horizontalSpacing = 8;
		flow.backgroundTile = h2d.Tile.fromColor(0x0,1,1, 0.7);
		flow.padding = 4;
		flow.horizontalAlign = Right;
		flow.verticalSpacing = 4;

		var f = new h2d.Flow(flow);
		f.layout = Horizontal;
		f.verticalAlign = Middle;
		fps = new h2d.Text(getFont(), f);
		fpsChart = new h2d.Graphics(f);
		fpsChart.visible = showFpsChart;

		engineInf = new h2d.Text(getFont(), flow);

		onResize();
	}

	inline function getFont() return font==null ? hxd.res.DefaultFont.get() : font;

	public function addComponent( update:(f:h2d.Flow)->Void ) {
		var f = new h2d.Flow();
		flow.addChildAt(f,0);
		f.layout = Horizontal;
		components.push({ f:f, update:update });
	}

	public function addText( update:Void->String ) {
		var f = new h2d.Flow();
		flow.addChildAt(f,0);
		f.layout = Horizontal;
		var tf = new h2d.Text(getFont(), f);
		components.push({ f:f, update:(_)->{
			tf.text = update();
		}});
	}

	public function removeAllComponents() {
		for(c in components)
			c.f.remove();
		components = [];
	}

	override function onResize() {
		super.onResize();
		var s = Scaler.bestFit_i(chartWid, chartHei, Scaler.getViewportWidth()*0.1, Scaler.getViewportHeight()*0.1 );
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

		if( root.visible && !cd.hasSetS("tick",updateFrequencyS) ) {
			var v = hxd.Timer.fps();

			// Update FPS history
			if( fpsChart.visible ) {
				fpsHistory.set(histCursor++, v);
				if( histCursor>=fpsHistory.length ) {
					// History overflow
					for( i in HISTORY_CHUNK...fpsHistory.length )
						fpsHistory[i-HISTORY_CHUNK] = fpsHistory[i];
					histCursor-=HISTORY_CHUNK;
				}
			}

			// Display FPS
			fps.text = Std.string( dn.M.pretty(v, fpsPrecision) );

			// Engine infos
			engineInf.text = "DC="+engine.drawCalls+"/Trg="+engine.drawTriangles;

			// Draw chart
			if( fpsChart.visible ) {
				fpsChart.clear();
				fpsChart.beginFill( dn.legacy.Color.makeColorRgb( 1, M.fclamp(v/targetFps, 0, 1), 0 ), 0.33 );
				fpsChart.drawRect(0,0,chartWid,chartHei);
				fpsChart.drawRect(0, chartHei * (1-targetFps/(targetFps*1.1)), chartWid, 1);
				fpsChart.endFill();
				fpsChart.lineStyle(1, 0xffffff);
				for(i in 1...fpsHistory.length) {
					if( i>=histCursor )
						break;

					fpsChart.lineStyle(1, dn.legacy.Color.makeColorRgb( 1, M.fclamp(fpsHistory[i-1]/targetFps, 0, 1), 0 ) );
					fpsChart.moveTo(
						chartWid * (i-1)/fpsHistory.length,
						chartHei * (1-fpsHistory[i-1]/(targetFps*1.1))
					);
					fpsChart.lineTo(
						chartWid*i/fpsHistory.length,
						chartHei * (1-fpsHistory[i]/(targetFps*1.1))
					);
				}
			}
		}
	}
}