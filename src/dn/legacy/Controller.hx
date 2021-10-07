package dn.legacy;

import dn.legacy.GamePad;
import hxd.Key;

enum Mode {
	Keyboard;
	Pad;
}

@:allow(dn.legacy.ControllerAccess)
class Controller {
	static var UNIQ_ID = 0;
	static var LONG_PRESS = 0.35; // seconds
	static var SHORT_PRESS = 0.17; // seconds
	static var ALL : Array<Controller> = [];

	var mode : Mode = Keyboard;
	var exclusiveId : String = null;
	var gc : GamePad;
	var suspendTimer = 0.;

	var locked = false;
	public var allowAutoSwitch = true;

	var primary : haxe.ds.IntMap<Int> = new haxe.ds.IntMap();
	var secondary : haxe.ds.IntMap<Int> = new haxe.ds.IntMap();
	var third : haxe.ds.IntMap<Int> = new haxe.ds.IntMap();
	var fourth : haxe.ds.IntMap<Int> = new haxe.ds.IntMap();

	public function new( s2d : h2d.Scene ){
		ALL.push( this );
		gc = new GamePad(0.4);
		s2d.addEventListener( function(e:hxd.Event) {
			if( allowAutoSwitch && ( e.kind==EMove || e.kind==EKeyDown ) && mode!=Keyboard )
				mode = Keyboard;
		});
		for( idx in 0...pressTimers.length ) pressTimers[idx] = -1;
		for( idx in 0...framePresses.length ) framePresses[idx] = -1;
	}

	public inline function setKeyboard() mode = Keyboard;
	public inline function setGamePad() mode = Pad;

	public function bind(k:PadKey, keyboardKey1:Int, ?keyboardKey2:Int, ?keyboardKey3:Int, ?keyboardKey4:Int, unbindExisting=true) {
		if( unbindExisting ) {
			unbindKeyboard(keyboardKey1);
			unbindKeyboard(keyboardKey2);
			unbindKeyboard(keyboardKey3);
			unbindKeyboard(keyboardKey4);
		}

		primary.set(k.getIndex(), keyboardKey1);

		if( keyboardKey2!=null )
			secondary.set(k.getIndex(), keyboardKey2);

		if( keyboardKey3!=null )
			third.set(k.getIndex(), keyboardKey3);

		if( keyboardKey4!=null )
			fourth.set(k.getIndex(), keyboardKey4);
	}

	public function unbindKeyboard(key:Null<Int>) {
		if( key==null )
			return;

		for(binding in [primary, secondary, third, fourth])
		for(k in binding.keys())
			if( binding.get(k)==key )
				binding.remove(k);
	}

	public inline function getPrimaryKey(k:PadKey) : Null<Int> {
		return primary.get( k.getIndex() );
	}
	public inline function getSecondaryKey(k:PadKey) : Null<Int> {
		return secondary.get( k.getIndex() );
	}
	public inline function getThirdKey(k:PadKey) : Null<Int> {
		return third.get( k.getIndex() );
	}
	public inline function getFourthKey(k:PadKey) : Null<Int> {
		return fourth.get( k.getIndex() );
	}

	public inline function setDefaultDeadZone(v:Float) gc.deadZone = dn.M.fclamp(v,0,1);

	public function isLocked() return locked;
	public function lock() locked = true;
	public function unlock() {
		if( locked ) {
			locked = false;
			suspendTemp();
		}
	}

	inline function suspendTemp(?sec=0.07) {
		suspendTimer = haxe.Timer.stamp() + sec;
	}

	public function createAccess( id:String, ?exclusive=false ){
		return new ControllerAccess(this,id,exclusive);
	}

	var pressTimers   : haxe.ds.Vector<Float> = new haxe.ds.Vector( GamePad.PadKey.LENGTH );
	var framePresses  : haxe.ds.Vector<Int>   = new haxe.ds.Vector( GamePad.PadKey.LENGTH );
	var longPressLock : haxe.ds.IntMap<Bool>  = new haxe.ds.IntMap();
	var hasAnyPress = false;

	function updateLongPress(k:PadKey) {
		var idx = k.getIndex();

		if( gc.isDown(k) || Key.isDown(getPrimaryKey(k)) || Key.isDown(getSecondaryKey(k)) || Key.isDown(getThirdKey(k)) || Key.isDown(getFourthKey(k)) ) {
			if( pressTimers.get(idx)==-1 )
				pressTimers.set(idx, haxe.Timer.stamp());

			// Long press detected
			if( haxe.Timer.stamp()-pressTimers.get(idx)>=LONG_PRESS ) {
				if( !longPressLock.exists(idx) ) {
					framePresses.set(idx, 2);
					hasAnyPress = true;
					longPressLock.set(idx,true);
				}
			}
		}
		else {
			if( longPressLock.exists(idx) )
				longPressLock.remove(idx);

			if( pressTimers.get(idx)!=-1 ) {
				if( framePresses.get(idx) < 0 ) {
					// Short press detected
					if( haxe.Timer.stamp()-pressTimers.get(idx)<=SHORT_PRESS ) {
						hasAnyPress = true;
						framePresses.set(idx, 1);
					}
				}
				pressTimers.set(idx, -1);
			}
		}
	}

