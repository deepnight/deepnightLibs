package dn.legacy;

@:enum
abstract PadKey(Int) {
	var A               	= 0;
	var B               	= 1;
	var X               	= 2;
	var Y               	= 3;
	var SELECT          	= 4;
	var START           	= 5;
	var LT              	= 6;
	var RT              	= 7;
	var LB              	= 8;
	var RB              	= 9;
	var LSTICK          	= 10;
	var RSTICK          	= 11;
	var DPAD_UP         	= 12;
	var DPAD_DOWN       	= 13;
	var DPAD_LEFT       	= 14;
	var DPAD_RIGHT      	= 15;
	var AXIS_LEFT_X     	= 16;
	var AXIS_LEFT_X_NEG 	= 17;
	var AXIS_LEFT_X_POS 	= 18;
	var AXIS_LEFT_Y     	= 19;
	var AXIS_LEFT_Y_NEG 	= 20;
	var AXIS_LEFT_Y_POS 	= 21;
	var AXIS_RIGHT_X    	= 22;
	var AXIS_RIGHT_X_NEG 	= 23;
	var AXIS_RIGHT_X_POS 	= 24;
	var AXIS_RIGHT_Y    	= 25;
	var AXIS_RIGHT_Y_NEG 	= 26;
	var AXIS_RIGHT_Y_POS 	= 27;

	public inline function new( v : Int ){
		this = v;
	}

	public inline function getIndex() : Int {
		return this;
	}

	inline public static var LENGTH = 28;
}

class GamePad {
	public static var ALL : Array<GamePad> = [];
	public static var AVAILABLE_DEVICES : Array<hxd.Pad>;

	static var MAPPING	: Array<Int> = [
		hxd.Pad.DEFAULT_CONFIG.A,
		hxd.Pad.DEFAULT_CONFIG.B,
		hxd.Pad.DEFAULT_CONFIG.X,
		hxd.Pad.DEFAULT_CONFIG.Y,
		hxd.Pad.DEFAULT_CONFIG.back,
		hxd.Pad.DEFAULT_CONFIG.start,
		hxd.Pad.DEFAULT_CONFIG.LT,
		hxd.Pad.DEFAULT_CONFIG.RT,
		hxd.Pad.DEFAULT_CONFIG.LB,
		hxd.Pad.DEFAULT_CONFIG.RB,
		hxd.Pad.DEFAULT_CONFIG.analogClick,
		hxd.Pad.DEFAULT_CONFIG.ranalogClick,
		hxd.Pad.DEFAULT_CONFIG.dpadUp,
		hxd.Pad.DEFAULT_CONFIG.dpadDown,
		hxd.Pad.DEFAULT_CONFIG.dpadLeft,
		hxd.Pad.DEFAULT_CONFIG.dpadRight,

		hxd.Pad.DEFAULT_CONFIG.analogX,
		hxd.Pad.DEFAULT_CONFIG.analogX,
		hxd.Pad.DEFAULT_CONFIG.analogX,

		hxd.Pad.DEFAULT_CONFIG.analogY,
		hxd.Pad.DEFAULT_CONFIG.analogY,
		hxd.Pad.DEFAULT_CONFIG.analogY,

		hxd.Pad.DEFAULT_CONFIG.ranalogX,
		hxd.Pad.DEFAULT_CONFIG.ranalogX,
		hxd.Pad.DEFAULT_CONFIG.ranalogX,

		hxd.Pad.DEFAULT_CONFIG.ranalogY,
		hxd.Pad.DEFAULT_CONFIG.ranalogY,
		hxd.Pad.DEFAULT_CONFIG.ranalogY
	];

	var device				: Null<hxd.Pad>;
	var toggles				: Array<Int>;

	public var deadZone					: Float = 0.18;
	public var axisAsButtonDeadZone		: Float = 0.70;
	public var lastActivity(default,null) : Float;

