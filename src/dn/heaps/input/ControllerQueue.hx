package dn.heaps.input;

import dn.heaps.input.*;
import dn.heaps.input.Controller;
import dn.struct.FixedArray;
import dn.Col;

class ControllerQueue<T:Int> {
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
				events.get(a).onDown(curTimeS);
			else
				events.get(a).onUp(curTimeS);
	}


	public function stopWatch(a:T) {
		watches.remove(a);
		events.remove(a);
	}


	/**
		Check if given `action` was pressed recently, and removes it from history if TRUE.

		By default, the press events chronological order is respected. So, if another action was pressed before the one requested, this method would return FALSE accordingly.

		If `ignoreChronologicalOrder` is FALSE, then the chronological order is ignored.

		**Example**: if the user quickly pressed the A,B,C,D actions sequence:
		- `checkAndPopPress(B)` would return FALSE (A is queued before B)
		- `checkAndPopPress(B, true)` would return TRUE, and B would be consumed from the queue, A would also be discarded because it happened before B, and C and D would stay in the queue.

	**/
	public function consumePress(action:T, ignoreChronologicalOrder=false) {
		var nextT = events.get(action).getNextPress();
		if( !ignoreChronologicalOrder ) {
			for(ev in events)
				if( ev.action!=action && ev.getNextPress()<nextT )
					return false;
		}
		var pressed = events.get(action).popPress(curTimeS);
		if( ignoreChronologicalOrder && pressed )
			for(ev in events)
				ev.clearStackUntil(ev.presses, nextT);

		return pressed;
	}


	/**
		Check if the `action` press event is in the queue. This method doesn't "consume" the event from the queue.

		See `consumePress` for more info.
	**/
	public function peekPress(action:T, ignoreChronologicalOrder=false) {
		var nextT = events.get(action).getNextPress();
		if( !ignoreChronologicalOrder ) {
			for(ev in events)
				if( ev.action!=action && ev.getNextPress()<nextT )
					return false;
		}
		return events.get(action).peekPress(curTimeS);
	}


	public function clearAllQueues() {
		for(ev in events)
			ev.clear();
	}

	public function clearQueue(a:T) {
		if( events.exists(a) )
			events.get(a).clear();
	}


	/**
		Manually insert fake press/release event
	**/
	public function emulatePressRelease(a:T) {
		if( events.exists(a) ) {
			events.get(a).presses.push(curTimeS);
			events.get(a).releases.push(curTimeS+0.06);
		}
	}


	public function createDebugger(parent:dn.Process) {
		var p = parent.createChildProcess();
		p.createRootInLayers(parent.root, 99999);
		var wrapper = new h2d.Object(p.root);

		var font = hxd.res.DefaultFont.get();

		p.onUpdateCb = ()->{
			wrapper.removeChildren();
			var i = 0;
			var lineHei = 32;
			var secondWid = 100;
			var labelWid = 60;
			for(ev in events) {
				var rowWrapper = new h2d.Object(wrapper);
				rowWrapper.y = i*lineHei;

				var rowColor : Col = ev.peekPress(curTimeS) || ev.peekRelease(curTimeS) ? Green : Red;

				// Full line bg
				var bg = new h2d.Graphics(rowWrapper);
				bg.beginFill(rowColor.toBlack(0.5), 0.9);
				bg.drawRect(0,0, labelWid + ev.maxKeepDurationS*secondWid, lineHei-1);
				bg.endFill();

				// Label
				var tf = new h2d.Text(font, rowWrapper);
				tf.text = Const.resolveGameActionName(ev.action);

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
				inline function _renderStack(stack:Array<Float>, col:dn.Col) {
					ev.gc(stack, curTimeS);
					for(t in stack) {
						g.beginFill(col,1);
						g.lineStyle(1, col.toWhite(0.3));
						g.drawCircle((ev.maxKeepDurationS-(curTimeS-t))*secondWid, eventIdx*eventHei + eventHei*0.5, eventHei*0.5);
						g.endFill();
					}
					eventIdx++;
				}
				_renderStack(ev.presses, Green);
				_renderStack(ev.releases, Orange);

				i++;
			}
		}

		// p.onResizeCb = ()->{
			// p.root.setScale( dn.heaps.Scaler.bestFit_i(300));
		// }

		p.onDisposeCb = ()->{}

		return p;
	}
}



private class QueueEventStacks<T> {
	public var action(default,null) : T;
	var wasDown = false;
	public var presses(default,null) : Array<Float>;
	public var releases(default,null) : Array<Float>;
	public var maxKeepDurationS(default,null) : Float;

	public function new(a:T, maxKeepDurationS:Float) {
		action = a;
		presses = [];
		releases = [];
		this.maxKeepDurationS = maxKeepDurationS;
	}

	public function onDown(curTimeS:Float) {
		if( !wasDown ) {
			wasDown = true;
			presses.push(curTimeS);
			gc(presses, curTimeS);
		}
	}

	public function onUp(curTimeS:Float) {
		if( wasDown ) {
			wasDown = false;
			releases.push(curTimeS);
			gc(releases, curTimeS);
		}
	}


	public inline function getNextPress() {
		return presses.length>0 ? presses[0] : 999999;
	}

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
		wasDown = false;
		presses = [];
		releases = [];
	}
}