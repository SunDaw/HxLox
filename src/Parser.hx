import haxe.ds.ReadOnlyArray;
using TokeType.TokenType;

class ParseError extends haxe.Exception {}

class Parser {
    final tokens: ReadOnlyArray<Token>;
    var current = 0;

    public function new (tokens) {
        this.tokens = tokens;
    }

    public function parse(): ReadOnlyArray<Stmt> {
        final statements: Array<Stmt> = [];
        while (!isAtEnd()) {
            statements.push(declaration());
        }

        return statements;
    }

    function expression(): Expr {
        return assignment();
    }

    function declaration(): Stmt {
        try {
            if (match([CLASS])) return classDeclaration();
            if (match([FUN])) return func("function");
            if (match([VAR])) return varDeclaration();

            return statement();
        } catch (error: ParseError) {
            synchronize();
            return null;
        }
    }

    function classDeclaration(): Stmt {
        final name = consume(IDENTIFIER, "Expect class name.");

        final superclass = if (match([LESS])) {
            consume(IDENTIFIER, "Expect superclass name.");
            Expr.Variable(previous());
        } else {
            null;
        }

        consume(LEFT_BRACE, "Expect '{' before class body.");

        final methods = [];
        while (!check(RIGHT_BRACE) && !isAtEnd()) {
            methods.push(func("method"));
        }

        consume(RIGHT_BRACE, "Expect '}' after class body.");

        return Stmt.Class(name, superclass, methods);
    }

    function statement(): Stmt {
        if (match([FOR])) return forStatement();
        if (match([IF])) return ifStatement();
        if (match([PRINT])) return printStatement();
        if (match([RETURN])) return returnStatement();
        if (match([WHILE])) return whileStatement();
        if (match([LEFT_BRACE])) return Stmt.Block(block());

        return expressionStatement();
    }

    function forStatement(): Stmt {
        consume(LEFT_PAREN, "Expect '(' after 'for'.");
        
        final initializer = if (match([SEMICOLON])) {
            null;
        } else if (match([VAR])) {
            varDeclaration();
        } else {
            expressionStatement();
        }

        var condition = if (!check(SEMICOLON)) {
            expression();
        } else {
            null;
        }
        consume(SEMICOLON, "Expect ';' after loop condition.");

        final increment = if (!check(RIGHT_PAREN)) {
            expression();
        } else {
            null;
        }
        consume(RIGHT_PAREN, "Expect ')' after for clauses.");

        var body = statement();

        if (increment != null) {
            body = Stmt.Block([body, Stmt.Expression(increment)]);
        }

        if (condition == null) condition = Expr.Literal(true);
        body = Stmt.While(condition, body);

        if (initializer != null) {
            body = Stmt.Block([initializer, body]);
        }

        return body;
    }

    function ifStatement(): Stmt {
        consume(LEFT_PAREN, "Expect '(' after 'if'.");
        final condition = expression();
        consume(RIGHT_PAREN, "Expect '(' after condition.");

        final thenBranch = statement();
        final elseBranch = if (match([ELSE])) {
            statement();
        } else {
            null;
        }

        return Stmt.If(condition, thenBranch, elseBranch);
    }

    function expressionStatement(): Stmt {
        final expr = expression();
        consume(SEMICOLON, "Expect ';' after expression.");
        return Stmt.Expression(expr);
    }

    function func(kind: String): Stmt {
        final name = consume(IDENTIFIER, 'Expect $kind name.');
        consume(LEFT_PAREN, 'Expect \'(\' after $kind name.');
        final parameters = [];
        if (!check(RIGHT_PAREN)) {
            do {
                if (parameters.length >= 255) {
                    error(peek(), "Cannot have more than 255 parameters.");
                }

                parameters.push(consume(IDENTIFIER, "Expect parameter name."));
            } while (match([COMMA]));
        }
        consume(RIGHT_PAREN, "Expect ')' after parameters.");

        consume(LEFT_BRACE, 'Expect\'{\' before $kind body');
        final body = block();
        return Stmt.Function(name, parameters, body);
    }

    function block(): ReadOnlyArray<Stmt> {
        final statements = [];

        while (!check(RIGHT_BRACE) && !isAtEnd()) {
            statements.push(declaration());
        }

        consume(RIGHT_BRACE, "Expect '}' after block.");
        return statements;
    }

    function assignment(): Expr {
        final expr = or();

        if (match([EQUAL])) {
            final equals = previous();
            final value = assignment();

            switch (expr) {
                case Variable(name): return Expr.Assign(name, value);
                case Get(object, name): return Expr.Set(object, name, value);
                default: error(equals, "Invalid assignment expression.");
            }
        }

        return expr;
    }

    function or(): Expr {
        var expr = and();

        while (match([OR])) {
            final op = previous();
            final right = and();
            expr = Expr.Logical(expr, op, right);
        }

        return expr;
    }

