# Hyperscript: A validating HTML and SVG markup DSL


Hyperscript is a Julia package for representing HTML and SVG expressions using native Julia syntax. It supports basic validation against the HTML/SVG specs in order to prevent simple mistakes, such as specifying the attribute `x` instead of `cx` on an SVG `<circle>`.


```
Pkg.add("Hyperscript")
using Hyperscript
```

Hyperscript provides a markup function `m` for concisely specifying DOM trees:

```
m("div", class="entry",
    m("h1", "An Important Announcement"))
```

The `m` function returns a `Node` object which knows how to show itself as a string. For concise expression, `Node`s can be applied as functions to supply additional attributes and children:

```
const entry = m("div", class="entry")
const h1 = m("h1")
div(h1("An Important Announcement"))
```

Hyperscript provides a convenience macro `@tags` that allows the above example to be written as

```
@tags div h1
div(class="hello", h1("An Important Announcement"))
```

Hyperscript allows setting the `class` attribute using dot syntax, mirroring CSS selectors:

```
@tags div h1
const entry = div.entry
entry(h1("An Important Announcement"))
entry(h1("Another one"))
```

To specify attributes that aren't representable as Julia identifiers (such as those with hyphens) you can use camelCase or squishcase — Hyperscript will convert them to their proper forms.

```
m("form", acceptCharset="ISO-8859-1")
m("form", acceptcharset="ISO-8859-1")
```