	public static function beforeUpdate() {
		GamePad.update();


		for( c in ALL )
			if( c.gc!=null ) {
				if( c.allowAutoSwitch && c.mode!=Pad && (
						c.gc.isDown(A) || c.gc.isDown(B) || c.gc.isDown(X) || c.gc.isDown(Y)
						|| M.fabs(c.gc.getValue(AXIS_LEFT_X_POS))>=0.75 || M.fabs(c.gc.getValue(AXIS_LEFT_Y_POS))>=0.75
						|| M.fabs(c.gc.getValue(AXIS_RIGHT_X_POS))>=0.75 || M.fabs(c.gc.getValue(AXIS_RIGHT_Y_POS))>=0.75
					) )
					c.mode = Pad;

				if( c.hasAnyPress ) {
					c.hasAnyPress = false;
					for( idx in 0...c.framePresses.length ) c.framePresses[idx] = -1;
				}

				c.updateLongPress(A);
				c.updateLongPress(B);
				c.updateLongPress(X);
				c.updateLongPress(Y);
				c.updateLongPress(START);
				c.updateLongPress(DPAD_DOWN);
			}
	}

}

@:allow(dn.legacy.Controller)
class ControllerAccess {

	var parent : Controller;

	public var mode(get,never) : Mode; inline function get_mode() return parent.mode;
	var id : String;
	var manualLock = false;

	function new(parent:Controller, id:String, ?exclusive=false) {
		this.parent = parent;
		this.id = id + (Controller.UNIQ_ID++);
		parent.suspendTemp(0.1);
		if( exclusive )
			takeExclusivity();
	}


	var leftDeadZone : Null<Float>; // null means default controller deadZone
	var rightDeadZone : Null<Float>;

	public inline function setLeftDeadZone(?v:Float) {
		if( v==null )
			leftDeadZone = null;
		else
			leftDeadZone = dn.M.fclamp(v, 0, 1);
	}

	public inline function setRightDeadZone(?v:Float) {
		if( v==null )
			rightDeadZone = null;
		else
			rightDeadZone = dn.M.fclamp(v, 0, 1);
	}

	public inline function isKeyboard() return parent.mode==Keyboard;
	public inline function isGamePad() return parent.mode==Pad;

	public inline function lock() manualLock = true;
	public inline function unlock() manualLock = false;
	public inline function locked() return manualLock || parent.isLocked() || ( parent.exclusiveId!=null && parent.exclusiveId!=id ) || haxe.Timer.stamp()<parent.suspendTimer;


	public inline function isDown(k:PadKey)      return !locked() && ( isKeyboardDown(parent.getPrimaryKey(k)) || isKeyboardDown(parent.getSecondaryKey(k)) || isKeyboardDown(parent.getThirdKey(k)) || isKeyboardDown(parent.getFourthKey(k)) || parent.gc.isDown(k) );
	public inline function isPressed(k:PadKey)   return !locked() && ( isKeyboardPressed(parent.getPrimaryKey(k)) || isKeyboardPressed(parent.getSecondaryKey(k)) || isKeyboardPressed(parent.getThirdKey(k)) || isKeyboardPressed(parent.getFourthKey(k)) || parent.gc.isPressed(k) );

	public inline function isShortPressed(k:PadKey)  return !locked() && parent.framePresses.get(k.getIndex())==1;
	public inline function isLongPressed(k:PadKey)   return !locked() && parent.framePresses.get(k.getIndex())==2;
	public inline function isLongPressing(k:PadKey)  return !locked() && getLongPressRatio(k)>0;

	public inline function leftDown()        return isDown(AXIS_LEFT_X_NEG);
	public inline function leftPressed()     return isPressed(AXIS_LEFT_X_NEG);
	public inline function dpadLeftDown()    return isDown(DPAD_LEFT);
	public inline function dpadLeftPressed() return isPressed(DPAD_LEFT);

	public inline function rightDown()        return isDown(AXIS_LEFT_X_POS);
	public inline function rightPressed()     return isPressed(AXIS_LEFT_X_POS);
	public inline function dpadRightDown()    return isDown(DPAD_RIGHT);
	public inline function dpadRightPressed() return isPressed(DPAD_RIGHT);

	public inline function upDown()          return isDown(AXIS_LEFT_Y_POS);
	public inline function upPressed()       return isPressed(AXIS_LEFT_Y_POS);
	public inline function dpadUpDown()      return isDown(DPAD_UP);
	public inline function dpadUpPressed()   return isPressed(DPAD_UP);

	public inline function downDown()        return isDown(AXIS_LEFT_Y_NEG);
	public inline function downPressed()     return isPressed(AXIS_LEFT_Y_NEG);
	public inline function dpadDownDown()    return isDown(DPAD_DOWN);
	public inline function dpadDownPressed() return isPressed(DPAD_DOWN);
	public inline function dpadDownLongPressed()    return !locked() && parent.framePresses.get(DPAD_DOWN.getIndex())==2;
	public inline function dpadDownLongPressing()   return !locked() && getLongPressRatio(DPAD_DOWN)>0;
	public inline function dpadDownLongPressRatio() return getLongPressRatio(DPAD_DOWN);

