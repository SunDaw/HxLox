using TokeType.TokenType;

class Scanner {
    final source: String;
    final tokens: Array<Token> = [];
    var start = 0;
    var current = 0;
    var line = 1;
    static final keywords = [
        "and" => AND,
        "class" =>  CLASS,
        "else" => ELSE,
        "false" => FALSE,
        "for" => FOR,
        "fun" => FUN,
        "if" => IF,
        "nil" => NIL,
        "or" => OR,
        "print" => PRINT,
        "return" => RETURN,
        "super" => SUPER,
        "this" => THIS,
        "true" => TRUE,
        "var" => VAR,
        "while" => WHILE,
    ];

    public function new(source) {
        this.source = source;
    }

    public function scanTokens(): Array<Token> {
        while (!isAtEnd()) {
            // We are at the beginning of the next lexeme.
            start = current;
            scanToken();
        }

        tokens.push(new Token(EOF, "", null, line));
        return tokens;
    }

    function scanToken(): Void {
        final c = advance();
        switch (c) {
            case '('.code: addToken(LEFT_PAREN);
            case ')'.code: addToken(RIGHT_PAREN);
            case '{'.code: addToken(LEFT_BRACE);
            case '}'.code: addToken(RIGHT_BRACE);
            case ','.code: addToken(COMMA);
            case '.'.code: addToken(DOT);
            case '-'.code: addToken(MINUS);
            case '+'.code: addToken(PLUS);
            case ';'.code: addToken(SEMICOLON);
            case '*'.code: addToken(STAR);
            case '!'.code: addToken(match('='.code) ? BANG_EQUAL : BANG);
            case '='.code: addToken(match('='.code) ? EQUAL_EQUAL : EQUAL);
            case '<'.code: addToken(match('='.code) ? LESS_EQUAL : LESS);
            case '>'.code: addToken(match('='.code) ? GREATER_EQUAL : GREATER);
            case '/'.code: 
                if (match('/'.code)) {
                   // A comment goes until the end of the line.
                    while (peek() != '\n'.code && !isAtEnd()) advance();
                } else {
                    addToken(SLASH);
                }
            
            case ' '.code | '\r'.code | '\t'.code: // Ignore whitespace.
            case '\n'.code: ++line;

            case '"'.code: string();

            default: 
                if (isDigit(c)) {
                    number();
                } else if (isAlpha(c)) {
                    identifier();
                } else {
                    Lox.errorLine(line, "Unexpected character");
                } 
        }
    }

    function identifier(): Void {
        while (isAlphaNumeric(peek())) advance();

        // See if the identifier is a reserved word.
        final text = source.substring(start, current);

        var type = keywords.get(text);
        if (type == null) type = IDENTIFIER;
        addToken(type);
    }

    function number(): Void {
        while (isDigit(peek())) advance();

        // Look for a fractional part.
        if (peek() == '.'.code && isDigit(peekNext())) {
            // Consume the "."
            advance();

            while (isDigit(peek())) advance();
        }

        addToken(NUMBER, Std.parseFloat(source.substring(start, current)));
    }

    function string(): Void {
        while (peek() != '"'.code && !isAtEnd()) {
            if (peek() == '\n'.code) ++line;
            advance();
        }

        // Unterminated string.
        if (isAtEnd()) {
            Lox.errorLine(line, "Unterminated string.");
            return;
        }

        // The closing ".
        advance();

        // Trim the surrounding quotes.
        final value = source.substring(start + 1, current - 1);
        addToken(STRING, value);
    }

    function match(expected: Int): Bool {
        if (isAtEnd()) return false;
        if (StringTools.fastCodeAt(source, current) != expected) return false;

        ++current;
        return true;
    }

    inline function peek(): Int {
        if (isAtEnd()) return 0;
        return StringTools.fastCodeAt(source, current);
    }

    inline function peekNext(): Int {
        if (current + 1 >= source.length) return 0;
        return StringTools.fastCodeAt(source, current + 1);
    }

    inline function isAlpha(c: Int): Bool {
        return (c >= 'a'.code && c <= 'z'.code) ||
           (c >= 'A'.code && c <= 'Z'.code) ||
            c == '_'.code;
    }

    inline function isAlphaNumeric(c: Int): Bool {
        return isAlpha(c) || isDigit(c);
    }

    inline function isDigit(c: Int): Bool {
        return c >= '0'.code && c <= '9'.code;
    }

    inline function isAtEnd(): Bool {
        return current >= source.length;
    }

    inline function advance(): Int {
        ++current;
        return StringTools.fastCodeAt(source, current - 1);
    }

    inline function addToken(type: TokenType, ?literal: Any): Void {
        final text = source.substring(start, current);
        tokens.push(new Token(type, text, literal, line));
    }
}