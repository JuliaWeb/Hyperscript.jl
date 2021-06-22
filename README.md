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

```julia
m("div", class="entry",
    m("h1", "An Important Announcement"))
```

Nodes can be used as a templates:

```julia
const div = m("div")
const h1 = m("h1")
div(class="entry", h1("An Important Announcement"))
```

Dot syntax is supported for setting class attributes:

```julia
const div = m("div")
const h1 = m("h1")
div.entry(h1("An Important Announcement"))
```

Chained dot calls turn into multiple classes:

```julia
m("div").header.entry
```

The convenience macro `@tags` can be used to quickly declare common tags:

```julia
@tags div h1
const entry = div.entry
entry(h1("An Important Announcement"))
```

Arrays, tuples, and generators are recursively flattened, linearizing nested structures for display:

```julia
@tags div h1
const entry = div.entry
div(entry.(["$n Fast $n Furious" for n in 1:10])) # joke © Glen Chiacchieri
```

Attribute names with hyphens can be written using camelCase:

```julia
m("meta", httpEquiv="refresh")
# turns into <meta http-equiv="refresh" />
```

For attributes that are _meant_ to be camelCase, Hyperscript still does the right thing:

```julia
m("svg", viewBox="0 0 100 100")
# turns into <svg viewBox="0 0 100 100"><svg>
```

Attribute names that happen to be Julia keywords can be specified with `:attr => value` syntax:

```julia
m("input"; :type => "text")
# turns into <input type="text" />
```

Hyperscript automatically HTML-escapes children of DOM nodes:

```julia
m("p", "I am a paragraph with a < inside it")
# turns into <p>I am a paragraph with a &#60; inside it</p>
```

You can disable escaping using `@tags_noescape` for writing an inline style or script:

```julia
@tags_noescape script
script("console.log('<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE')")
```

Nodes can be printed compactly with `print` or `show`, or pretty-printed by wrapping a node in `Pretty`:

```julia
node = m("div", class="entry", m("h1", "An Important Announcement"))

print(node)
# <div class="entry"><h1>An Important Announcement</h1></div>

print(Pretty(node))
# <div class="entry">
#  <h1>An Important Announcement</h1>
# </div>
```

Note that the extra white space can affect layout, particularly in conjunction with CSS properties like [white-space](https://developer.mozilla.org/en-US/docs/Web/CSS/white-space).

Vectors of nodes can be written as an html-file using the `savehtml` function. Here's an example:

```julia
@tags head meta body h1 h2 ul li

doc = [
    head(
      meta(charset="UTF-8"),
      ),
    body(
         [
          h1("My title"),
             "Some text",
             h2("A list"),
             ul(li.(["First point", "Second Point"]))
         ] )
]
# 2-element Vector{Hyperscript.Node{Hyperscript.HTMLSVG}}:
# <head><meta charset="UTF-8" /></head>
# <body><h1>My title</h1>Some text<h2>A list</h2><ul><li>First point</li><li>Second Point</li></ul></body>

savehtml("/tmp/hyper.html", doc) ;

# cat /tmp/hyper.html
# <!doctype html>
# <html><head><meta charset="UTF-8" /></head><body><h1>My title</h1>Some text<h2>A list</h2><ul><li>First point</li><li>Second Point</li></ul></body></html>
```

## CSS

In addition to HTML and SVG, Hyperscript also supports CSS:

```julia
css(".entry", fontSize="14px")
# turns into .entry { font-size: 14px; }
```

CSS nodes can be nested inside each other:

```julia
css(".entry",
    fontSize="14px",
    css("h1", textDecoration="underline"),
    css("> p", color="#999"))
# turns into
# .entry { font-size: 14px; }
# .entry h1 { text-decoration: underline; }
# .entry > p { color: #999; }
```

`@media` queries are also supported:

```julia
css("@media (min-width: 1024px)",
    css("p", color="red"))
# turns into
# @media (min-width: 1024px) {
#   p { color: red; }
# }
```

## Scoped Styles

Hyperscript supports scoped styles. They are implemented by adding unique attributes to nodes and selecting them via [attribute selectors](https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors):

```julia
@tags p
@tags_noescape style

# Create a scoped `Style` object
s1 = Style(css("p", fontWeight="bold"), css("span", color="red"))

# Apply the style to a DOM node
s1(p("hello"))
# turns into <p v-style1>hello</p>

# Insert the corresponding styles into a <style> tag
style(styles(s1))
# turns into
# <style>
#   p[v-style1] {font-weight: bold;}
#   span[v-style1] {color: red;}
# </style>

```

Scoped styles are scoped to the DOM subtree where they are applied. Styled nodes function as cascade barriers — parent styles do not leak into styled child nodes:

```julia
# Create a second scoped style
s2 = Style(css("p", color="blue"))

# Apply `s1` to the parent and `s2` to a child.
# Note the `s1` style does not apply to the child styled with `s2`.
s1(p(p("outer"), s2(p("inner"))))
# turns into
# <p v-style1>
#   <p v-style1>outer</p>
#   <p v-style2>inner</p>
# </p>

style(styles(s1), styles(s2))
# turns into
# <style>
#   p[v-style1] {font-weight: bold;}
#   span[v-style1] {color: red;}
#   p[v-style2] {color: blue;}
# </style>
```

## CSS Units

Hyperscript supports a concise syntax for CSS unit arithmetic:

```julia
using Hyperscript

css(".foo", width=50px)
# turns into .foo {width: 50px;}

css(".foo", width=50px + 2 * 100px)
# turns into .foo {width: 250px;}

css(".foo", width=(50px + 50px) + 2em)
# turns into .foo {width: calc(100px + 2em);}
```

Supported units are `px`, `pt`, `em`,`vh`, `vw`, `vmin`, `vmax`, and `pc` for percent.

---

I'd like to create a more comprehensive guide to the full functionality available in Hyperscript at some point. For now here's a list of some of the finer points:

* Nodes are immutable — any derivation of new nodes from existing nodes will leave existing nodes unchanged.
* Calling an existing node with with more children creates a new node with the new children appended.
* Calling an existing node with more attributes creates a new node whose attributes are the `merge` of the existing and new attributes.
* `div.fooBar` adds the CSS class `foo-bar`. To add the camelCase class `fooBar` you can use the dot syntax with a string: `div."fooBar"`
* The dot syntax always _adds_ to the CSS class. This is why chaining (`div.foo.bar.baz`) adds all three classes in sequence. 
* Tags defined with `@tags_noescape` only "noescape" one level deep. Children of children will still be escaped according to their own rules.
* Using `nothing` as the value of a DOM attribute creates a valueless attribute, e.g. `<input checked />`.
