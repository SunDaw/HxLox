import Interpreter.RuntimeError;
import TokeType.TokenType;
import haxe.io.Eof;
import sys.io.File;

class Lox {
    static final interpreter = new Interpreter();
    static var hadError = false;
    static var hadRuntimeError = false;

    public static function main(): Void {
        final args = Sys.args();
        if (args.length > 1) {
            Sys.println("Usage: hlox [script]");
            Sys.exit(64);
        } else if (args.length == 1) {
            runFile(args[0]);
        } else {
            runPrompt();
        }
    }

    static function runFile(path: String): Void {
        final bytes = File.read(path).readAll();
        run(bytes.toString());
        if (hadError) {
            Sys.exit(65);
        }
        if (hadRuntimeError) {
            Sys.exit(70);
        }
    }

    static function runPrompt(): Void {
        final reader = Sys.stdin();
        while (true) {
            try {
                Sys.print("> ");
                final line = reader.readLine();
                run(line);
                hadError = false;
            } catch (error: Eof) {
                Sys.println("\nexiting Lox");
                return;
            }
        }
    }

    static function run(source: String): Void {
        final scanner = new Scanner(source);
        final tokens = scanner.scanTokens();
        final parser = new Parser(tokens);
        final statements = parser.parse();

        // Stop if there was a syntax error.
        if (hadError) return;

        final resolver = new Resolver(interpreter);
        resolver.resolve(statements);

        // Stop if there was a resolution error.
        if (hadError) return;

        interpreter.interpret(statements);
    }

    @:allow(Scanner) static function errorLine(line: Int, message: String): Void {
        report(line, "", message);
    }
    
    @:allow(Parser, Resolver) static function errorToken(token: Token, message: String): Void {
        if (token.type == TokenType.EOF) {
            report(token.line, " at end", message);
        } else {
            report(token.line, ' at "${token.lexeme}"', message);
        }
    }

    @:allow(Interpreter) static function runtimeError(error: RuntimeError): Void {
        Sys.stderr().writeString('${error.message}\n[line ${error.token.line}]');
        hadRuntimeError = true;
    }

    static function report(line: Int, where: String, message: String): Void {
        Sys.stderr().writeString('[line $line] Error $where: $message\n');
        hadError = true;
    }
}