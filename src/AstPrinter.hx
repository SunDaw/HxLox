class AstPrinter {
    public function new() {}

    public function print(expr: Expr): String {
        return visit(expr);
    }

    function visit(expr: Expr): String {
        return switch (expr) {
            case Binary(left, op, right): parenthesize(op.lexeme, [left, right]);
            case Grouping(expression): parenthesize("group", [expression]);
            case Literal(value): if (value == null) "nil" else Std.string(value);
            case Unary(op, right): parenthesize(op.lexeme, [right]);
        }
    }

    function parenthesize(name: String, exprs: Array<Expr>): String {
        final builder = new StringBuf();

        builder.add("(");
        builder.add(name);
        for (expr in exprs) {
            builder.add(" ");
            builder.add(visit(expr));
        }

        builder.add(")");

        return builder.toString();
    }
}