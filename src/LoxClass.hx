class LoxClass implements LoxCallable {
    @:allow(LoxInstance) final name: String;
    public final arity: Int;
    final superclass: LoxClass;
    final methods: Map<String, LoxFunction>;

    public function new(name: String, superclass: LoxClass, methods: Map<String, LoxFunction>) {
        this.name = name;
        this.superclass = superclass;
        this.methods = methods;
        final initializer = findMethod("init");
        arity = if (initializer == null) 0 else initializer.arity;
    }

    public function findMethod(name: String): LoxFunction {
        var method = methods.get(name);
        if (method != null) {
            return method;
        }

        if (superclass != null) {
            return superclass.findMethod(name);
        }

        return null;
    }

    public function toString(): String {
        return name;
    }

    public function call(interpeter: Interpreter, arguments: haxe.ds.ReadOnlyArray<Any>): Any {
        final instance = new LoxInstance(this);
        final initializer = findMethod("init");
        if (initializer != null) {
            initializer.bind(instance).call(interpeter, arguments);
        }

        return instance;
    }
}