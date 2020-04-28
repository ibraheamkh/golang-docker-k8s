package main

import (
	"net/http"
)

func main() {
	//handler func, in golang functions are first class citizens, cool
	//also dynamic kind of dynamic typing but the langauge is actually statically typed
	helloHandler := func(w http.ResponseWriter, r *http.Request) {

		w.Write([]byte("Hello Golang"))
	}
	//map endpoint with handler
	http.HandleFunc("/", helloHandler)
	//run server on given port
	http.ListenAndServe(":8080", nil)
}