	public function new(?deadZone:Float, ?onEnable:GamePad->Void) {
		ALL.push(this);
		toggles = [];

		if( deadZone!=null )
			this.deadZone = deadZone;

		if( onEnable!=null )
			this.onEnable = onEnable;

		if( AVAILABLE_DEVICES==null ){
			AVAILABLE_DEVICES = [];
			hxd.Pad.wait( onDevice );
		} else if( AVAILABLE_DEVICES.length > 0 ){
			enableDevice( AVAILABLE_DEVICES[0] );
		}

		lastActivity = haxe.Timer.stamp();
	}

	public dynamic function onEnable(pad:GamePad) {}
	public dynamic function onDisable(pad:GamePad) {}
	public inline function isEnabled() return device!=null;

	public inline function toString() return "GamePad("+getDeviceId()+")";
	public inline function getDeviceName() : Null<String> return device==null ? null : device.name;
	public inline function getDeviceId() : Null<Int> return device==null ? null : device.index;

	function enableDevice( p : hxd.Pad ) {
		if( device==null ) {
			AVAILABLE_DEVICES.remove( p );
			p.onDisconnect = function(){
				disable();
			}
			device = p;
			onEnable( this );
		}
	}

	function disable() {
		if( device!=null ) {
			device = null;
			onDisable(this);
		}
	}

	static function onDevice( p : hxd.Pad ) {
		for( i in ALL ){
			if( i.device == null ){
				i.enableDevice( p );
				return;
			}
		}

		AVAILABLE_DEVICES.push( p );
		p.onDisconnect = function() AVAILABLE_DEVICES.remove( p );
	}

	public function dispose() {
		ALL.remove(this);
		if( device != null )
			onDevice( device );
		device = null;
	}

	public function rumble( strength : Float, time_s : Float ) {
		if( isEnabled() )
			device.rumble(strength, time_s);
	}

	inline function getControlValue(idx:Int, simplified:Bool, overrideDeadZone:Float=-1.) : Float {
		var v = idx > -1 && idx<device.values.length ? device.values[idx] : 0;
		//if( inverts.get(cid)==true )
		//	v*=-1;

		var dz : Float = overrideDeadZone < 0. ? deadZone : overrideDeadZone;

		if( simplified )
			return v<-dz?-1. : (v>dz?1. : 0.);
		else
			return v>-dz && v<dz ? 0. : v;
	}

	public inline function getValue(k:PadKey, simplified=false, overrideDeadZone:Float=-1.) : Float {
		return isEnabled() ? getControlValue( MAPPING[k.getIndex()], simplified, overrideDeadZone ) : 0.;
	}

	public inline function checkDownStatus(k:PadKey) {
		switch( k ) {
			case AXIS_LEFT_X_NEG, AXIS_LEFT_Y_NEG, AXIS_RIGHT_X_NEG, AXIS_RIGHT_Y_NEG : return getValue(k,true, axisAsButtonDeadZone)<0;
			case AXIS_LEFT_X_POS, AXIS_LEFT_Y_POS, AXIS_RIGHT_X_POS, AXIS_RIGHT_Y_POS : return getValue(k,true, axisAsButtonDeadZone)>0;
			default : return getValue(k,true)!=0;
		}
	}

	public inline function isDown(k:PadKey) {
		return isEnabled() && toggles[k.getIndex()] > 0;
	}

	public /*inline */function isPressed(k:PadKey) {
		return isEnabled() && toggles[k.getIndex()] == 1;
		//var idx = MAPPING[k.getIndex()];
		//var t = isEnabled() && idx>-1 && idx<device.values.length ? toggles[idx] : 0;
		//return (t==1 || t==2) && isDown(k);
	}

	public static function update() {
		for(e in ALL){
			var hasToggle = false;
			if( e.device!=null ){
				//for(i in 0...e.device.values.length) {
				for (i in 0...PadKey.LENGTH) {
					if( e.checkDownStatus(new PadKey(i)) ){
						hasToggle = true;
						if ( e.toggles[i] >= 1 )
							e.toggles[i] = 2;
						else
							e.toggles[i] = 1;
					}
					else{
						e.toggles[i] = 0;
					}
				}
			}
			if( hasToggle )
				e.lastActivity = haxe.Timer.stamp();
		}
	}
}
