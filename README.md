# About

The general purpose libs I use in all my Haxe projects. If you want to build one of [my project](https://github.com/deepnight/), you will need them.

[![Unit tests](https://github.com/deepnight/deepnightLibs/actions/workflows/runUnitTests.yml/badge.svg)](https://github.com/deepnight/deepnightLibs/actions/workflows/runUnitTests.yml)

# Install

## Stable

Use this version if you plan to use the libs for your own projects.

```bash
haxelib install deepnightLibs
```

## Latest Git version (mostly stable)

This is the version I use and update very frequently.

Pick this version if you're building one of my GitHub projects, such as LDtk or one of my gamejam entry.

```bash
haxelib git deepnightLibs https://github.com/deepnight/deepnightLibs
```

# Usage

In your HXML file, add:
```hxml
-lib deepnightLibs
```

All the libs are in the `dn.*` package.

```haxe
class MyProject {
	public function new() {
		trace( dn.M.fmin(0.3,0.8) ); // 0.3
	}
}
```

# Tips

Use global imports! To import libs in every HX files, just add a ``import.hx`` (this exact name & caps) file to the **root** of your ``src`` folder:

```
dn.*;
dn.Col as C;
```

 - The first line imports all classes in ``dn`` package,

 - The second one imports ``dn.Col`` as an alias "C",

 - Feel free to add your own convenient imports there.

# Noteworthy classes

## dn.M

My re-implementation of the Math class, with high-performances in mind:

```haxe
M.fmin(0.5, 0.9); // 0.5
M.frandRange(0, 2); // random Float number between 0 -> 2
M.randRange(0, 2); // either 0, 1 or 2
M.pow(val, 2); // turns into val*val at compilation time
```

## dn.Col

The color management lib, with performance in mind.

A color is an abstract class that revolves around a single Integer value (the color in 0xaarrggbb format). Most methods are just operations on this internal Int value.

```haxe
import dn.Col;
var c : Col = 0xff0000;  // red
var c : Col = Red;  // also red, but using and enum constant
var c : Col = "#ff0000"; // still red, but the conversion from a constant String to Int is hard-inlined using macros. Costs 0 at runtime.
var darker = c.toBlack(0.5); // return a 50% darker red
var c2 = c.to(Yellow, 0.3); // return a mix from current color with 30% of the standard yellow
```

## dn.DecisionHelper

A nice tool to easily pick a value among many others using any custom criterion.

```haxe
var arr = [ "a", "foo", "bar", "food", "hello" ];

var dh = new dn.DecisionHelper(arr);

/* Iterates all values in arr and increase their internal score by 1 if they contain the letter "o". */
dh.score( v -> StringTools.contains(v,"o") ? 1 : 0 );

/* Increase score of each values using 10% of their length (ie. longer strings get slightly higher score) */
dh.score( v -> v.length*0.1 );

/* Discard any value containing the letter "h" */
dh.remove( v -> StringTools.contains(v,"h") );

/* Only keep values with length>1 */
dh.keepOnly( v -> v.length>1 );

trace( dh.getBest() ); // -> food
/* Internal scores: a (discarded), foo (1.3), bar (0.3), food (1.4), hello (discarded). */
```
