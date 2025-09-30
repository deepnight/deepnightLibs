package dn.heaps.input;

private typedef DebugComponent = {
	var process : dn.Process;
	var flow : h2d.Flow;
}

/**
	This class should only be instanciated by a ControllerAccess.
**/
class ControllerDebug<T:Int> extends dn.Process {
	static var BT_SIZE = 10;
	static var RED = 0xff4400;
	static var GREEN = 0x66ff00;

	var ca : ControllerAccess<T>;
	var columnsFlow : h2d.Flow;
	var columns : Array<h2d.Flow> = [];
	var font : h2d.Font;
	var status : Null<h2d.Text>;
	var padConnected = false;
	var buttons : Map<T,DebugComponent> = new Map();
	var odd = false;
	var needResize = true;

	var afterRender : Null< ControllerDebug<T>->Void >;

	var curColumn(get,never) : h2d.Flow;
		inline function get_curColumn() {
			if( columns.length==0 )
				return createColumn();
			else
				return columns[columns.length-1];
		}

	public var width(get,never) : Int;
		inline function get_width() return columnsFlow.outerWidth;

	public var height(get,never) : Int;
		inline function get_height() return columnsFlow.outerHeight;


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

		columnsFlow = new h2d.Flow(root);
		columnsFlow.layout = Horizontal;
		columnsFlow.horizontalSpacing = 16;
		columnsFlow.verticalAlign = Top;

