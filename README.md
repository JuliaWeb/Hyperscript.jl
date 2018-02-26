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
div(entry.(["$n Fast $n Furious" for n in 1:10])) # this joke is © Glen Chiacchieri
```

Attribute names with hyphens can be written with camelCase:

```
m("meta", httpEquiv="refresh")
# <meta http-equiv="refresh" />
```

Hyperscript will do the right thing for attributes that are _supposed_ to be camelCase:

```
m("svg", viewBox="0 0 100 100")
# <svg viewBox="0 0 100 100"><svg>
```

Hyperscript automatically HTML-escape the children of DOM nodes:
```
m("p", "I am a paragraph with a < inside it")
# <p>I am a paragraph with a &#60; inside it</p>
```

You can disable escaping if you're writing an inline `<style>` or `<script>`using `@tags_noescape`:


```
@tags_noescape script
script("console.log('<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE')")
```
