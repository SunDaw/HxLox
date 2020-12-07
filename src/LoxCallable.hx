interface LoxCallable {
    public final arity: Int;
    function call(intepreter: Interpreter, arguments: haxe.ds.ReadOnlyArray<Any>): Any;
}

class Clock implements LoxCallable {
    public final arity = 0;

    public function new() {}

    public function call(intepreter: Interpreter, arguments: haxe.ds.ReadOnlyArray<Any>): Any {
        return Date.now().getTime();
    }
}