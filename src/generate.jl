using Unicode # for attr2symbols
using Base.Iterators, JSON # for data generation

load(fname) = JSON.parse(read(fname, String); dicttype=Dict{String, Vector{String}})

## Validation data

"""
Map of SVG elements to allowed attributes. Also contains global attributes under '*'.
Includes attributes from SVG 1.1, SVG Tiny 1.2, and SVG 2.
Note: Does not include ARIA attributes (role, aria-*), xml:* or xlink:* attributes, event attributes (on*), or ev:event
[Source](https://github.com/wooorm/svg-element-attributes/blob/2b028fecbf10df35162e63ee50308138068331a6/index.json)
"""
const SVG_ATTRS = load("svg.json")

"""
List of known SVG tag-names. Includes the elements from SVG 1.1, SVG Tiny 1.2, and SVG 2.
[Source](https://github.com/wooorm/svg-tag-names/blob/a30d82c127d9959add5c357e44f5822c15eb8540/index.json)
"""
const SVG_TAGS = Set{String}(load("svgtags.json"))

"""
Map of HTML elements to allowed attributes. Also contains global attributes under '*'. Includes attributes from HTML 4, W3C HTML 5, and WHATWG HTML 5.
Note: Includes deprecated attributes.
Note: Attributes which were not global in HTML 4 but are in HTML 5, are only included in the list of global attributes.
[Source](https://github.com/wooorm/html-element-attributes/blob/2d4db7c929552c35e2720a8d99547da72f8dde52/index.json)
"""
const HTML_ATTRS = load("html.json")

"""
List of known HTML tag-names. Includes ancient (for example, nextid and basefont) and modern (for example, shadow and template) tag-names from both W3C and WHATWG.
[Source](https://github.com/wooorm/html-tag-names/blob/ef96f74a78b4fbe343518a6c156692e12446987a/index.json)
"""
const HTML_TAGS = Set{String}(load("htmltags.json"))

"""
Human-readable list of tags that are both HTML and SVG.
Destined for a docstring.
"""
const HTML_SVG_TAG_INTERSECTION_MD = join(["`$tag`" for tag in intersect(SVG_TAGS, HTML_TAGS)] , ", ", ", and ")

"""
List of attributes defined by [ARIA](https://www.w3.org/TR/aria-in-html/).
[Source](https://github.com/wooorm/aria-attributes/blob/b5dc0dfb1a97ed89eee6b3229527f240db054754/index.json)
"""
const ARIA_EXTRAS = load("aria.json")

