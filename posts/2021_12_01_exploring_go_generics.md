*This post was created from my time at Big Nerd Ranch, but they've since disbanded.
I've moved the content here so it's still available.*

# Exploring Go v1.18's Generics

Go 1.18 is set to arrive in February 2022, and with it comes the long-awaited addition of generics to the language. It's been a long process to find something that works with the current Go ecosystem, but a proposal has been accepted that tries to protect the objectives of the language while adding the largest changes to the language in over a decade. Will developers add more complexity and make things less maintainable with generics? Or will this enable new heights and capabilities for gophers everywhere?

In this post, we'll go over specifically what type parameters and constraints look like in Go 1.18, but we won't be covering every detail of the proposal itself: we'll be giving an overview enough to use them, and then some real-life examples of where generics are going to solve headaches for gophers. As such, no article will ever be a replacement for going over the proposal itself. It's quite long, but each piece is well explained and still approachable.

## Getting set up

To start playing with generics (or really just the next Go version), there are two simple ways:

### Go Playground

You can use the Go 2 playground in your browser to execute Go 1.18 samples. A word of caution—this uses a tool that was made to help those trying out the new syntax for proposals, and is no longer maintained. So if something doesn't work here, it's likely due to this tool not keeping up with changes since the specifications were finalized.

### gotip

This tool is used to compile and run the Go development branch on your local machine without replacing your normal `go` terminal tools.

- `go install golang.org/dl/gotip@latest`
- `gotip download`
- Set your version to `1.18` in your `go.mod` file for your repo directory.

Once that's all done, the `gotip` command can be used anywhere you've been using the stable `go` command, e.g. `gotip test ./...`.

## Type parameters

The big change enabling generic structures and data types is the introduction of a _type-parameter_ for type aliases, structs, methods, and standalone functions. Here's some sample syntax for a generic-looking `Node` type:

```go
type Node[T any] struct {
    Value T
    Left  *Node[T]
    Right *Node[T]
}
```

This looks a lot like the existing Go code (which is great), just the addition of `T any` inside of square brackets. We can read that as a normal parameter to a function, like `id string`, except this refers to a type that will determine what type the `Value` field will hold. This could be any type you want, as specified by the `any` _type constraint_ that we'll touch on later.

You can instantiate a generic type like this:

```go
node := Node[int]{}
```

In this snippet, we've added square brackets behind the type name to specify that `int` is the type-parameter, which creates an instance of the `Node` struct, except it's typed such that its `Value` field is an `int`. You can omit to specify the type-parameter and allow the compiler to infer the type being used:

```go
node := Node{
    Value: 17,
}
```

Similar to the example above, this results in a `Node` type that holds an `int`. Type parameters can also be used on methods belonging to a generic struct, like so:

```go
func (n Node[T]) Val() T {
    return n.Value
}
```

But they're really pointing to the types on the receiver (Node) type; methods cannot have type parameters, they can only reference parameters already declared on the base type. If a method doesn't need type parameters or all _x_ number of them, it can omit them entirely or leave out a few.

Type alias declarations can also accept parameters:

```go
type Slice[T any] []T
```

Without generics, library authors would write this to accommodate any type:

```go
type Node struct {
    Value interface{}
    Left  *Node
    Right *Node
}
```

Using this `Node` definition, library consumers would have to cast each time each time the `Value` field was accessed:

```go
v, ok := node.Value.(*myType)
if !ok {
    // Do error handling...
}
```

Additionally, `interface{}` can be dangerous by allowing _any_ type, even different types for separate instances of the `struct` like so:

```go
node := Node{
    Value: 62,
    Left: &Node{
        Value: "64",
    },
    Right: &Node{
        Value: []byte{},
    },
}
```

This results in a very unwieldy tree of heterogeneous types, yet it still compiles. Not only can casting types be tiresome, each time that a typecast happens you open yourself to an error happening at runtime, possibly in front of a user or critical workload. But when the compiler handles type safety and removes the need for casting, a number of bugs and mishaps are avoided by giving us errors that prevent the program from building. This is a great argument in favor of strong-type systems: errors at compilation are easier to fix than debugging bugs at runtime when they're already in production.

