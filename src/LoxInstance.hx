import Interpreter.RuntimeError;

class LoxInstance {
    final klass: LoxClass;
    final fields: Map<String, Any> = [];

    public function new(klass: LoxClass) {
        this.klass = klass;
    }

    public function get(name: Token): Any {
        final field = fields.get(name.lexeme);
        if (field != null) return field;

        final method = klass.findMethod(name.lexeme);
        if (method != null) return method.bind(this);

        throw new RuntimeError(name, 'Undefined property \'${name.lexeme}\'.');
    }

    public function set(name: Token, value: Any): Void {
        fields.set(name.lexeme, value);
    }

    public function toString(): String {
        return '${klass.name} instance';
    }
}