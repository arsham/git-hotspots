package main

func FuncTwo() {}

func FuncThree() {
	nested := func() {}
	_ = nested
}
