*This post was created from my time at Big Nerd Ranch, but they've since disbanded.
I've moved the content here so it's still available.*

Go 1.18 has finally landed, and with it comes its own flavor of generics. In a previous post, we went over the accepted proposal and dove into the new syntax. For this post, I've taken the last example in the first post and turned it into a working library that uses generics to design a more type-safe API, giving a good look at how to use this new feature in a production setting. So grab yourself an update to Go 1.18, and settle in for how we can start to use our new generics to accomplish things the language couldn't before.

## A note on when to use generics

Before we discuss how we're using generics in the library, I wanted to make a note: generics are just a tool that has been added to the language. Like many tools in the language, it's not recommended to use all of them all of the time. For example, you should try to handle errors before using `panic` since the latter will end up exiting your program. However, if you're completely unable to recover the program after an error, `panic` might be a perfectly fine option. Similarly, a sentiment has been circulating with the release of Go 1.18 about when to use generics. Ian Lance Taylor, whose name you may recognize from the accepted generics proposal, has a great quote in a talk of his:

> Write Go by writing code, not by designing types.

This idea fits perfectly within the "simple" philosophy of Go: do the smallest, working thing to achieve our goal before evolving the solution to be more complex. For example, if you've ever found yourself writing similar functions to:

```go
func InSlice(s string, ss []string) bool {
    for _, c := range ss {
        if s != c {
            continue
        }

        return true
    }

    return false
}
```

And then you duplicate this function for other types, like `int`, it may be time to start thinking about codifying the more abstract behavior the code is trying to show us:

```go
func InSlice[T constraints.Ordered](t T, ts []T) bool {
    for _, c := range ts {
        if t != c {
            continue
        }

        return true
    }

    return false
}
```

Overall: don't optimize for the problems you haven't solved for yet. Wait to start designing generic types since your project will make abstractions become visible to you the more you work with it. A good rule of thumb here is to keep it simple until you can't.

## Designing Upfront

Although we _just_ discussed how we shouldn't try to design types before coding and learning the abstractions hidden in our project, there's an area where I believe we cannot and should not get away from designing the types first: API-first design. After all, once our server starts to respond to and accepts request bodies from clients, careless changes to either one can result in an application no longer working. However, the way we currently write HTTP handlers in Go has a bit of a lack of types. Let's go through all the ways this can subtly break or introduce issues to our server, starting with a pretty vanilla example:

```go
func ExampleHandler(w http.ResponseWriter, r *http.Request) {
    var reqBody Body
    if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    resp, err := MyDomainFunction(reqBody)
    if err != nil {
        // Write out an error to the client...
    }

    byts, err := json.Marshal(resp)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.Write(byts)
    w.WriteHeader(http.StatusCreated)
}
```

Just to be clear on what this HTTP handler does: it ingests a body and decodes it from JSON, which can return an error. It then passes that decoded struct to `MyDomainFunction`, which gives us either a response or an error. Finally, we marshal the response back to JSON, set our headers, and write the response to the client.

### Picking apart the function: Changing return types

Imagine a small change on the return type of the `MyDomainFunction` function. Say it was returning this struct:

```go
type Response struct {
    Name string
    Age int
}
```

And now it returns this:

```go
type Response struct {
    FirstName string
    LastName string
    Age int
}
```

Assuming that `MyDomainFunction` compiles, so, too, will our example function. It's great that it still compiles, but this may not be a great thing since the response will change and a client may depend on a certain structure, e.g., there's no longer a `Name` field in the new response. Maybe the developer wanted to massage the response so it would look the same despite the change to `MyDomainFunction`. Worse yet is that since this compiles, we won't know this broke something until we deploy and get the bug report.

### Picking apart the function: Forgetting to return

What happens if we forgot to return after we wrote our error from unmarshaling the request body?

```go
var reqBody RequestBody
if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
    http.Error(w, err.Error(), http.StatusBadRequest)
    return
}
```

Because `http.Error` is part of an imperative interface for dealing with responses back to HTTP clients, it does not cause the handler to exit. Instead, the client will get their response, and go about their merry way, while the handler function continues to feed a zero-value `RequestBody` struct to `MyDomainFunction`. This may not be a complete error, depending on what your server does, but this is likely an undesired behavior that our compiler won't catch.

