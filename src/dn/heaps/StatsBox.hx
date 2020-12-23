package dn.heaps;

class StatsBox extends dn.Process {
	static final HISTORY_CHUNK = 20;
	static final CHART_WID = 80;
	static final CHART_HEI = 20;

	var anchor : h2d.col.Point;
	var flow : h2d.Flow;
	var fps : h2d.Text;
	var fpsChart : h2d.Graphics;

	var fpsHistory = new haxe.ds.Vector(HISTORY_CHUNK*3);
	var histCursor = 0;

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


	public function new(parent:dn.Process) {
		super(parent);

		if( parent.root==null )
			throw "Need to be attached to a Process with a root!";

		createRootInLayers(parent.root, 99999);

		anchor = new h2d.col.Point();

		flow = new h2d.Flow(root);
		flow.layout = Horizontal;
		flow.horizontalSpacing = 8;
		flow.backgroundTile = h2d.Tile.fromColor(0x0,1,1, 0.7);
		flow.padding = 4;

		fpsChart = new h2d.Graphics(flow);
		fps = new h2d.Text(hxd.res.DefaultFont.get(), flow);
	}


	override function postUpdate() {
		super.postUpdate();

		anchor.set( w()*anchorRatioX, h()*anchorRatioY );
		root.globalToLocal(anchor);
		flow.x = anchor.x - flow.outerWidth * anchorRatioX;
		flow.y = anchor.y - flow.outerHeight * anchorRatioY;
	}


	override function update() {
		super.update();
		if( !cd.hasSetS("tick",updateFrequencyS) ) {
			// Update FPS history
			var v = hxd.Timer.fps();
			fpsHistory.set(histCursor++, v);
			if( histCursor>=fpsHistory.length ) {
				// History overflow
				for( i in HISTORY_CHUNK...fpsHistory.length )
					fpsHistory[i-HISTORY_CHUNK] = fpsHistory[i];
				histCursor-=HISTORY_CHUNK;
				trace("overflow "+ftime+" => "+histCursor);
			}

			// Display FPS
			fps.text = Std.string( dn.M.pretty(v, fpsPrecision) );

			// Draw chart
			fpsChart.clear();
			fpsChart.beginFill( Color.makeColorRgb( 1, M.fclamp(v/targetFps, 0, 1), 0 ), 0.33 );
			fpsChart.drawRect(0,0,CHART_WID,CHART_HEI);
			fpsChart.drawRect(0, CHART_HEI * (1-targetFps/(targetFps*1.1)), CHART_WID, 1);
			fpsChart.endFill();
			fpsChart.lineStyle(1, 0xffffff);
			for(i in 1...fpsHistory.length) {
				if( i>=histCursor )
					break;

				fpsChart.lineStyle(1, Color.makeColorRgb( 1, M.fclamp(fpsHistory[i-1]/targetFps, 0, 1), 0 ) );
				fpsChart.moveTo(
					CHART_WID * (i-1)/fpsHistory.length,
					CHART_HEI * (1-fpsHistory[i-1]/(targetFps*1.1))
				);
				fpsChart.lineTo(
					CHART_WID*i/fpsHistory.length,
					CHART_HEI * (1-fpsHistory[i]/(targetFps*1.1))
				);
			}
		}
	}
}