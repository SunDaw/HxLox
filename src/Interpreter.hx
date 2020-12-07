import LoxCallable.Clock;
import haxe.ds.ReadOnlyArray;
import haxe.Exception;

class RuntimeError extends Exception {
    @:allow(Lox.runtimeError) final token: Token;

    public function new(token, message) {
        super(message);
        this.token = token;
    }
}

class Interpreter {
    final globals = new Environment();
    var environment: Environment;
    final locals: Map<Expr, Int> = [];

    public function new() {
        environment = globals;

        globals.define("clock", new Clock());
    }

    public function interpret(statements: ReadOnlyArray<Stmt>): Void {
        try {
            for (statement in statements) {
                visitStmt(statement);
            }
        } catch (error: RuntimeError) {
            Lox.runtimeError(error);
        }
    }

    @:allow(Resolver) function resolve(expr: Expr, depth: Int): Void {
        locals.set(expr, depth);
    }

    function visitStmt(stmt: Stmt): Void {
        switch (stmt) {
            case Expression(expression): visitExpr(expression);
            case Print(expression): {
                final value = visitExpr(expression);
                Sys.println(stringify(value));
            }
            case Var(name, initializer): {
                final value = if (initializer != null) {
                    visitExpr(initializer);
                } else {
                    null;
                }

                environment.define(name.lexeme, value);
            }
            case Block(statements): executeBlock(statements, new Environment(environment));
            case If(condition, thenBranch, elseBranch): {
                if (isTruthy(visitExpr(condition))) {
                    visitStmt(thenBranch);
                } else if (elseBranch != null) {
                    visitStmt(elseBranch);
                }
            }
            case While(condition, body): {
                while (isTruthy(visitExpr(condition))) {
                    visitStmt(body);
                }
            }
            case Function(name, params, body): {
                final func = new LoxFunction(name, params, body, environment, false);
                environment.define(name.lexeme, func);
            }
            case Return(keyword, value): {
                final retValue = if (value != null) {
                    visitExpr(value);
                } else {
                    null;
                }

                throw new Return(retValue);
            }
            case Class(name, superclass, methods): {
                final superKlass = if (superclass != null) {
                    final temp = visitExpr(superclass);
                    if (!Std.isOfType(temp, LoxClass)) {
                        switch (superclass) {
                            case Variable(name): throw new RuntimeError(name, "Superclass must be a class.");
                            default: throw new RuntimeError(null, "Superclass must be a class.");
                        }
                    }
                    temp;
                } else {
                    null;
                }

                environment.define(name.lexeme, null);

                if (superclass != null) {
                    environment = new Environment(environment);
                    environment.define("super", superKlass);
                }

                final klassMethods: Map<String, LoxFunction> = [];
                for (method in methods) {
                    switch (method) {
                        case Function(name, params, body): {
                            final func = new LoxFunction(name, params, body, environment, name.lexeme == "this");
                            klassMethods.set(name.lexeme, func);
                        }
                        default: 
                    }
                }

                final klass = new LoxClass(name.lexeme, cast(superKlass, LoxClass), klassMethods);

                if (superclass != null) {
                    environment = environment.enclosing;
                }

                environment.assign(name, klass);
            }
        }
    }

    @:allow(LoxFunction) function executeBlock(statements: ReadOnlyArray<Stmt>, environment: Environment): Void {
        final previous = this.environment;
        try {
            this.environment = environment;

            for (statement in statements) {
                visitStmt(statement);
            }
        } catch (e) {
            this.environment = previous;
            throw e;
        }

        this.environment = previous;
    }

