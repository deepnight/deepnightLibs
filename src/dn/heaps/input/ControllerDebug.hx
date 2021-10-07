package dn.heaps.input;


/**
	This class should only be instanciated by a ControllerAccess.
**/
class ControllerDebug<T:EnumValue> extends dn.Process {
	static var BT_SIZE = 10;

	var gia : ControllerAccess<T>;
	var flow : h2d.Flow;
	var font : h2d.Font;
	var status : Null<h2d.Text>;
	var connected = false;

	var afterRender : Null< ControllerDebug<T>->Void >;


	@:allow(dn.heaps.input.ControllerAccess)
	private function new(inputAccess:ControllerAccess<T>, ?f:h2d.Font, p:dn.Process, ?afterRender) {
		super(p);

		if( p.root==null )
			throw "Parent process has no root!";
		else
			createRootInLayers(p.root, 99999);

		this.gia = inputAccess;
		this.afterRender = afterRender;
		font = f!=null ? f : hxd.res.DefaultFont.get();

		flow = new h2d.Flow(root);
		flow.layout = Vertical;
		flow.padding = 4;
		flow.verticalSpacing = 2;

		render();
	}

	function render() {
		connected = true;
		killAllChildrenProcesses();
		flow.removeChildren();

		status = new h2d.Text(font, flow);
		flow.addSpacing(4);

		for(k in gia.input.actionsEnum.getConstructors()) {
			var a = gia.input.actionsEnum.createByName(k);
			createButton(a);
			if( gia.input.isBoundToAnalog(a) )
				createAnalog(a);
		}

		if( afterRender!=null )
			afterRender(this);
	}

	function onDisconnect() {
		render();
	}

	function onConnect() {
		render();
	}

	@:keep override function toString() return getName();

	inline function getName() {
		return gia.toString();
	}


	override function onDispose() {
		super.onDispose();
		font = null;
		gia = null;
	}


	function createButton(a:T) {
		var p = createChildProcess();
		p.createRoot(flow);

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), p.root);
		var tf = new h2d.Text(font, p.root);
		tf.text = a.getName();
		tf.x = BT_SIZE+4;
		tf.y = -4;

		p.onUpdateCb = ()->{
			if( gia.isDown(a) ) {
				tf.textColor = 0x00ff00;
				bmp.color.setColor( dn.Color.addAlphaF(0x00ff00) );
			}
			else {
				tf.textColor = 0xff0000;
				bmp.color.setColor( dn.Color.addAlphaF(0xff0000) );
			}
		}
	}


	function createAnalog(a:T) {
		var p = createChildProcess();
		p.createRoot(flow);

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,2,BT_SIZE), p.root);
		bmp.tile.setCenterRatio(0.5,0);
		var tf = new h2d.Text(font, p.root);
		tf.x = BT_SIZE+4;
		tf.y = -4;

		p.onUpdateCb = ()->{
			var v = gia.getAnalogValue(a);
			bmp.x = BT_SIZE*0.5 + BT_SIZE*0.5*v;
			tf.textColor = v!=0 ? 0x00ff00 : 0xff0000;
			tf.text = a.getName()+" val="+dn.M.pretty(v,1)+" dist="+dn.M.pretty(gia.getAnalogDist(a),1);
			bmp.color.setColor( dn.Color.addAlphaF(v!=0 ? 0x00ff00 : 0xff0000) );
		}
	}


	/**
		Create a combined X/Y (ie. stick) display
	**/
	public function createStick(xAxis:T, yAxis:T) {
		var p = createChildProcess();
		p.createRoot(flow);

		var s = dn.M.round(BT_SIZE*0.3);
		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,s,s), p.root);
		bmp.rotation = dn.M.PIHALF*0.5;
		bmp.tile.setCenterRatio(0.5,0);

		var tf = new h2d.Text(font, p.root);
		tf.x = BT_SIZE+4;
		tf.y = -2;

		p.onUpdateCb = ()->{
			var a = gia.getAnalogAngle(xAxis, yAxis);
			var d = gia.getAnalogDist(xAxis, yAxis);
			bmp.x = BT_SIZE*0.5 + Math.cos(a) * BT_SIZE*0.3*d;
			bmp.y = BT_SIZE*0.5 + Math.sin(a) * BT_SIZE*0.3*d;

			tf.text = xAxis.getName()+"/"+yAxis.getName()+" ang="+dn.M.pretty(a)+" dist="+dn.M.pretty(d,1);
		}
	}


	override function update() {
		super.update();

		if( !connected && gia.input.isPadConnected() )
			onConnect();

		if( connected && !gia.input.isPadConnected() )
			onDisconnect();

		status.text = getName()+"\n"+ (gia.input.isPadConnected() ? "Pad connected" : "Pad disconnected");
		status.textColor = gia.input.isPadConnected() ? 0x00ff00 : 0xff0000;
	}
}