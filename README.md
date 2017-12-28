# Hyperscript: A lightweight DOM and HTML markup DSL

Hyperscript is a Julia package for representing HTML and SVG expressions using native Julia syntax.

```
Pkg.clone("https://github.com/yurivish/Hyperscript.jl")
using Hyperscript
```

Hyperscript introduces the `m` function for creating markup nodes:

```
m("div", class="entry",
    m("h1", "An Important Announcement"))
```

Nodes are validated as they are created. Hyperscript checks for valid tag names, and tag-attribute pairs:

```
m("snoopy") # ERROR: snoopy is not a valid HTML or SVG tag
m("div", mood="facetious") # ERROR: mood is not a valid attribute name
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

Arrays, tuples, and generators are recursively flattened, automatically linearizing nested structures for display:

```
@tags div h1
const entry = div.entry
div(entry.(["$n Fast $n Furious" for n in 1:10])) # this joke is © Glen Chiacchieri
```

Some attribute names, such as those with hyphens, can't be written as Julia identifiers. For those you can use either camelCase or squishcase and Hyperscript will convert them for you:

```
# These are both valid:
m("meta", httpEquiv="refresh")
m("meta", httpequiv="refresh")
```

If you'd like to turn off validation you should use `m_novalidate`, which is just like `m` except that it doesn't validate or perform attribute conversion:

```
import Hyperscript # Note import, not using
const m = Hyperscript.m_novalidate

m("snoopy") # <snoopy></snoopy>
m("div", mood="facetious") # <div mood="facetious"></div>
```


To validate more stringently against _just_ HTML or _just_ SVG, you can similarly use `Hyperscript.m_html` or `Hyperscript.m_svg`.
