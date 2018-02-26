# Hyperscript

Hyperscript is a package for working with HTML, SVG, and CSS in Julia.

When using this library you automatically get:

* A concise DSL for writing HTML, SVG, and CSS.
* Flexible ways to combine DOM pieces together into larger components.
* Safe and automatic HTML-escaping.
* Lightweight and optional support for scoped CSS.
* Lightweight and optional support for CSS unit arithmetic.

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
# turns into <meta http-equiv="refresh" />
```

For attributes that are _meant_ to be camelCase, Hyperscript still does the right thing:

```
m("svg", viewBox="0 0 100 100")
# turns into <svg viewBox="0 0 100 100"><svg>
```

Hyperscript automatically HTML-escapes children of DOM nodes:

```
m("p", "I am a paragraph with a < inside it")
# turns into <p>I am a paragraph with a &#60; inside it</p>
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
# turns into .entry { font-size: 14px; }
```

CSS nodes can be nested inside each other:

```
css(".entry",
    fontSize="14px",
    css("h1", textDecoration="underline")
    css("> p", color="#999"))
# turns into
# .entry { font-size: 14px; }
# .entry h1 { text-decoration: underline; }
# .entry > p { color: #999; }
```

`@media` queries are also supported:

```
css("@media (min-width: 1024px)",
    css("p", color="red"))
# turns into
# @media (min-width: 1024px) {
# p { color: red; }
# }
```

## Scoped Styles

Hyperscript supports scoped styles implemented by adding unique attributes to nodes and selecting them via [attribute selectors](https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors):

```
@tags p
@tags_noescape style

# Create a scoped `Style` object
s = Style(css("p", fontWeight="bold"))

s(p("hello")) # Apply the style to a DOM node
# turns into <p v-style1>hello</p>

# Insert the corresponding style into a <style> tag
style(styles(s))
# turns into <style>p[v-style1] {font-weight: bold;}</style>
```

Scoped styles are scoped to the subtree of the DOM to which they are applied. Scoped styles on a parent node do not leak into styled child nodes, which function as cascade barriers:

```
# Create a second scoped style
s2 = Style(css("p", color="blue"))

# Apply `s` to the parent and `s2` to a child.
# Note the `s` style did not apply to the child styled with `s2`.
s(p(s2(p("hello"))))
# turns into <p v-style1><p v-style2>hello</p></p>

style(styles(s), styles(s2))
# turns into
# <style>
# p[v-style1] {font-weight: bold;}
# p[v-style2] {color: blue;}
# </style>
```

## CSS Units

Specifying CSS attributes as strings can get verbose, so Hyperscript supports a shorter syntax for arithmetic with CSS units:

```
using Hyperscript
import Hyperscript: px, em

css(".foo", width=50px)
# turns into .foo {width: 50px;}

css(".foo", width=50px + 2 * 100px)
# turns into .foo {width: 250px;}

css(".foo", width=(50px + 50px) + 2em)
# turns into .foo {width: calc(100px + 2em);}
```

---

I'd like to create a more comprehensive guide to the full functionality available in Hyperscript at some point. For now here's a list of some of the finer points:

* Nodes are immutable — any derivation of new nodes from existing nodes will not leave existing nodes unchanged.
* Calling an existing node with with more children creates a new node with the new children appended.
* Calling an existing node with more attributes creates a new node whose attributes are the `merge` of the existing and new attributes.
* `div.fooBar` adds the CSS class `foo-bar`. To add the camelCase class `fooBar` you can use the dot syntax with a string: `div."fooBar"`
* The dot syntax always _adds_ to the CSS class. This is why chaining (`div.foo.bar.baz`) adds all three classes in sequence. 
* Tags defined with `@tags_noescape` only "noescape" one level deep. Children of children will still be escaped according to their own rules.
* Using `nothing` as the value of a DOM attribute creates a valueless attribute, e.g. `<input checked />`.
