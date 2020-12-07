# HxLox

A pure Haxe implementation of the Tree-Walk Interpreter from [Crafting Interpreters](http://craftinginterpreters.com/a-tree-walk-interpreter.html).   
Read the amazing book for more information about the theory behind it.

It should work on any of Haxe's `sys` targets ([Check the official website for more information](https://haxe.org/documentation/introduction/compiler-targets.html)), although it has only been tested on HashLink and HashLink/C

## Differences to Java version

As Haxe supports pattern matching this implementation uses it instead of the Visitor Pattern of the original Java version described in the book. This also leads to some other minor differences in other places.