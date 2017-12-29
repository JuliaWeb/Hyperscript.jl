__precompile__()

module Hyperscript

export m, @tags

include("constants.jl")

# To reduce redundancy, we create some constant values here
const COMBINED_ATTRS = merge(unique∘vcat, SVG_ATTRS, HTML_ATTRS)
const COMBINED_TAGS = union(SVG_TAGS, HTML_TAGS)
const COMBINED_ATTR_NAMES = merge(HTML_ATTR_NAMES, SVG_ATTR_NAMES)

# NOTE: This is still the self-closing-tag list when validation is turned off.
# How should this work instead?
isvoid(tag) = tag in COMBINED_VOID_TAGS

## Validation types and implementation

"""
Validations provide checks against common typos and mistakes. They are non-exhaustive
and enforce valid HTML/SVG tag names as well as enforcing that the passed attributes
are allowed on the given tag, e.g. you can use `cx` but not `x` on a `<circle />`.

Validations other than `NoValidate` also enforce that numeric attribute values are non-`NaN`.

The specific tag and attribute names depend on the chosen validation. The default is
*combined* validation via `ValidateCombined`, which liberally accepts any mix of valid
HTML/SVG tags and attributes.

Note that `ValidateCombined` does not enforce inter-attribute consistency. If you use a tag
that belongs to both SVG and HTML, it will accept any mix of HTML and SVG attributes for
that tag even when the valid attributes for that HTML tag and SVG tag differ.

These are all of the tags shared between HTML and SVG:

$HTML_SVG_TAG_INTERSECTION_MD
"""
#=
abstract type Validation end

"Validates generously against the combination of HTML and SVG."
struct ValidateCombined <: Validation end

"Validates generously against the combination of SVG 1.1, SVG Tiny 1.2, and SVG 2."
struct ValidateSVG <: Validation end

"Validates generously against the combination of HTML 4, W3C HTML 5, and WHATWG HTML 5."
struct ValidateHTML <: Validation end

"Does not validate input tag names, attribute names, or attribute values."
struct NoValidate <: Validation end

sym_to_name(::ValidateCombined) = COMBINED_ATTR_NAMES
sym_to_name(::ValidateHTML) = HTML_ATTR_NAME
sym_to_name(::ValidateSVG) = SVG_ATTR_NAME

tag_to_attrs(::ValidateCombined) = COMBINED_ATTRS
tag_to_attrs(::ValidateHTML) = HTML_ATTRS
tag_to_attrs(::ValidateSVG) = SVG_ATTRS

tags(::ValidateCombined) = COMBINED_TAGS
tags(::ValidateHTML) = HTML_TAGS
tags(::ValidateSVG) = SVG_TAGS

name(::ValidateCombined) = "HTML or SVG"
name(::ValidateHTML) = "HTML"
name(::ValidateSVG) = "SVG"

function validatetag(v::Validation, tag)
    tag ∈ tags(v) || error("$tag is not a valid $(v.name) tag")
    tag
end
validatetag(v::NoValidate, tag) = tag

function validatevalue(v::Validation, tag, attr, value::Number)
    # Technically a NaN is valid attribute value, but we consider it
    # an error since it's almost never what you actually want.
    # TODO: Find some way to disable this check; somebody somewhere will
    # probably want NaNs to pass through.
    isnan(value) && error("A NaN value was passed to an attribute: $(stringify(tag, attr, value))")
    value
end
validatevalue(v, tag, attr, value) = value
validatevalue(v::NoValidate, tag, attr, value) = value

function validateattrs(v::Validation, tag, nt::NamedTuple)
    sym_to_name = sym_to_v.name
    ATTRS = tag_to_attrs(v)
    attrs = Dict{String, Any}()
    for (sym, value) in pairs(nt)
        attr = get(sym_to_name, sym) do
            error("$(string(sym)) is not a valid attribute name: $(stringify(tag, sym, value))")
        end
        validatevalue(v, tag, attr, value)
        valid = attr ∈ ATTRS[tag] || attr ∈ ATTRS["*"]
        valid || error("$attr is not a valid attribute name for $tag tags")
        attrs[attr] = value
    end
    attrs
end

function validateattrs(v::NoValidate, tag, nt::NamedTuple)
    Dict{String, Any}(string(sym) => value for (sym, value) in pairs(nt))
end

##################
=#

## Validation

abstract type Validation end

struct Validate{nans} <: Validation
    name
    tags
    tag_to_attrs
    sym_to_name
end

"Does not validate input tag names, attribute names, or attribute values."
struct NoValidate <: Validation
end

"Validates generously against the combination of HTML and SVG."
const VALIDATE_COMBINED = Validate{true}("HTML or SVG", COMBINED_TAGS, COMBINED_ATTRS, COMBINED_ATTR_NAMES)

"Validates generously against the combination of SVG 1.1, SVG Tiny 1.2, and SVG 2."
const VALIDATE_SVG = Validate{true}("SVG", SVG_TAGS, SVG_ATTRS, SVG_ATTR_NAMES)

"Validates generously against the combination of HTML 4, W3C HTML 5, and WHATWG HTML 5."
const VALIDATE_HTML = Validate{true}("HTML", HTML_TAGS, HTML_ATTRS, HTML_ATTR_NAMES)

function validatetag(v::Validation, tag)
    tag ∈ v.tags || error("$tag is not a valid $(v.name) tag")
    tag
end
validatetag(v::NoValidate, tag) = tag

function validatevalue(v::Validate{true}, tag, attr, value::Number)
    isnan(value) && error("A NaN value was passed to an attribute: $(stringify(tag, attr, value))")
    value
end
validatevalue(v, tag, attr, value) = value

