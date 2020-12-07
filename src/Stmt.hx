import haxe.ds.ReadOnlyArray;

enum Stmt {
    Block(statements: ReadOnlyArray<Stmt>);
    Class(name: Token, superclass: Expr, methods: ReadOnlyArray<Stmt>);
    Expression(expression: Expr);
    Function(name: Token, params: ReadOnlyArray<Token>, body: ReadOnlyArray<Stmt>);
    If(condition: Expr, thenBranch: Stmt, elseBranch: Stmt);
    Print(expression: Expr);
    Return(keyword: Token, value: Expr);
    Var(name: Token, initializer: Expr);
    While(condition: Expr, body: Stmt);
}