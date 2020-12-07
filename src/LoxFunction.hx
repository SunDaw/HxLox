import haxe.ds.ReadOnlyArray;

class LoxFunction implements LoxCallable {
    public final arity: Int;
    final name: Token;
    final params: ReadOnlyArray<Token>;
    final body: ReadOnlyArray<Stmt>;
    final closure: Environment;
    final isInitializer: Bool;

    @:allow(Interpreter) function new(name: Token, params: ReadOnlyArray<Token>, body: ReadOnlyArray<Stmt>, closure: Environment, isInitializer: Bool) {
        this.name = name;
        this.params = params;
        this.body = body;
        arity = params.length;
        this.closure = closure;
        this.isInitializer = isInitializer;
    }

    public function bind(instance: LoxInstance): LoxFunction {
        final environment = new Environment(closure);
        environment.define("this", instance);
        return new LoxFunction(name, params, body, environment, isInitializer);
    }

    public function call(intepreter: Interpreter, arguments: haxe.ds.ReadOnlyArray<Any>): Any {
        final environment = new Environment(closure);
        for (i in 0...params.length) {
            environment.define(params[i].lexeme, arguments[i]);
        }

        try {
            intepreter.executeBlock(body, environment);
        } catch (returnValue: Return) {
            if (isInitializer) return closure.getAt(0, "this");
            return returnValue.value;
        }

        if (isInitializer) return closure.getAt(0, "this");
        return null;
    }

    public function toString(): String {
        return '<fn ${name.lexeme}>';
    }
}