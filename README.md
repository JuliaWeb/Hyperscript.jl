# Hyperscript

Hyperscript is a Julia package for representing HTML, SVG, and CSS expressions using native Julia syntax.

When using this library you automatically get:

* A concise DSL for writing HTML, SVG, and CSS.
* Flexible ways to combine DOM pieces together into larger components.
* Safe and automatic HTML-escaping.
* Validation to catch common mistakes early.
* Lightweight and optional support for scoped CSS.

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
# <meta http-equiv="refresh" />
```

Hyperscript does the right thing for attributes that are _meant_ to be camelCase:

```
m("svg", viewBox="0 0 100 100")
# <svg viewBox="0 0 100 100"><svg>
```

Hyperscript automatically HTML-escapes children of DOM nodes:

```
m("p", "I am a paragraph with a < inside it")
# <p>I am a paragraph with a &#60; inside it</p>
```

You can disable escaping using `@tags_noescape` for writing an inline style or script:

```
@tags_noescape script
script("console.log('<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE')")
```

In addition to HTML and SVG, Hyperscript also supports CSS:

```
css(".entry", fontSize="14px")
# .entry { font-size: 14px; }
```

CSS nodes can be nested inside each other:

```
css(".entry",
    fontSize="14px",
    css("h1", textDecoration="underline")
    css("> p", color="#999")
)
# .entry { font-size: 14px; }
# .entry h1 { text-decoration: underline; }
# .entry > p { color: #999; }
```

