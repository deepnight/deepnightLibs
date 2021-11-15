package dn.heaps.input;


/**
	This class should only be instanciated by a ControllerAccess.
**/
class ControllerDebug<T:EnumValue> extends dn.Process {
	static var BT_SIZE = 10;

	var ca : ControllerAccess<T>;
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

		this.ca = inputAccess;
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

		for(k in ca.input.actionsEnum.getConstructors()) {
			var a = ca.input.actionsEnum.createByName(k);
			createButton(a);
			if( ca.input.isBoundToAnalog(a) )
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
		return ca.toString();
	}


	override function onDispose() {
		super.onDispose();
		font = null;
		ca = null;
	}


	function getBindingsList(a:T) : String {
		var all = @:privateAccess ca.bindings;
		if( !all.exists(a) )
			return "<none>";
		else {
			var arr = [];
			for(b in all.get(a))
				arr.push(b.toString());
			return arr.join(", ");
		}
	}


	function createButton(a:T) {
		var p = createChildProcess();
		p.createRoot(flow);

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), p.root);
		var tf = new h2d.Text(font, p.root);
		tf.text = a.getName();
		tf.x = BT_SIZE+4;
		tf.y = -4;

		var btf = new h2d.Text(font,p.root);
		btf.x = 150;

		p.onUpdateCb = ()->{
			btf.text = getBindingsList(a);
			if( ca.isDown(a) ) {
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
			var v = ca.getAnalogValue(a);
			bmp.x = BT_SIZE*0.5 + BT_SIZE*0.5*v;
			tf.textColor = v!=0 ? 0x00ff00 : 0xff0000;
			tf.text = a.getName()+" val="+dn.M.pretty(v,1)+" dist="+dn.M.pretty(ca.getAnalogDist(a),1);
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
			var a = ca.getAnalogAngle(xAxis, yAxis);
			var d = ca.getAnalogDist(xAxis, yAxis);
			tf.textColor = d<=0 ? 0xff0000 : 0x00ff00;
			bmp.x = BT_SIZE*0.5 + Math.cos(a) * BT_SIZE*0.3*d;
			bmp.y = BT_SIZE*0.5 + Math.sin(a) * BT_SIZE*0.3*d;

			tf.text = xAxis.getName()+"/"+yAxis.getName()+" ang="+dn.M.pretty(a)+" dist="+dn.M.pretty(d,1);
		}
	}

	/**
		Create an "auto-fire" button display
	**/
	public function createAutoFire(a:T) {
		var p = createChildProcess();
		p.createRoot(flow);

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), p.root);
		var tf = new h2d.Text(font, p.root);
		tf.text = a.getName()+"(AF)";
		tf.x = BT_SIZE+4;
		tf.y = -4;

		p.onUpdateCb = ()->{
			if( ca.isPressedAutoFire(a) ) {
				tf.textColor = 0x00ff00;
				bmp.color.setColor( dn.Color.addAlphaF(0x00ff00) );
			}
			else {
				tf.textColor = 0xff0000;
				bmp.color.setColor( dn.Color.addAlphaF(0xff0000) );
			}
		}
	}

	/**
		Create an "held" button display
	**/
	public function createHeld(a:T, durationS:Float) {
		var p = createChildProcess();
		p.createRoot(flow);

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), p.root);
		var tf = new h2d.Text(font, p.root);
		var base = a.getName()+"(H)";
		tf.x = BT_SIZE+4;
		tf.y = -4;

		p.onUpdateCb = ()->{
			if( ca.isHeld(a,durationS) ) {
				tf.scaleX = 1.4;
				tf.textColor = 0x55ff00;
			}
			else if( ca.isDown(a) )
				tf.textColor = dn.Color.interpolateInt(0x000044, 0x0088ff, ca.getHoldRatio(a,durationS));
			else
				tf.textColor = 0xff0000;

			tf.text = base + ": " + M.round( ca.getHoldRatio(a,durationS)*100 ) + "%";
			if( ca.isHeld(a,durationS) )
				tf.text +=" <OK>";
			else
				tf.scaleX += (1-tf.scaleX)*0.3;

			bmp.color.setColor( dn.Color.addAlphaF(tf.textColor) );
		}
	}


	override function update() {
		super.update();

		if( !connected && ca.input.isPadConnected() )
			onConnect();

		if( connected && !ca.input.isPadConnected() )
			onDisconnect();

		status.text = getName()+"\n"+ (ca.input.isPadConnected() ? "Pad connected" : "Pad disconnected");
		status.textColor = ca.input.isPadConnected() ? 0x00ff00 : 0xff0000;
	}
}