    final function visitExpr(expr: Expr): Any {
        return switch (expr) {
            case Grouping(expression): visitExpr(expression);
            case Unary(op, right): {
                final rightValue = visitExpr(right);

                return switch (op.type) {
                    case BANG: !isTruthy(rightValue);
                    case MINUS: checkNumberOperand(op, rightValue); -cast(rightValue, Float);
                    default: throw new RuntimeError(op, 'Unexpected operand in unary expression');
                }
            }
            case Binary(left, op, right): {
                final leftValue = visitExpr(left);
                final rightValue = visitExpr(right);

                return switch (op.type) {
                    case GREATER: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) > cast(rightValue, Float);
                    case GREATER_EQUAL: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) >= cast(rightValue, Float);
                    case LESS: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) < cast(rightValue, Float);
                    case LESS_EQUAL: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) <= cast(rightValue, Float);
                    case MINUS: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) - cast(rightValue, Float);
                    case SLASH: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) / cast(rightValue, Float);
                    case STAR: checkNumberOperands(op, leftValue, rightValue); cast(leftValue, Float) * cast(rightValue, Float);
                    case PLUS: {
                        if (Std.isOfType(leftValue, Float) && Std.isOfType(rightValue, Float)) {
                            return cast(leftValue, Float) + cast(rightValue, Float);
                        }

                        if (Std.isOfType(leftValue, String) && Std.isOfType(rightValue, String)) {
                            return cast(leftValue, String) + cast(rightValue, String);
                        }

                        throw new RuntimeError(op, "Operands must be two numbers or two strings.");
                    }
                    case BANG_EQUAL: !isEqual(leftValue, rightValue);
                    case EQUAL_EQUAL: isEqual(leftValue, rightValue);
                    default: throw new RuntimeError(op, 'Unexpected operand in binary expression');
                }
            }
            case Literal(value): value;
            case Variable(name): lookupVariable(name, expr);
            case Assign(name, value): {
                final value = visitExpr(value);

                final distance = locals.get(expr);
                if (distance != null) {
                    environment.assignAt(distance, name, value);
                } else {
                    globals.assign(name, value);
                }
                
                return value;
            }
            case Logical(left, op, right): {
                final leftValue = visitExpr(left);

                if (op.type == OR) {
                    if (isTruthy(leftValue)) return leftValue;
                } else {
                    if (!isTruthy(leftValue)) return leftValue;
                }

                return visitExpr(right);
            }
            case Call(callee, paren, arguments): {
                final calleeValue = visitExpr(callee);
                final argumentValues = [for (argument in arguments) visitExpr(argument)];

                if (!Std.isOfType(calleeValue, LoxCallable)) {
                    throw new RuntimeError(paren, "Can only call functions and classes.");
                }

                final func = cast(calleeValue, LoxCallable);

                if (argumentValues.length != func.arity) {
                    throw new RuntimeError(paren, 'Expected ${func.arity} arguments but got ${argumentValues.length}.');
                }

                return func.call(this, argumentValues);
            }
            case Get(object, name): {
                final object = visitExpr(object);
                if (Std.isOfType(object, LoxInstance)) {
                    return cast(object, LoxInstance).get(name);
                }

                throw new RuntimeError(name, "Only instances have properties.");
            }
            case Set(object, name, value): {
                final object = visitExpr(object);

                if (!Std.isOfType(object, LoxInstance)) {
                    throw new RuntimeError(name, "Only instances have fields.");
                }

                final value = visitExpr(value);
                cast(object, LoxInstance).set(name, value);
                return value;
            }
            case This(keyword): {
                lookupVariable(keyword, expr);
            }
            case Super(keyword, method): {
                final distance = locals.get(expr);
                final superclass = cast(environment.getAt(distance, "super"), LoxClass);

                // "this" is always one level nearer than "super"'s environment.
                final object = cast(environment.getAt(distance - 1, "this"), LoxInstance);

                final supermethod = superclass.findMethod(method.lexeme);

                if (supermethod == null) {
                    throw new RuntimeError(method, 'Undefined property \'method.lexeme\'.');
                }

                return supermethod.bind(object);
            }
        }
    }

    function lookupVariable(name: Token, expr: Expr): Any {
        final distance = locals.get(expr);
        if (distance != null) {
            return environment.getAt(distance, name.lexeme);
        } else {
            return globals.get(name);
        }
    }

    inline function checkNumberOperand(op: Token, operand: Any): Void {
        if (Std.isOfType(operand, Float)) return;
        throw new RuntimeError(op, "Operand must be a number.");
    }

    inline function checkNumberOperands(op: Token, left: Any, right: Any): Void {
        if (Std.isOfType(left, Float) && Std.isOfType(right, Float)) return;
        throw new RuntimeError(op, "Operands must be numbers.");
    }

    function isTruthy(object: Any): Bool {
        if (object == null) return false;
        if (Std.isOfType(object, Bool)) return cast(object, Bool);
        return true;
    }

    function isEqual(a: Any, b: Any): Bool {
        // nil is only equal to nil.
        if (a == null && b == null) return true;
        if (a == null) return false;

        return a == b;
    }

    inline function stringify(object: Any): String {
        return if (object == null) "nil" else Std.string(object);
    }
}