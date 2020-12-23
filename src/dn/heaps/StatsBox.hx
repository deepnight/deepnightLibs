package dn.heaps;

class StatsBox extends dn.Process {
	var anchor : h2d.col.Point;
	var flow : h2d.Flow;
	var fps : h2d.Text;

	/** Frequency of updates in seconds **/
	public var updateFrequencyS = 0.15;

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
		if( !cd.hasSetS("tick",updateFrequencyS) )
			fps.text = Std.string( dn.M.pretty(hxd.Timer.fps(), fpsPrecision) );
	}
}