function validateattrs(v::Validation, tag, nt::NamedTuple)
    attrs = Dict{String, Any}()
    for (sym, value) in pairs(nt)
        attr = get(v.sym_to_name, sym) do
            error("$(string(sym)) is not a valid attribute name: $(stringify(tag, sym, value))")
        end
        validatevalue(v, tag, attr, value)
        valid = attr ∈ v.tag_to_attrs[tag] || attr ∈ v.tag_to_attrs["*"]
        valid || error("$attr is not a valid attribute name for $tag tags")
        attrs[attr] = value
    end
    attrs
end

function validateattrs(v::NoValidate, tag, nt::NamedTuple)
    Dict{String, Any}(string(sym) => value for (sym, value) in pairs(nt))
end

# Nice printing in errors
stringify(tag) = string("<", tag, isvoid(tag) ? " />" : ">")
stringify(tag, attr, value) = string("<", tag, " ", attr, "=\"", value, "\"", isvoid(tag) ? " />" : ">")

## Node representation and generation

struct Node{V<:Validation}
    tag::String
    attrs::Dict{String, Any}
    children::Vector{Any}
    validation::V
end

function Node(v::V, tag, children, attrs) where {V <: Validation}
    Node{V}(validatetag(v, tag), validateattrs(v, tag, attrs), flat(children), v)
end

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
validation(x::Node) = Base.getfield(x, :validation)

# Allow extending a node using function application syntax.
# Overrides attributes and appends children.
function (node::Node{V})(cs...; as...) where {V <: Validation}
    Node{V}(
        tag(node),
        isempty(as) ? attrs(node)    : merge(attrs(node), validateattrs(validation(node), tag(node), as)),
        isempty(cs) ? children(node) : prepend!(flat(cs), children(node)),
        validation(node)
    )
end

# Recursively flatten generators, tuples, and arrays.
# Wraps scalars in a single-element tuple.
# Note: We could do something trait-based, so custom lazy collections can opt into compatibility
function flat(xs::Union{Base.Generator, Tuple, Array})
    out = []
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

# Allow concise class attribute specification.
# Classes specified this way will append to an existing class if present.
function Base.getproperty(x::Node, class::Symbol)
    a = attrs(x)
    x(class=haskey(a, "class") ? string(a["class"], " ", class) : string(class))
end

"""
`m(tag, children...; attrs)`

Create a hypertext node with the specified attributes and children. `m` performs
validation against SVG and HTML tags and attributes; use `m_svg`, `m_html` to
validate against just SVG or HTML, or use `m_novalidate` to prevent validation
entirely.

The following import pattern is useful for convenient access to your choice
of validation style:

```julia
import Hyperscript
const m = Hyperscript.m_svg
```

The `children` can be any Julia values, including other `Node`s creates by `m`.
Tuples, arrays, and generators will be recursively flattened.

Since attribute names are passed as Julia symbols `m(attrname=value)`, Hyperscript
accepts both Julia-style (lowercase) and JSX-like (camelCase) attributes:

`acceptCharset` turns into the HTML attribute `accept-charset`, as does `acceptcharset`.
"""
m(v::Validation, tag, children...; attrs...) = Node(v, tag, children, attrs)
m(tag, children...; attrs...)                = Node(VALIDATE_COMBINED, tag, children, attrs)
m_svg(tag, children...; attrs...)            = Node(VALIDATE_SVG, tag, children, attrs)
m_html(tag, children...; attrs...)           = Node(VALIDATE_HTML, tag, children, attrs)
m_novalidate(tag, children...; attrs...)     = Node(NoValidate(), tag, children, attrs)

"""
Macro for concisely declaring a number of tags in global scope.

`@tags h1 h2 span` expands into

```
const h1 = m("h1")
const h2 = m("h2")
const span = m("span")
```

The `const` declaration precludes this macro from being used in
non-global scopes (e.g. inside a function) since const is disallowed
on local variables. It is present for performance.
"""
macro tags(args::Symbol...)
    blk = Expr(:block)
    for tag in args
        push!(blk.args, quote
            const $(esc(tag)) = m($(string(tag)))
        end)
    end
    push!(blk.args, nothing)
    blk
end

## Markup generation

# Creates an HTML escaping dictionary
chardict(chars) = Dict(c => "&#$(Int(c));" for c in chars)
# See: https://stackoverflow.com/questions/7753448/how-do-i-escape-quotes-in-html-attribute-values
const ATTR_ESCAPES = chardict("&<>\"\n\r\t")
# See: https://stackoverflow.com/a/9189067/1175713
const HTML_ESCAPES = chardict("&<>\"'`!@\$%()=+{}[]")

printescaped(io, x, replacements=HTML_ESCAPES) = for c in x
    print(io, get(replacements, c, c))
end

function render(io::IO, x)
    mime = MIME(mimewritable(MIME("text/html"), x) ? "text/html" : "text/plain")
    printescaped(io, sprint(show, mime, x))
end

render(io::IO, x::Union{AbstractString, Char}) = printescaped(io, x)
render(io::IO, x::Number) = printescaped(io, string(x))
render(node::Node) = sprint(render, node)
function render(io::IO, node::Node)
    print(io, "<", tag(node))
    for (k, v) in pairs(attrs(node))
        print(io, " ", k, "=\"")
        printescaped(io, v, ATTR_ESCAPES)
        print(io, "\"")
    end
    if isvoid(tag(node))
        @assert isempty(children(node))
        print(io, " />")
    else
        print(io, ">")
        for child in children(node)
            render(io, child)
        end
        print(io, "</", tag(node), ">")
    end
end

Base.show(io::IO, ::MIME"text/html",  node::Node) = render(io, node)
Base.show(io::IO, node::Node) = render(io, node)

end # module
