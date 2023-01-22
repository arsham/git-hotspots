package main

type x struct{}

func (x) FuncOne() {}
func (*x) FuncTwo() {
	nested := func() {}
	_ = nested
}
func (f *x) FuncThree() {}