	public inline function aDown()           return isDown(A);
	public inline function aPressed()        return isPressed(A);
	public inline function aShortPressed()   return !locked() && parent.framePresses.get(A.getIndex())==1;
	public inline function aLongPressed()    return !locked() && parent.framePresses.get(A.getIndex())==2;
	public inline function aLongPressing()   return !locked() && getLongPressRatio(A)>0;
	public inline function aLongPressRatio() return getLongPressRatio(A);

	public inline function bDown()           return isDown(B);
	public inline function bPressed()        return isPressed(B);
	public inline function bShortPressed()   return !locked() && parent.framePresses.get(B.getIndex())==1;
	public inline function bLongPressed()    return !locked() && parent.framePresses.get(B.getIndex())==2;
	public inline function bLongPressing()   return !locked() && getLongPressRatio(B)>0;
	public inline function bLongPressRatio() return getLongPressRatio(B);

	public inline function xDown()           return isDown(X);
	public inline function xPressed()        return isPressed(X);
	public inline function xShortPressed()   return !locked() && parent.framePresses.get(X.getIndex())==1;
	public inline function xLongPressed()    return !locked() && parent.framePresses.get(X.getIndex())==2;
	public inline function xLongPressing()   return !locked() && getLongPressRatio(X)>0;
	public inline function xLongPressRatio() return getLongPressRatio(X);

	public inline function yDown()           return isDown(Y);
	public inline function yPressed()        return isPressed(Y);
	public inline function yShortPressed()   return !locked() && parent.framePresses.get(Y.getIndex())==1;
	public inline function yLongPressed()    return !locked() && parent.framePresses.get(Y.getIndex())==2;
	public inline function yLongPressing()   return !locked() && getLongPressRatio(Y)>0;
	public inline function yLongPressRatio() return getLongPressRatio(Y);

	public inline function leftAngle() return Math.atan2( -lyValue(), lxValue() );
	public inline function leftDist() return M.fmax( M.fabs(lxValue()), M.fabs(lyValue()) );
	public inline function rightAngle() return Math.atan2( -ryValue(), rxValue() );
	public inline function rightDist() return M.fmax( M.fabs(rxValue()), M.fabs(ryValue()) );

	public inline function lxValue() : Float {
		if( isKeyboard() )
			return leftDown() ? -1 : rightDown() ? 1 : 0;
		else
			return parent.gc.getValue(AXIS_LEFT_X_POS, false, leftDeadZone);
	}

	public inline function lyValue() : Float {
		if( isKeyboard() )
			return upDown() ? -1 : downDown() ? 1 : 0;
		else
			return parent.gc.getValue(AXIS_LEFT_Y_POS, false, leftDeadZone);
	}

	public inline function rxValue()         return parent.gc.getValue(AXIS_RIGHT_X, false, rightDeadZone);
	public inline function ryValue()         return parent.gc.getValue(AXIS_RIGHT_Y, false, rightDeadZone);

	public inline function ltDown()          return isDown(LT);
	public inline function ltPressed()       return isPressed(LT);

	public inline function rtDown()          return isDown(RT);
	public inline function rtPressed()       return isPressed(RT);

	public inline function lbDown()          return isDown(LB);
	public inline function lbPressed()       return isPressed(LB);

	public inline function rbDown()          return isDown(RB);
	public inline function rbPressed()       return isPressed(RB);

	public inline function startPressed()    return isPressed(START);
	public inline function selectPressed()   return isPressed(SELECT);

	public inline function rumble(strength:Float, time_s:Float){
		return parent.gc.rumble( strength, time_s );
	}

	public inline function takeExclusivity()  parent.exclusiveId = id;

	public inline function releaseExclusivity() {
		if( parent.exclusiveId==id ) {
			parent.exclusiveId = null;
			parent.suspendTemp();
		}
	}

	public inline function isKeyboardDown(k:Null<Int>)     return k!=null && !locked() && Key.isDown(k);
	public inline function isKeyboardUp(k:Null<Int>)       return k!=null && !locked() && !Key.isDown(k);
	public inline function isKeyboardPressed(k:Null<Int>)  return k!=null && !locked() && Key.isPressed(k);

	public function dispose() {
		releaseExclusivity();
		parent.suspendTemp();
	}


	public inline function getLongPressRatio(k:PadKey) : Float {
		if( parent.framePresses.get(k.getIndex()) > 0 || parent.pressTimers.get(k.getIndex())<0 )
			return 0;

		return dn.M.fclamp( ( haxe.Timer.stamp()-parent.pressTimers.get(k.getIndex()) - Controller.SHORT_PRESS ) / ( Controller.LONG_PRESS - Controller.SHORT_PRESS ), 0, 1 );
	}

}
