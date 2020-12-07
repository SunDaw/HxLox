enum FunctionType {
    NONE;
    FUNCTION;
    INITIALIZER;
    METHOD;
}

enum ClassType {
    NONE;
    CLASS;
    SUBCLASS;
}

class Resolver {
    final interpreter: Interpreter;
    final scopes: Array<Map<String, Bool>> = [];
    var currentFunction = FunctionType.NONE;
    var currentClass = ClassType.NONE;

    public function new(interpreter: Interpreter) {
        this.interpreter = interpreter;
    }

    public function visitStmt(stmt: Stmt): Void {
        switch (stmt) {
            case Block(statements): {
                beginScope();
                resolve(statements);
                endScope();
            }
            case Var(name, initializer): {
                declare(name);
                if (initializer != null) {
                    visitExpr(initializer);
                }
                define(name);
            }
            case Function(name, params, body): {
                declare(name);
                define(name);

                resolveFunction(params, body, FunctionType.FUNCTION);
            }
            case Expression(expression): visitExpr(expression);
            case If(condition, thenBranch, elseBranch): {
                visitExpr(condition);
                visitStmt(thenBranch);
                if (elseBranch != null) visitStmt(elseBranch);
            }
            case Print(expression): visitExpr(expression);
            case Return(keyword, value): { 
                if (currentFunction == NONE) {
                    Lox.errorToken(keyword, "Cannot return from top-level code.");
                }
                if (value != null) {
                    if (currentFunction == INITIALIZER) {
                        Lox.errorToken(keyword, "Cannot return a value from an initializer.");
                    }

                    visitExpr(value);
                }
            }
            case While(condition, body): {
                visitExpr(condition);
                visitStmt(body);
            }
            case Class(name, superclass, methods): {
                final enclosingClass = currentClass;
                currentClass = ClassType.CLASS;

                declare(name);
                define(name);

                if (superclass != null) {
                    switch (superclass) {
                        case Variable(supername): {
                            if (name.lexeme == supername.lexeme) {
                                Lox.errorToken(supername, "A class cannot inherit from itself.");
                            }
                        }
                        default: 
                    }
                    currentClass = ClassType.SUBCLASS;
                    visitExpr(superclass);

                    if (superclass != null) {
                        beginScope();
                        scopes[scopes.length - 1].set("super", true);
                    }
                }

                beginScope();
                scopes[scopes.length - 1].set("this", true);

                for (method in methods) {
                    switch (method) {
                        case Function(name, params, body): {
                            var declaration = FunctionType.METHOD;
                            if (name.lexeme == "init") {
                                declaration = FunctionType.INITIALIZER;
                            }
                            resolveFunction(params, body, declaration);
                        }
                        default: 
                    }
                }

                endScope();

                if (superclass != null) {
                    endScope();
                }

                currentClass = enclosingClass;
            }
        }
    }

    public function visitExpr(expr: Expr): Void {
        switch (expr) {
            case Variable(name): {
                if (scopes.length != 0 && scopes[scopes.length - 1].get(name.lexeme) == false) {
                    Lox.errorToken(name, "Cannot read local variable in its own initializer.");
                }

                resolveLocal(expr, name);
            }
            case Assign(name, value): {
                visitExpr(value);
                resolveLocal(expr, name);
            }
            case Binary(left, _, right): {
                visitExpr(left);
                visitExpr(right);
            }
            case Call(callee, _, arguments): {
                visitExpr(callee);
                for (argument in arguments) {
                    visitExpr(argument);
                }
            }
            case Grouping(expression): visitExpr(expression);
            case Literal(_): return;
            case Logical(left, _, right): {
                visitExpr(left);
                visitExpr(right);
            }
            case Unary(_, right): visitExpr(right);
            case Get(object, _): {
                visitExpr(object);
            }
            case Set(object, _, value): {
                visitExpr(value);
                visitExpr(object);
            }
            case This(keyword): {
                if (currentClass == ClassType.NONE) {
                    Lox.errorToken(keyword, "Cannot use 'this' outside of a class.");
                    return;
                }

                resolveLocal(expr, keyword);
            }
            case Super(keyword, _): {
                if (currentClass == ClassType.NONE) {
                    Lox.errorToken(keyword, "Cannot use 'super' outside of a class.");
                } else if (currentClass != ClassType.SUBCLASS) {
                    Lox.errorToken(keyword, "Cannot use 'super' in a class with no superclass.");
                }

                resolveLocal(expr, keyword);
            }
        }
    }

    @:allow(Lox.run) function resolve(statements: haxe.ds.ReadOnlyArray<Stmt>): Void {
        for (statement in statements) {
            visitStmt(statement);
        }
    }

    function resolveFunction(params: haxe.ds.ReadOnlyArray<Token>, body: haxe.ds.ReadOnlyArray<Stmt>, type: FunctionType): Void {
        final enclosingFunction = currentFunction;
        currentFunction = type;
        
        beginScope();
        for (param in params) {
            declare(param);
            define(param);
        }
        resolve(body);
        endScope();
        currentFunction = enclosingFunction;
    }

    function beginScope(): Void {
        scopes.push([]);
    }

    function endScope(): Void {
        scopes.pop();
    }

    function declare(name: Token): Void {
        if (scopes.length == 0) return;

        final scope = scopes[scopes.length - 1];
        if (scope.exists(name.lexeme)) {
            Lox.errorToken(name, "Variable with this name already declared in this scope.");
        }

        scope.set(name.lexeme, false);
    }

    function define(name: Token): Void {
        if (scopes.length == 0) return;

        final scope = scopes[scopes.length - 1];
        scope.set(name.lexeme, true);
    }

    function resolveLocal(expr: Expr, name: Token): Void {
        var i = scopes.length;
        while (i-- > 0) {
            if (scopes[i].exists(name.lexeme)) {
                interpreter.resolve(expr, scopes.length - 1 - i);
                return;
            }
        }
    }
}