# Section M.2: https://www.w3.org/TR/SVG/attindex.html
const SVG_PRESENTATION_ATTRIBUTES = ["alignment-baseline", "baseline-shift", "clip-path", "clip-rule", "clip", "color-interpolation-filters", "color-interpolation", "color-profile", "color-rendering", "color", "cursor", "direction", "display", "dominant-baseline", "enable-background", "fill-opacity", "fill-rule", "fill", "filter", "flood-color", "flood-opacity", "font-family", "font-size-adjust", "font-size", "font-stretch", "font-style", "font-variant", "font-weight", "glyph-orientation-horizontal", "glyph-orientation-vertical", "image-rendering", "kerning", "letter-spacing", "lighting-color", "marker-end", "marker-mid", "marker-start", "mask", "opacity", "overflow", "pointer-events", "shape-rendering", "stop-color", "stop-opacity", "stroke-dasharray", "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "stroke-width", "stroke", "text-anchor", "text-decoration", "text-rendering", "unicode-bidi", "visibility", "word-spacing", "writing-mode"]
const SVG_PRESENTATION_ELEMENTS   = ["a", "altGlyph", "animate", "animateColor", "circle", "clipPath", "defs", "ellipse", "feBlend", "feColorMatrix", "feComponentTransfer", "feComposite", "feConvolveMatrix", "feDiffuseLighting", "feDisplacementMap", "feFlood", "feGaussianBlur", "feImage", "feMerge", "feMorphology", "feOffset", "feSpecularLighting", "feTile", "feTurbulence", "filter", "font", "foreignObject", "g", "glyph", "glyphRef", "image", "line", "linearGradient", "marker", "mask", "missing-glyph", "path", "pattern", "polygon", "polyline", "radialGradient", "rect", "stop", "svg", "switch", "symbol", "text", "textPath", "tref", "tspan", "use"]
for tag in SVG_PRESENTATION_ELEMENTS
    append!(SVG_ATTRS[tag], SVG_PRESENTATION_ATTRIBUTES)
end


# Allow all ARIA attributes on all HTML and SVG elements.
# This is over-generous.
append!(SVG_ATTRS["*"], ARIA_EXTRAS)
append!(HTML_ATTRS["*"], ARIA_EXTRAS)

# Used to validate by default.
# Allows mixing of HTML and SVG attributes on the same element.
const COMBINED_ATTRS = merge(unique∘vcat, SVG_ATTRS, HTML_ATTRS)
const COMBINED_TAGS = union(SVG_TAGS, HTML_TAGS)

function attr2symbols(attr)
    Symbol.(if contains(attr, '-')
        pieces = split(attr, '-')
        (join(pieces), join([first(pieces), map(ucfirst, pieces[2:end])...]))
    else
        if any(isupper, attr)
            (lowercase(attr), attr)
        else
            (attr,)
        end
    end)
end

function sym_to_attr_dict(attrs)
    Dict{Symbol, String}(sym => attr for attr in unique(flatten(values(attrs))) for sym in attr2symbols(attr))
end

# Lookup tables from kwargs symbols to attribute strings.
# e.g. :viewbox => "viewBox", :viewBox => "viewBox"
# e.g. :stopcolor => "stop-color", :stopColor => "stop-color"
const HTML_ATTR_NAMES = sym_to_attr_dict(HTML_ATTRS)
const SVG_ATTR_NAMES = sym_to_attr_dict(SVG_ATTRS)
const COMBINED_ATTR_NAME = merge(HTML_ATTR_NAMES, SVG_ATTR_NAMES)

# Void elements are not allowed to contain content
# See: http://www.w3.org/TR/html5/syntax.html#void-elements
const HTML_VOID_TAGS = Set{String}(["area", "base", "br", "col", "embed", "hr", "img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"])
# See: https://github.com/jonschlinkert/self-closing-tags
const SVG_VOID_TAGS = Set{String}(["circle", "ellipse", "line", "path", "polygon", "polyline", "rect", "stop", "use"])
const COMBINED_VOID_TAGS = union(SVG_VOID_TAGS, HTML_VOID_TAGS)

# Guard against the unlikely chance that a tag is not void in both
# HTML and SVG in a future version of either spec; this would invalidate
# the assumptin made by `isvoid`.
@assert all(tag -> !(tag ∈ SVG_VOID_TAGS && tag ∈ HTML_VOID_TAGS), COMBINED_VOID_TAGS)

macro vardecl(x)
    name = string(x)
    quote
        string("const ", $name, " = ", sprint(showcompact, $x))
    end
end

open("constants.jl", "w") do io
    println(io, "# This code was generated with generate.jl")
    println(io, @vardecl(HTML_TAGS))
    println(io, @vardecl(SVG_TAGS))
    # println(io, @vardecl(COMBINED_TAGS))

    println(io, @vardecl(HTML_ATTRS))
    println(io, @vardecl(SVG_ATTRS))
    # println(io, @vardecl(COMBINED_ATTRS))

    println(io, @vardecl(HTML_ATTR_NAMES))
    println(io, @vardecl(SVG_ATTR_NAMES))
    # println(io, @vardecl(COMBINED_ATTR_NAME))

    println(io, @vardecl(COMBINED_VOID_TAGS))
    println(io, @vardecl(HTML_SVG_TAG_INTERSECTION_MD))
end