haxe native.hxml
clang -O3 -o bin/hxlox -I out out/main.c -lhl -L ../hashlink/