Generics solve a longstanding complaint where library authors have to resort to using `interface{}`, or manually creating variants of the same structure, or even use code generation just to define functions that could accept different types. With the addition of generics, it removes a lot of headache and effort from common developer use cases.

## Type constraints

Back to the `any` keyword that was mentioned earlier. This is the other half of the generics implementation, called a _type constraint,_ and it tells the compiler to narrow down what types can be used in the type parameter. This is useful for when your generic struct can take most things, but needs a few details about the type it's referring to, like so:

```go
func length[T any](t T) int {
    return len(t)
}
```

This won't compile, since `any` could allow an `int` or any sort of struct or interface, so calling `len` on those would fail. We can define a constraint to help with this:

```go
type LengthConstraint interface {
    string | []byte
}

func length[T LengthConstraint](t T) int {
    return len(t)
}
```

This type of constraint defines a _typeset_: a collection of types (separated by a pipe delimiter) that we're allowing as good answers to the question of what can be passed to our generic function. Because we've only allowed two types, the compiler can verify that `len` works on both of those types; the compiler will check that we can call `len` on a string (yes) and a byte array (also yes). What if someone hands us a type alias with `string` as the underlying type? That won't work since the type alias is a new type altogether and not in our set. But worry not, we can use a new piece of syntax:

```go
type LengthConstraint interface {
    ~string | ~[]byte
}
```

The tilde character specifies an approximation constraint `~T` that can be fulfilled by types that use `T` as an underlying type. This makes values of `type info []byte` satisfactory arguments to our `length` function:

```go
type info []byte

func main() {
    var i info
    a := length(i)
    fmt.Printf("%#v", a)
}
```

Type constraints can also enforce that methods are present, just like regular interfaces:

```go
type LengthConstraint interface {
    ~string | ~[]byte
    String() string
}
```

This reads as before, making sure that the type is either based on a string or byte array, but now ensures implementing types also have a method called `String` that returns a `string`. A quick note: the compiler won't stop you from defining a constraint that's impossible to implement, so be careful:

```go
type Unsatifiable interface {
    int
    String() string
}
```

Finally, Go 1.18 will also add a package called `constraints` that will define some utility type sets, like `constraints.Ordered`, which will contain all types that the less than or greater than operators can use. So don't feel like you need to redefine your own constraints all the time, odds are you'll have one defined by the standard library already.

### No type erasure

Go's proposal for generics also mentions that there will not be any type of erasure when using them. That is, all compile-time information about the types used in a generic function will still be available at runtime; no specifics about type-parameters will be lost when using `reflect` on instances of generic functions and structs. Consider this example of type erasure in Java:

```java
// Example generic class
public class ArrayList<E extends Number> {
    // ...
};

ArrayList<Integer> li = new ArrayList<Integer>();
ArrayList<Float> lf = new ArrayList<Float>();
if (li.getClass() == lf.getClass()) { // evaluates to true
    System.out.println("Equal");
}
```

Despite the classes having differing types contained within, that information goes away at runtime, which can be useful to prevent code from relying on information being abstracted away.

Compare that to a similar example in Go 1.18:

```go
type Numeric interface {
    int | int64 | uint | float32 | float64
}

type ArrayList[T Numeric] struct {}

var li ArrayList[int64]
var lf ArrayList[float64]
if reflect.TypeOf(li) == reflect.TypeOf(lf) { // Not equal
    fmt.Printf("they're equal")
    return
}
```

All of the type information is retained when using `reflect.TypeOf`, which can be important for those wanting to know about what sort of type was passed in and want to act accordingly. However, it should be noted that no information will be provided about the constraint or approximation constraint that the type matched. For example, say we had a parameter of `type MyType string` that matched a constraint of `~string`, reflect will only tell us about `MyType` and not the constraint that it fulfilled.

## Real-life example

There will be many examples of generics being used in traditional computer science data models, especially as the Go community adopts generics and updates their libraries after their release. But to finish out this tour of generics, we'll look at a real-life example of something that gophers work with almost every single day: HTTP handlers. Gophers will always remember the function signature of a vanilla HTTP handler:

```go
func(w http.ResponseWriter, r *http.Request)
```

Which honestly doesn't say much about what the function can take in or return. It can write anything back out of it and we'd have to manually call the function to get the response for unmarshaling and testing.

What follows is a function for constructing HTTP handlers out of functions that take in and return useful types rather than writers and requests that say nothing about the problem domain.

```go
package main

import (
    "encoding/json"
    "fmt"
    "net/http"
)

func AutoDecoded[T any, O any](f func(body T, r *http.Request) (O, error)) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Decode the body into t
        var t T
        if err := json.NewDecoder(r.Body).Decode(&t); err != nil {
            http.Error(w, fmt.Sprintf("error decoding body: %s", err), http.StatusBadRequest)
            return
        }

        // Call the inner function
        result, err := f(t, r)
        if err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }

        marshaled, err := json.Marshal(result)
        if err != nil {
            http.Error(w, fmt.Sprintf("error marshaled response: %s", err), http.StatusInternalServerError)
            return
        }

        if _, err := w.Write(marshaled); err != nil {
            http.Error(w, fmt.Sprintf("error writing response: %s", err), http.StatusInternalServerError)
            return
        }
    }
}

type Hello struct {
    Name string `json:"name"`
}

type HelloResponse struct {
    Greeting string `json:"greeting"`
}

func handleApi(body Hello, r *http.Request) (HelloResponse, error) {
    return HelloResponse{
        Greeting: fmt.Sprintf("Hello, %s", body.Name),
    }, nil
}

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/api", AutoDecoded(handleApi))

    http.ListenAndServe(":3000", mux)
}
```

`AutoDecoded` is a generic function with two type parameters: `T` and `O`. These types represent the incoming body type we should expect from the request, and the output type we expect to hand back to the requester, respectively. Looking at the rest of `AutoDecoded`'s function signature, we see that it wants a function that maps an instance of `T` and an `*http.Request` to an instance of `Result[O]`. Stepping through `AutoDecoded`'s logic, it starts by decoding the incoming JSON request into an instance of `T`. With the body stored in a variable, the function is ready to call the inner function that was provided as the argument using variable `t`. `AutoDecoded` then handles if the inner function errored, and if it didn't, then takes the output and writes it back to the client as JSON.

Below `AutoDecoded` is our HTTP handler called `handleApi`, and we can see that it doesn't follow the normal patter for an `http.HandlerFunc`; this function accepts and returns types `Hello` and `HelloResponse` defined above it. Compared to a function using an `http.ResponseWriter`, this `handleApi` function is a lot easier to test since it returns a specific type or error, rather than writing bytes back out. Plus, the types on this function now serve as a bit of documentation: other developers reading this can look at `handleApi`'s type signature and know what it is expecting and what it will return. Finally, the compiler can tell us if we're trying to return the wrong type from our handler. Before you could write anything back to the client and the compiler wouldn't care:

```go
func(w http.ResponseWriter, r *http.Request) {
    // Decoding logic...

    // Our client was expecting a `HelloResponse`!
    w.Write([]byte("something else entirely"))
}
```

In the `main` function, we see a bit of type-parameter inference happen when we no longer need to specify the type parameters when linking the pieces together in `AutoDecoded(handleApi)`. Since `AutoDecoded` returns an `http.Handler`, we can take the result of the function call and plug it into any Go router, like the `http.ServeMux` used here. And with that, we've introduced more concrete types into our program.

As you can hopefully now see, it's going to be nice to have compiler functionality in Go to help us write more generic types and functions while avoiding the warts of the language where we might resort to using `interface{}`. The introduction of type parameters will be a gradual process overall, as Russ Cox has made the suggestion to not touch the existing standard library types or structures in the next Go release. Even if you don't want to use generics, this next release will be compatible with your existing code, so adopt what features make sense for your project and team. Congrats to the Go team on another release, and congrats to the gophers who have patiently awaited these features for so long. Have fun being generic!