		render();
	}

	function createColumn() {
		var f = new h2d.Flow(columnsFlow);
		columns.push(f);
		f.layout = Vertical;
		f.padding = 4;
		f.verticalSpacing = 2;
		return f;
	}

	function render() {
		killAllChildrenProcesses();

		columns = [];
		columnsFlow.removeChildren();

		columnsFlow.backgroundTile = h2d.Tile.fromColor(0x0, 1,1, 0.4);

		status = new h2d.Text(font, curColumn);
		curColumn.addSpacing(4);

		var allActions : Array<T> = [];
		@:privateAccess
		for( act in ca.controller.actionNames.keys() ) {
			var act : T = cast act;
			allActions.push(act);
		}
		allActions.sort( (a,b)->Reflect.compare(a,b) );
		for(act in allActions)
			buttons.set(act, createButton(act));

		columnsFlow.reflow();
		if( afterRender!=null )
			afterRender(this);
	}

	function onPadDisconnected() {
		padConnected = false;
		render();
	}

	function onPadConnected() {
		padConnected = true;
		render();
	}

	@:keep override function toString() return getControllerName();

	inline function getControllerName() {
		return ca.toString();
	}

	inline function getActionName(act:T) {
		return @:privateAccess ca.controller.actionNames.exists(act)
			? @:privateAccess ca.controller.actionNames.get(act)
			: "???";
	}


	override function onDispose() {
		super.onDispose();
		font = null;
		ca = null;
		buttons = null;
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

	function removeButton(a:T) {
		if( buttons.exists(a) )
			buttons.get(a).process.destroy();
		buttons.remove(a);
	}


	function createComponent() : DebugComponent {
		if( curColumn.numChildren>=13 )
			createColumn();

		var p = createChildProcess();
		p.createRoot(curColumn);
		p.onResizeCb = ()->{
			needResize = true;
		}
		var flow = new h2d.Flow(p.root);
		flow.verticalAlign = Middle;
		flow.horizontalSpacing = 4;
		flow.paddingVertical = 4;
		flow.paddingLeft = 2;
		return { process:p, flow:flow }
	}


	function createButton(a:T) {
		var isAnalog = ca.controller.isBoundToAnalog(a,true);

		var c = createComponent();

		var buttonFlow = new h2d.Flow(c.flow);
		buttonFlow.minWidth = 120;
		buttonFlow.verticalAlign = Middle;
		buttonFlow.horizontalSpacing = c.flow.horizontalSpacing;

		var analogBg = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), buttonFlow);
		var bt = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,isAnalog?2:BT_SIZE, BT_SIZE), buttonFlow);
		if( isAnalog ) {
			buttonFlow.getProperties(bt).isAbsolute = true;
			analogBg.color = bt.color;
		}
		else
			analogBg.visible = false;

		var tf = new h2d.Text(font, buttonFlow);
		tf.text = getActionName(a);

		inline function _addText(t:String, f:h2d.Flow) {
			var tf = new h2d.Text(font, f);
			tf.text = t;
			return tf;
		}

		// Gamepad icons
		var gpFlow = new h2d.Flow(c.flow);
		gpFlow.verticalAlign = Middle;
		gpFlow.minWidth = 150;
		var first = true;
		for(f in ca.controller.getAllBindindIconsFor(a,Gamepad)) {
			if( !first )
				_addText(", ", gpFlow);
			gpFlow.addChild(f);
			first = false;
		}
		// Keyboard icons
		var kbFlow = new h2d.Flow(c.flow);
		kbFlow.verticalAlign = Middle;
		var first = true;
		for(f in ca.controller.getAllBindindIconsFor(a,Keyboard)) {
			if( !first )
				_addText(", ", kbFlow);
			kbFlow.addChild(f);
			first = false;
		}

		c.process.onUpdateCb = ()->{
			var alpha = isAnalog ? 0.4 : 1;
			if( ca.isDown(a) ) {
				tf.textColor = GREEN;
				bt.color.setColor( dn.legacy.Color.addAlphaF(GREEN, alpha) );
			}
			else {
				tf.textColor = RED;
				bt.color.setColor( dn.legacy.Color.addAlphaF(RED, alpha) );
			}

			// Analog
			if( isAnalog ) {
				bt.x = analogBg.x + BT_SIZE*0.5 + BT_SIZE*0.5* ca.getAnalogValue(a) - bt.tile.width*0.5;
				bt.y = analogBg.y;
			}
		}

		odd = !odd;
		return c;
	}


	/** Create a combined X/Y (ie. stick) display **/
	public function createStickXY(xAxis:T, yAxis:T) {
		createGenericStick(
			getActionName(xAxis)+"/"+getActionName(yAxis),
			ca.getAnalogAngleXY.bind(xAxis,yAxis),
			ca.getAnalogDistXY.bind(xAxis,yAxis)
		);
	}

	/** Create a combined Left/Right/Up/Down (ie. stick) display **/
	public function createStick4(?name:String, left:T, right:T, up:T, down:T) {
		createGenericStick(
			name!=null?name+" ":"",
			ca.getAnalogAngle4.bind(left,right,up,down),
			ca.getAnalogDist4.bind(left,right,up,down)
		);
	}

	/** Create a stick component **/
	function createGenericStick( label:String, angGetter:Void->Float, distGetter:Void->Float ) {
		var c = createComponent();

		var bg = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), c.flow);

		var stick = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,2,2), bg);
		stick.tile.setCenterRatio(0.5);
		stick.setPosition(BT_SIZE*0.5, BT_SIZE*0.5);

		var tf = new h2d.Text(font, c.flow);
		c.flow.getProperties(tf).isAbsolute = true; // Avoid text shaking
		tf.x = BT_SIZE+4;

		c.process.onUpdateCb = ()->{
			var a = angGetter();
			var d = distGetter();
			tf.textColor = d<=0 ? RED : GREEN;
			tf.text = label+" ang="+dn.M.pretty(a)+" dist="+dn.M.pretty(d,1);

			stick.x = BT_SIZE*0.5 + Math.cos(a) * (BT_SIZE*0.5-2)*d;
			stick.y = BT_SIZE*0.5 + Math.sin(a) * (BT_SIZE*0.5-2)*d;

			bg.color.setColor( dn.legacy.Color.addAlphaF(tf.textColor,0.4) );
		}
	}


	/**
		Create an "auto-fire" button display
	**/
	public function createAutoFire(a:T) {
		var c = createComponent();

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), c.flow);
		var tf = new h2d.Text(font, c.flow);
		tf.text = getActionName(a)+"(AF)";
		tf.x = BT_SIZE+4;
		tf.y = -4;

		c.process.onUpdateCb = ()->{
			if( ca.isPressedAutoFire(a) ) {
				tf.textColor = GREEN;
				bmp.color.setColor( dn.legacy.Color.addAlphaF(GREEN) );
			}
			else {
				tf.textColor = RED;
				bmp.color.setColor( dn.legacy.Color.addAlphaF(RED) );
			}
		}
	}

	/**
		Create an "held" button display
	**/
	public function createHeld(a:T, durationS:Float) {
		var c = createComponent();

		var bmp = new h2d.Bitmap(h2d.Tile.fromColor(0xffffff,BT_SIZE,BT_SIZE), c.flow);
		var tf = new h2d.Text(font, c.flow);
		var base = getActionName(a)+"(H)";
		tf.x = BT_SIZE+4;
		tf.y = -4;

		c.process.onUpdateCb = ()->{
			if( ca.isHeld(a,durationS) ) {
				tf.scaleX = 1.4;
				tf.textColor = 0x55ff00;
			}
			else if( ca.isDown(a) )
				tf.textColor = dn.legacy.Color.interpolateInt(0x000044, 0x0088ff, ca.getHoldRatio(a,durationS));
			else
				tf.textColor = RED;

			tf.text = base + ": " + M.round( ca.getHoldRatio(a,durationS)*100 ) + "%";
			if( ca.isHeld(a,durationS) )
				tf.text +=" <OK>";
			else
				tf.scaleX += (1-tf.scaleX)*0.3;

			bmp.color.setColor( dn.legacy.Color.addAlphaF(tf.textColor) );
		}
	}


	override function postUpdate() {
		super.postUpdate();
		if( needResize ) {
			root.setScale( dn.heaps.Scaler.bestFit_f( width, height, true ) );
			needResize = false;
		}
	}

	override function update() {
		super.update();

		if( !padConnected && ca.controller.isPadConnected() )
			onPadConnected();

		if( padConnected && !ca.controller.isPadConnected() )
			onPadDisconnected();

		status.text = getControllerName()+"\n"+ (ca.controller.isPadConnected() ? "Pad connected" : "Pad disconnected");
		status.textColor = ca.controller.isPadConnected() ? GREEN : RED;
	}
}