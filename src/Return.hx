import haxe.Exception;

class Return extends Exception {
    public final value: Any;

    public function new(value: Any) {
        super(null, null);
        this.value = value;
    }
}