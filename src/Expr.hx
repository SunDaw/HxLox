enum Expr {
    Assign(name: Token, value: Expr);
    Binary(left: Expr, op: Token, right: Expr);
    Call(callee: Expr, paren: Token, arguments: haxe.ds.ReadOnlyArray<Expr>);
    Get(object: Expr, name: Token);
    Grouping(expression: Expr);
    Literal(value: Any);
    Logical(left: Expr, op: Token, right: Expr);
    Set(object: Expr, name: Token, value: Expr);
    Super(keyword: Token, method: Token);
    This(keyword: Token);
    Unary(op: Token, right: Expr);
    Variable(name: Token);
}