    function and(): Expr {
        var expr = equality();

        while (match([AND])) {
            final op = previous();
            final right = equality();
            expr = Expr.Logical(expr, op, right);
        }

        return expr;
    }

    function printStatement(): Stmt {
        final value = expression();
        consume(SEMICOLON, "Expect ';' after value.");
        return Stmt.Print(value);
    }

    function returnStatement(): Stmt {
        final keyword = previous();
        final value = if (!check(SEMICOLON)) {
            expression();
        } else {
            null;
        }

        consume(SEMICOLON, "Expect ';' after return value.");
        return Stmt.Return(keyword, value);
    }

    function varDeclaration(): Stmt {
        final name = consume(IDENTIFIER, "Expect variable name.");

        final initializer: Expr = if (match([EQUAL])) {
            expression();
        } else {
            null;
        }

        consume(SEMICOLON, "Expect ';' after variable declaration.");
        return Stmt.Var(name, initializer);
    }

    function whileStatement(): Stmt {
        consume(LEFT_PAREN, "Expect '(' after 'while'.");
        final condition = expression();
        consume(RIGHT_PAREN, "Expect ')' after condition.");
        final body = statement();

        return Stmt.While(condition, body);
    }

    function binaryOp(tokenTypes: Array<TokenType>, operand: Void->Expr): Expr {
        var expr = operand();

        while (match(tokenTypes)) {
            final op = previous();
            final right = operand();
            expr = Expr.Binary(expr, op, right);
        }

        return expr;
    }

    inline function equality(): Expr return binaryOp([BANG_EQUAL, EQUAL_EQUAL], comparison);
    inline function comparison(): Expr return binaryOp([GREATER, GREATER_EQUAL, LESS, LESS_EQUAL], addition);
    inline function addition(): Expr return binaryOp([MINUS, PLUS], multiplication);
    inline function multiplication(): Expr return binaryOp([SLASH, STAR], unary);

    function unary(): Expr {
        if (match([BANG, MINUS])) {
            final op = previous();
            final right = unary();
            return Expr.Unary(op, right);
        }

        return call();
    }

    function finishCall(callee: Expr): Expr {
        final arguments = [];
        if (!check(RIGHT_PAREN)) {
            do {
                if (arguments.length >= 255) {
                    error(peek(), "Cannot have more than 255 arguments.");
                }
                arguments.push(expression());
            } while (match([COMMA]));
        }

        final paren = consume(RIGHT_PAREN, "Expect ')' after arguments.");

        return Expr.Call(callee, paren, arguments);
    }

    function call(): Expr {
        var expr = primary();

        while (true) {
            if (match([LEFT_PAREN])) {
                expr = finishCall(expr);
            } else if (match([DOT])) {
                final name = consume(IDENTIFIER, "Expect property name after '.'.");
                expr = Expr.Get(expr, name);
            } else {
                break;
            }
        } 

        return expr;
    }

    function primary(): Expr {
        if (match([FALSE])) return Expr.Literal(false);
        if (match([TRUE])) return Expr.Literal(true);
        if (match([NIL])) return Expr.Literal(null);

        if (match([NUMBER, STRING])) {
            return Expr.Literal(previous().literal);
        }

        if (match([SUPER])) {
            final keyword = previous();
            consume(DOT, "Expect '.' after 'super'.");
            final method = consume(IDENTIFIER, "Expect superclass method name.");
            return Expr.Super(keyword, method);
        }

        if (match([THIS])) return Expr.This(previous());

        if (match([IDENTIFIER])) {
            return Expr.Variable(previous());
        }

        if (match([LEFT_PAREN])) {
            final expr = expression();
            consume(RIGHT_PAREN, "Expect ')' after expression.");
            return Expr.Grouping(expr);
        }

        throw error(peek(), "Expect expression.");
    }

    function match(types: ReadOnlyArray<TokenType>): Bool {
        for (type in types) {
            if (check(type)) {
                advance();
                return true;
            }
        }

        return false;
    }

    function consume(type: TokenType, message: String): Token {
        if (check(type)) return advance();

        throw error(peek(), message);
    }

    inline function check(type: TokenType): Bool {
        if (isAtEnd()) return false;
        return peek().type == type;
    }

    inline function advance(): Token {
        if (!isAtEnd()) ++current;
        return previous();
    }

    inline function isAtEnd(): Bool {
        return peek().type == EOF;
    }

    inline function peek(): Token {
        return tokens[current];
    }

    inline function previous(): Token {
        return tokens[current - 1];
    }

    inline function error(token: Token, message: String): ParseError {
        Lox.errorToken(token, message);
        return new ParseError(message);
    }

    function synchronize(): Void {
        advance();

        while (!isAtEnd()) {
            if (previous().type == SEMICOLON) return;

            switch (peek().type) {
                case CLASS | FUN | VAR | FOR | IF | WHILE | PRINT | RETURN: return;
                default: advance();
            }
        }
    }
}