import Interpreter.RuntimeError;

class Environment {
    @:allow(Interpreter.visitStmt) final enclosing: Environment;
    final values: Map<String, Any> = [];

    public function new(?enclosing: Environment) {
        this.enclosing = enclosing;
    }

    @:allow(Interpreter) function get(name: Token): Any {
        final value = values.get(name.lexeme);
        if (value != null) {
            return value;
        }

        if (enclosing != null) return enclosing.get(name);

        throw new RuntimeError(name, 'Undefined variable "${name.lexeme}".');
    }

    @:allow(Interpreter) function assign(name: Token, value: Any): Void {
        if (values.exists(name.lexeme)) {
            values.set(name.lexeme, value);
            return;
        } 
        
        if (enclosing != null) {
            enclosing.assign(name, value);
            return;
        }

        throw new RuntimeError(name, 'Undefined variable "${name.lexeme}".');
    }

    public inline function define(name: String, value: Any): Void {
        values[name] = value;
    }

    function ancestor(distance: Int): Environment {
        var environment = this;
        for (i in 0...distance) {
            environment = environment.enclosing;
        }

        return environment;
    }

    @:allow(Interpreter, LoxFunction) function getAt(distance: Int, name: String): Any {
        return ancestor(distance).values.get(name);
    }

    @:allow(Interpreter) function assignAt(distance: Int, name: Token, value: Any): Void {
        ancestor(distance).values.set(name.lexeme, value);
    }
}