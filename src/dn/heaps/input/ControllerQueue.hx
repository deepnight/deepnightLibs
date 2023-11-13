package dn.heaps.input;

import dn.heaps.input.*;
import dn.heaps.input.Controller;
import dn.struct.FixedArray;
import dn.Col;

class ControllerQueue<T:Int> {
	@:allow(dn.heaps.input.QueueEventStacks)
	var curTimeS = 0.;
	var watches : Array<T> = [];
	var ca : ControllerAccess<T>;
	var events : Map<T, QueueEventStacks<T>> = new Map();
	public var defaultMaxKeepDurationS(default,null) : Float;

	public function new(ca:ControllerAccess<T>, defaultMaxKeepDurationS=0.6) {
		this.ca = ca;
		this.defaultMaxKeepDurationS = defaultMaxKeepDurationS;
	}

	public function watch(?action:T, ?actions:Array<T>, ?maxKeepDurationS=-1.) {
		if( action==null && actions==null || action!=null && actions!=null )
			throw "Need 1 argument";

		if( actions==null )
			actions = [action];

		for(a in actions) {
			stopWatch(a);
			watches.push(a);
			events.set(a, new QueueEventStacks(a, maxKeepDurationS<=0 ? defaultMaxKeepDurationS : maxKeepDurationS));
		}
	}


	/**
		This update MUST be called as early as possible, in each frame.

		`curTimeS` is the context timestamp, in seconds.
	**/
	public function earlyFrameUpdate(curTimeS:Float) {
		this.curTimeS = curTimeS;
		for(a in watches)
			if( ca.isDown(a) )
				events.get(a).onDown(this);
			else
				events.get(a).onUp(this);
	}

	public dynamic function onQueuePress(action:T) {}
	public dynamic function onQueueRelease(action:T) {}


	public function stopWatch(a:T) {
		watches.remove(a);
		events.remove(a);
	}


	/**
		Check if given `action` was Pressed recently, and if TRUE, consumes (removes) it from history.

		By default, the Press events chronological order is respected. So, if another action was Pressed before the one requested, this method would return FALSE accordingly.

		If `ignoreChronologicalOrder` is FALSE, then the chronological order is ignored.

		**Example**: if the user quickly pressed the A,B,C,D actions sequence:
		- `consumePress(B)` would return FALSE (A is queued before B)
		- `consumePress(B, true)` would return TRUE, and B would be consumed from the queue, A would also be discarded because it happened before B, and C and D would stay in the queue.
	**/
	public function consumePress(action:T, ignoreChronologicalOrder=false) {
		if( !peekPress(action, ignoreChronologicalOrder) )
			return false;

		var nextT = events.get(action).getNextPress();
		events.get(action).popPress(curTimeS);

		if( ignoreChronologicalOrder )
			for(ev in events)
				ev.clearStackUntil(ev.presses, nextT);

		return true;
	}


	/**
		Check if the `action` press event is in the queue. This method doesn't "consume" the event from the queue.

		See `consumePress` for more info.
	**/
	public function peekPress(action:T, ignoreChronologicalOrder=false) {
		var nextT = events.get(action).getNextPress();
		if( !ignoreChronologicalOrder ) {
			for(ev in events) {
				ev.gc(ev.presses, curTimeS);
				if( ev.action!=action && ev.getNextPress()<nextT )
					return false;
			}
		}
		return events.get(action).peekPress(curTimeS);
	}



	/**
		Check if given `action` was Released recently, and if TRUE, consumes (removes) it from history.

		See `consumePress()` for more info.
	**/
	public function consumeRelease(action:T, ignoreChronologicalOrder=false) {
		if( !peekRelease(action, ignoreChronologicalOrder) )
			return false;

		var nextT = events.get(action).getNextRelease();
		events.get(action).popRelease(curTimeS);

		if( ignoreChronologicalOrder )
			for(ev in events)
				ev.clearStackUntil(ev.releases, nextT);

		return true;
	}

	/**
		Check if the `action` Release event is in the queue. This method doesn't "consume" the event from the queue.

		See `consumeRelease` for more info.
	**/
	public function peekRelease(action:T, ignoreChronologicalOrder=false) {
		var nextT = events.get(action).getNextRelease();
		if( !ignoreChronologicalOrder ) {
			for(ev in events) {
				ev.gc(ev.releases, curTimeS);
				if( ev.action!=action && ev.getNextRelease()<nextT )
					return false;
			}
		}
		return events.get(action).peekRelease(curTimeS);
	}


	/**
		Same as `consumePressOrDown` but also returns TRUE if the action button is currently down.
	**/
	public inline function consumePressOrDown(action:T, ignoreChronologicalOrder=false) {
		if( consumePress(action,ignoreChronologicalOrder) )
			return true;
		else
			return ca.isDown(action);
	}


	/**
		Same as `peekPress` but also returns TRUE if the action button is currently down.
	**/
	public inline function peekPressOrDown(action:T, ignoreChronologicalOrder=false) {
		return ca.isDown(action) || peekPress(action, ignoreChronologicalOrder);
	}


	public function clearAllQueues() {
		for(ev in events)
			ev.clear();
	}

	public function clearQueue(a:T) {
		if( events.exists(a) )
			events.get(a).clear();
	}


	/** Manually insert fake Press event (no corresponding Release) **/
	public function emulatePressOnly(a:T) {
		if( events.exists(a) )
			events.get(a).presses.push(curTimeS);
	}


	/** Manually insert fake Release event (no corresponding Press) **/
	public function emulateReleaseOnly(a:T) {
		if( events.exists(a) )
			events.get(a).releases.push(curTimeS);
	}


