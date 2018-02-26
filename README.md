# Hyperscript

Hyperscript is a package for writing HTML, SVG, and CSS using native Julia syntax.

When using this library you automatically get:

* A concise DSL for writing HTML, SVG, and CSS.
* Flexible ways to combine DOM pieces together into larger components.
* Safe and automatic HTML-escaping.
* Validation for a few common mistakes.
* Lightweight and optional support for scoped CSS.
* A simple and optional system for CSS unit arithmetic.

## Usage

Hyperscript introduces the `m` function for creating markup nodes:

```
m("div", class="entry",
    m("h1", "An Important Announcement"))
```

Nodes can be used as a templates:

```
const div = m("div")
const h1 = m("h1")
div(class="entry", h1("An Important Announcement"))
```

Dot syntax is supported for setting class attributes:

```
const div = m("div")
const h1 = m("h1")
div.entry(h1("An Important Announcement"))
```

Chained dot calls turn into multiple classes:

```
m("div").header.entry
```

The convenience macro `@tags` can be used to quickly declare common tags:

```
@tags div h1
const entry = div.entry
entry(h1("An Important Announcement"))
```

Arrays, tuples, and generators are recursively flattened, linearizing nested structures for display:

```
@tags div h1
const entry = div.entry
div(entry.(["$n Fast $n Furious" for n in 1:10])) # joke © Glen Chiacchieri
```

Attribute names with hyphens can be written using camelCase:

```
m("meta", httpEquiv="refresh")
# turns into: <meta http-equiv="refresh" />
```

For attributes that are _meant_ to be camelCase, Hyperscript still does the right thing:

```
m("svg", viewBox="0 0 100 100")
# turns into: <svg viewBox="0 0 100 100"><svg>
```

Hyperscript automatically HTML-escapes children of DOM nodes:

```
m("p", "I am a paragraph with a < inside it")
# turns into: <p>I am a paragraph with a &#60; inside it</p>
```

You can disable escaping using `@tags_noescape` for writing an inline style or script:

```
@tags_noescape script
script("console.log('<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE')")
```

## CSS

In addition to HTML and SVG, Hyperscript also supports CSS:

```
css(".entry", fontSize="14px")
# turns into: .entry { font-size: 14px; }
```

CSS nodes can be nested inside each other:

```
css(".entry",
    fontSize="14px",
    css("h1", textDecoration="underline")
    css("> p", color="#999"))

# turns into:
# .entry { font-size: 14px; }
# .entry h1 { text-decoration: underline; }
# .entry > p { color: #999; }
```

`@media` queries are also supported:

```
css("@media (min-width: 1024px)",
    css("p", color="red"))

# turns into:
# @media (min-width: 1024px) {
# p { color: red; }
# }
```

## Extras 

There are a few things out of this quick introduction, both optional:

* The scoped style system allows you to define local styles that apply to only part of a page
* You can compute with CSS units using Julia syntax: 

```
import Hyperscript: px, em
println((5px + 5px) + 2em) # "calc(10px + 2em)"
```

I'd like to create a more comprehensive guide to the full functionality available in Hyperscript at some point. For now here's a list of some of the finer points of the library:

* All nodes and node properties are immutable — any nodes derived from existing nodes will be conceptually distinct entities.
* Using `nothing` as the value of a DOM attribute creates a valueless attribute, e.g. `<input checked />`.
* Calling an existing node with with more children creates a new node with the new children appended to the existing children.
* Calling an existing node with more attributes will create a new node whose attributes are the `merge` of the existing and new attributes.
* `div.fooBar` adds the CSS class `foo-bar`. To add the camelCase class `fooBar` you can use the dot syntax with a string: `div."fooBar"`
* The dot syntax always _adds_ to the CSS class. This is why chaining (`div.foo.bar.baz`) adds all three classes in sequence. 
* Tags defined with `@tags_noescape` only "noescape" one level deep. Children of children will still be escaped according to their own rules.
