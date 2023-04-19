struct x {}

impl x {
    fn func_one() {}
    fn func_two() {
        let nested = || {};
    }
    fn func_three() {}
}