	/** Manually insert a fake Press event followed by a fake Release event **/
	public function emulatePressAndRelease(a:T) {
		if( events.exists(a) ) {
			events.get(a).presses.push(curTimeS);
			events.get(a).releases.push(curTimeS+0.06);
		}
	}


	public function createDebugger(parent:dn.Process, ?actionNameResolver:T->String) {
		var p = parent.createChildProcess();
		p.createRootInLayers(parent.root, 99999);
		var wrapper = new h2d.Object(p.root);

		var font = hxd.res.DefaultFont.get();

		@:privateAccess(QueueEventStacks)
		p.onUpdateCb = ()->{
			wrapper.removeChildren();
			var i = 0;
			var lineHei = 32;
			var secondWid = 100;
			var labelWid = 60;
			for(ev in events) {
				var rowWrapper = new h2d.Object(wrapper);
				rowWrapper.y = i*lineHei;

				var rowColor : Col = ev.wasDown ? Green : ev.lockedUntilUp ? Red : WarmMidGray;

				// Full line bg
				var bg = new h2d.Graphics(rowWrapper);
				bg.beginFill(rowColor.toBlack(0.5), 0.9);
				bg.drawRect(0,0, labelWid + ev.maxKeepDurationS*secondWid, lineHei-1);
				bg.endFill();

				// Label
				var tf = new h2d.Text(font, rowWrapper);
				tf.text = actionNameResolver!=null ? actionNameResolver(ev.action) : "#"+ev.action;

				var g = new h2d.Graphics(rowWrapper);
				g.x = labelWid;

				// Graph bg
				g.beginFill(Black, 0.3);
				g.drawRect(0,0, ev.maxKeepDurationS*secondWid, lineHei);
				g.endFill();

				// Graduations
				var t = 0.;
				while( t<ev.maxKeepDurationS ) {
					t+=0.1;
					g.lineStyle(1, rowColor, 0.3);
					g.moveTo(t*secondWid, 0);
					g.lineTo(t*secondWid, lineHei);
				}

				// Keep limit
				g.lineStyle(1, Red, 0.3);
				g.moveTo(0, 0);
				g.lineTo(0, lineHei);

				// Event stacks
				var eventIdx = 0;
				var eventHei = 8;
				inline function _renderStack(stack:Array<Float>, shape:Int, col:dn.Col) {
					ev.gc(stack, curTimeS);
					for(t in stack) {
						g.beginFill(col,1);
						g.lineStyle(1, col.toWhite(0.3));
						var x = (ev.maxKeepDurationS-(curTimeS-t))*secondWid;
						var y = eventIdx*eventHei;
						switch shape {
							case 0: // Down arrow
								g.moveTo(x-4, y);
								g.lineTo(x+4, y);
								g.lineTo(x, y+eventHei);
								g.lineTo(x-4, y);

							case 1: // Up arrow
								g.moveTo(x,y);
								g.lineTo(x+4, y+eventHei);
								g.lineTo(x-4, y+eventHei);
								g.lineTo(x, y);

							case _:
								g.drawCircle(x, y+eventHei*0.5, eventHei*0.5);
						}
						g.endFill();
					}
					eventIdx++;
				}
				_renderStack(ev.presses, 0, Green);
				_renderStack(ev.releases, 1, Orange);

				i++;
			}
		}

		p.onDisposeCb = ()->{}

		return p;
	}
}



private class QueueEventStacks<T> {
	var wasDown = false;
	var lockedUntilUp = false;
	public var action(default,null) : T;
	public var presses(default,null) : Array<Float>;
	public var releases(default,null) : Array<Float>;
	public var maxKeepDurationS(default,null) : Float;

	public function new(a:T, maxKeepDurationS:Float) {
		action = a;
		presses = [];
		releases = [];
		this.maxKeepDurationS = maxKeepDurationS;
	}

	public function onDown(queue:ControllerQueue<Dynamic>) {
		if( !lockedUntilUp && !wasDown ) {
			wasDown = true;
			presses.push(queue.curTimeS);
			gc(presses, queue.curTimeS);
			queue.onQueuePress(action);
		}
	}

	public function onUp(queue:ControllerQueue<Dynamic>) {
		if( lockedUntilUp )
			lockedUntilUp = false;

		if( wasDown ) {
			wasDown = false;
			releases.push(queue.curTimeS);
			gc(releases, queue.curTimeS);
			queue.onQueueRelease(action);
		}
	}


	public inline function getNextPress() return presses.length>0 ? presses[0] : 999999;
	public inline function getNextRelease() return releases.length>0 ? releases[0] : 999999;

	public inline function popPress(curTimeS:Float) return popFromStack(presses,curTimeS);
	public inline function popRelease(curTimeS:Float) return popFromStack(releases,curTimeS);

	public inline function peekPress(curTimeS:Float) return peekFromStack(presses,curTimeS);
	public inline function peekRelease(curTimeS:Float) return peekFromStack(releases,curTimeS);

	function popFromStack(stack:Array<Float>, curTimeS:Float) : Bool {
		gc(stack,curTimeS);
		if( stack.length>0 ) {
			stack.shift();
			return true;
		}
		else
			return false;
	}

	function peekFromStack(stack:Array<Float>, curTimeS:Float) : Bool {
		gc(stack,curTimeS);
		if( stack.length>0 )
			return true;
		else
			return false;
	}

	public function clearStackUntil(stack:Array<Float>, timeS:Float) {
		while( stack.length>0 && stack[0]<=timeS )
			stack.shift();
	}

	public inline function gc(stack:Array<Float>, curTimeS:Float) {
		while( stack.length>0 && curTimeS-stack[0]>maxKeepDurationS )
			stack.shift();
	}

	public function clear() {
		lockedUntilUp = true;
		wasDown = false;
		presses = [];
		releases = [];
	}
}