### Picking apart the function: Ordering the headers

Finally, the most silent error is writing a header code at the wrong time or in the wrong order. For instance, I bet many readers didn't notice that the example function will write back a `200` status code instead of the `201` that the last line of the example wanted to return. The `http.ResponseWriter` API has an implicit order that requires that you write the header code before you call `Write`, and while you can read some documentation to know this, it's not something that is immediately called out when we push up or compile our code.

## Being `Upfront` about it

Given all these (albeit minor) issues exist, how can generics help us to move away from silent or delayed failures toward compile-time avoidance of these issues? To answer that, I've written a small library called Upfront. It's just a collection of functions and type signatures to apply generics to these weakly-typed APIs in HTTP handler code. We first have library consumers implement this function:

```go
type BodyHandler[In, Out, E any] func(i BodyRequest[In]) Result[Out, E]
```

As a small review of the syntax, this function takes any three types for its parameters: `In`, for the type that is the output of decoding the body, `Out`, for the type you want to return, and `E` the possible error type you want to return to your client when something goes awry. Next, your function will accept an `upfront.BodyRequest` type, which is currently just a wrapper for the request and the JSON-decoded request body:

```go
// BodyRequest is the decoded request with the associated body
type BodyRequest[T any] struct {
    Request *http.Request
    Body    T
}
```

And finally, the `Result` type looks like this:

```go
// Result holds the necessary fields that will be output for a response
type Result[T, E any] struct {
    StatusCode int // If not set, this will be a 200: http.StatusOK

    value      T
    err        *E
}
```

The above struct does most of the magic when it comes to fixing the subtle, unexpected pieces of vanilla HTTP handlers. Rewriting our function a bit, we can see the end result and work backward:

```go
func ExampleHandler[Body, DomainResp, error](in upfront.BodyRequest[Body]) Result[DomainResp, error] {
    resp, err := MyDomainFunction(in.Body)
    if err != nil {
        return upfront.ErrResult(
            fmt.Errorf("error from MyDomainFunction: %w"),
            http.StatusInternalServerError,
        )
    }

    return upfront.OKResult(
        resp,
        http.StatusCreated,
    )
}
```

We've eliminated a lot of code, but hopefully, we've also eliminated a few of the "issues" from the original example function. You'll first notice that the JSON decoding and encoding are handled by the `upfront` package, so there's a few less places to forget `return`'s. We also use our new `Result` type to exit the function, and it takes in a status code. The `Result` type we're returning has a type parameter for what we want to send back from our handler. This means if `MyDomainFunction` changes its return type, the handler will fail compilation, letting us know we broke our contract with our callers long before we `git push`. Finally, the `Result` type also takes a status code, so it will handle the ordering of setting it at the right time (before writing the response).

And what's with the two constructors, `upfront.ErrResult` and `upfront.OKResult`? These are used to set the package private fields `value` and `err` inside the `Result` struct. Since they're private, we can enforce that any constructors of the type can't set both `value` and `err` at the same time. In other languages, this would be similar (definitely not the same) to an Either type.

## Final thoughts

This is a small example, but with this library, we can get feedback about silent issues at compile time, rather than when we redeploy the server and get bug reports from customers. And while this library is for HTTP handlers, this sort of thinking can apply to many areas of computer science and areas where we've been rather lax with our types in Go. With this blog and library, we've sort of reimplemented the idea of algebraic data types, which I don't see being added to Go in the foreseeable future. But still, it's a good concept to understand: it might open your mind to think about your current code differently.

Having worked with this library in a sample project, there are a few areas for improvement that I hope we see in future patches. The first being that we cannot use type parameters on type aliases. That would save a bunch of writing and allow library consumers to create their own `Result` type with an implicit error type instead of having to repeat it everywhere. Secondly, the type inference is a little lackluster. It's caused the resulting code to be _very_ verbose about the type parameters. On the other hand, Go has never embraced the idea of being terse. If you're interested in the library's source code, you can find it [on GitHub](https://github.com/jdholdren/upfront).

All that being said, generics are ultimately a really neat tool. They let us add some type safety to a really popular API in the standard library without getting too much in the way. But as with any tool, use them sparingly and when they apply. As always: keep things simple until you can't.
