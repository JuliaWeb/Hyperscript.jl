#=
    High-level Overview

    Hyperscript is a package for representing and rendering HTML and SVG DOM trees.

    The primary abstraction is a `Node` — with a tag, attributes, and children.

    Each `Node` also has a `Context` associated with it which defines the way in which
    the basic Hyperscript functions operate on that node.

    The basic pipeline is as follows:

    A `Node` is created with some tag, attributes, and children.

    The tag, attributes, and children are normalized and then validated, using the
    functions [normalize|validate][tag|attr|child] which can dispatch on context to
    handle different node types according to their needs.

    Normalization is the conversion to a canonical form (e.g. kebab- or camel-casing) and
    validation is checking invariants and throwing an error if they are not met (e.g. no
    spaces in attribute names).

    Each of these functions takes a `ctx` argument, allowing the context of a node to fully
    dictate the terms of normalization, validation, escapining, and rendering.

    Nodes handle escaping of their contents upon render using functions named
    escape[tag|attrname|attrvalue|child].

    The full pipeline over the lifecycle of a `Node` involves all of these functions
    in order: normalize => validate => escape upon render.

    ===

    Node extensibility points

    Note that these defaults are not defined — it makes more sense to fully define the relevant
    behaviors independently for each context. The values below are just 'no-op' examples.

    # Return the normalized property value
    normalizetag(ctx, tag) = tag
    normalizeattr(ctx, tag, attr) = attr
    normalizechild(ctx, tag, child) = child

    # Return the property value or throw a validation error
    validatetag(ctx, tag) = tag
    validateattr(ctx, tag, attr) = attr
    validatechild(ctx, tag, child) = child

    # Return a Dict{Char, String} specifying escape replacements
    escapetag(ctx) = NO_ESCAPES
    escapeattrname(ctx) = NO_ESCAPES
    escapeattrvalue(ctx) = NO_ESCAPES
    escapechild(ctx) = NO_ESCAPES
=#

__precompile__()
module Hyperscript

export @tags, @tags_noescape, m, css, Style, styles

include(joinpath(@__DIR__, "cssunits.jl"))

## Basic definitions

abstract type Context end

struct CSS <: Context
    allow_nan_attr_values::Bool
end

struct DOM <: Context
    allow_nan_attr_values::Bool
    noescape::Bool
end

abstract type AbstractNode{T} end

struct Node{T<:Context} <: AbstractNode{T}
    context::T
    tag::String
    children::Vector{Any}
    attrs::Dict{String, Any}
end

function Node(ctx::T, tag::AbstractString, children, attrs) where T <: Context
    tag = validatetag(ctx, normalizetag(ctx, tag))
    Node{T}(
        ctx,
        tag,
        processchildren(ctx, tag, children),
        processattrs(ctx, tag, attrs)
    )
end

function (node::Node{T})(cs...; as...) where T
    ctx = context(node)
    Node{T}(
        ctx,
        tag(node),
        isempty(cs) ? children(node) : prepend!(processchildren(ctx, tag(node), cs), children(node)),
        isempty(as) ? attrs(node)    : merge(attrs(node), processattrs(ctx, tag(node), as))
    )
end

tag(x::Node)      = Base.getfield(x, :tag)
attrs(x::Node)    = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
context(x::Node)  = Base.getfield(x, :context)

function Base.:(==)(x::Node, y::Node)
    context(x)  == context(y)  && tag(x)   == tag(y) &&
    children(x) == children(y) && attrs(x) == attrs(y)
end


## Node utils

function processchildren(ctx, tag, children)
    # Any[] for type-stability Node construction (children::Vector{Any})
    Any[validatechild(ctx, tag, normalizechild(ctx, tag, child)) for child in flat(children)]
end

# A single attribute is allowed to normalize to multiple attributes,
# for example when normalizing CSS attribute names into vendor-prefixed versions.
# TODO: Can remove the isempty check if Iterators.flatten([]) ever returns []
processattrs(ctx, tag, attrs) = if isempty(attrs)
    Dict{String, Any}()
else
    Dict{String, Any}(
        validateattr(ctx, tag, attr′)
        for attr in attrs
        for attr′ in flat(normalizeattr(ctx, tag, attr))
    )
end

function flat(xs::Union{Base.Generator, Tuple, Array})
    out = Any[] # Vector{Any} for node children and attribute values
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

## Rendering

# Top-level nodes render in their own context.
render(io::IO, node::Node) = render(io, context(node), node)
render(node::Node) = sprint(render, node)

Base.show(io::IO, node::Node) = render(io, node)

printescaped(io::IO, x::AbstractString, escapes) = for c in x
    print(io, get(escapes, c, c))
end

# todo: turn the above into something like an escaping IO pipe to avoid string
# allocation via sprint. future use: sprint(printescaped, x, escapes))
printescaped(io::IO, x, escapes) = printescaped(io, sprint(show, x), escapes)

# pass numbers through untrammelled
kebab(camel::String) = join(islowercase(c) || isnumeric(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)

## DOM

function render(io::IO, ctx::DOM, node::Node{DOM})
    etag = escapetag(ctx)
    eattrname = escapeattrname(ctx)
    eattrvalue = escapeattrvalue(ctx)

    print(io, "<")
    printescaped(io, tag(node), etag)
    for (name, value) in pairs(attrs(node))
        print(io, " ")
        printescaped(io, name, eattrname)
        if value != nothing
            print(io, "=\"")
            printescaped(io, value, eattrvalue)
            print(io, "\"")
        end
    end

    if isvoid(tag(node))
        @assert isempty(children(node))
        print(io, " />")
    else
        print(io, ">")
        for child in children(node)
            renderdomchild(io, ctx, child)
        end
        print(io, "</")
        printescaped(io, tag(node), etag)
        print(io, ">")
    end
end

const VOID_TAGS = Set([
    "track", "hr", "col", "embed", "br", "circle", "input", "base",
    "use", "source", "polyline", "param", "ellipse", "link", "img",
    "path", "wbr", "line", "stop", "rect", "area", "meta", "polygon"
])
isvoid(tag) = tag ∈ VOID_TAGS

# Rendering DOM child nodes in their own context
renderdomchild(io, ctx::DOM, node::AbstractNode{DOM}) = render(io, node)

# Render and escape other DOM children, including CSS nodes, in the parent context.
renderdomchild(io, ctx, x) = printescaped(io, x, escapechild(ctx))

# All camelCase attribute names from HTML 4, HTML 5, SVG 1.1, SVG Tiny 1.2, and SVG 2
const HTML_SVG_CAMELS = Dict(lowercase(x) => x for x in [
    "preserveAspectRatio", "requiredExtensions", "systemLanguage",
    "externalResourcesRequired", "attributeName", "attributeType", "calcMode",
    "keySplines", "keyTimes", "repeatCount", "repeatDur", "requiredFeatures",
    "requiredFonts", "requiredFormats", "baseFrequency", "numOctaves", "stitchTiles",
    "focusHighlight", "lengthAdjust", "textLength", "glyphRef", "gradientTransform",
    "gradientUnits", "spreadMethod", "tableValues", "pathLength", "clipPathUnits",
    "stdDeviation", "viewBox", "viewTarget", "zoomAndPan", "initialVisibility",
    "syncBehavior", "syncMaster", "syncTolerance", "transformBehavior", "keyPoints",
    "defaultAction", "startOffset", "mediaCharacterEncoding", "mediaContentEncodings",
    "mediaSize", "mediaTime", "maskContentUnits", "maskUnits", "baseProfile",
    "contentScriptType", "contentStyleType", "playbackOrder", "snapshotTime",
    "syncBehaviorDefault", "syncToleranceDefault", "timelineBegin", "edgeMode",
    "kernelMatrix", "kernelUnitLength", "preserveAlpha", "targetX", "targetY",
    "patternContentUnits", "patternTransform", "patternUnits", "xChannelSelector",
    "yChannelSelector", "diffuseConstant", "surfaceScale", "refX", "refY",
    "markerHeight", "markerUnits", "markerWidth", "filterRes", "filterUnits",
    "primitiveUnits", "specularConstant", "specularExponent", "limitingConeAngle",
    "pointsAtX", "pointsAtY", "pointsAtZ", "hatchContentUnits", "hatchUnits"])

normalizetag(ctx::DOM, tag) = strip(tag)

# The simplest normalization — kebab-case and don't pay attention to the tag.
# Allows both squishcase and camelCase for the attributes above.
# If the attribute name is a string and not a Symbol (using the Node constructor),
# then no normalization is performed — this way you can pass any attribute you'd like.
function normalizeattr(ctx::DOM, tag, (name, value)::Pair{Symbol, <:Any})
    name = string(name)
    get(() -> kebab(name), HTML_SVG_CAMELS, lowercase(name)) => value
end

function normalizeattr(ctx::DOM, tag, attr::Pair{<:AbstractString, <:Any})
    # Note: This must implementation must change if we begin to normalize attr values above.
    # Right now we only normalize attr names.
    attr
end

normalizechild(ctx::DOM, tag, child) = child

# Nice printing in errors
stringify(ctx::DOM, tag, attr::String=" ") = "<$tag>$attr $(isvoid(tag) ? " />" : ">")"
stringify(ctx::DOM, tag, (name, value)::Pair) = stringify(ctx, tag, " $name=$value")

function validatetag(ctx::CSS, tag)
    isempty(tag) && error("Tag cannot be empty.")
    tag
end

function validateattr(ctx::DOM, tag, attr)
    (name, value) = attr
    if !ctx.allow_nan_attr_values && typeof(value) <: AbstractFloat && isnan(value)
        error("NaN values are not allowed for DOM nodes: $(stringify(ctx, tag, attr))")
    end
    if any(isspace, name)
        error("Spaces are not allowed in DOM attribute names: $(stringify(ctx, tag, attr))")
    end
    attr
end

function validatechild(ctx::DOM, tag, child)
    if isvoid(tag)
        error("Void tags are not allowed to have children: $(stringify(ctx, tag))")
    end
    child
end

# Creates an DOM escaping dictionary
chardict(chars) = Dict(c => "&#$(Int(c));" for c in chars)

# See: https://stackoverflow.com/questions/7753448/how-do-i-escape-quotes-in-html-attribute-values
const ATTR_VALUE_ESCAPES = chardict("&<>\"\n\r\t")

# See: https://stackoverflow.com/a/9189067/1175713
const HTML_ESCAPES = chardict("&<>\"'`!@\$%()=+{}[]")

# Used for CSS nodes, as well as children of tag nodes defined with @tags_noescape
const NO_ESCAPES = Dict{Char, String}()

escapetag(ctx::DOM) = HTML_ESCAPES
escapeattrname(ctx::DOM) = HTML_ESCAPES
escapeattrvalue(ctx::DOM) = ATTR_VALUE_ESCAPES
escapechild(ctx::DOM) = ctx.noescape ? NO_ESCAPES : HTML_ESCAPES

# Concise CSS class shorthand
addclass(attrs, class) = haskey(attrs, "class") ? string(attrs["class"], " ", class) : class
Base.getproperty(x::Node{DOM}, class::Symbol) = x(class=addclass(attrs(x), kebab(String(class))))
Base.getproperty(x::Node{DOM}, class::String) = x(class=addclass(attrs(x), class))

const DEFAULT_DOM_CONTEXT = DOM(false, false)
const NOESCAPE_DOM_CONTEXT = DOM(false, true)
m(tag::AbstractString, cs...; as...) = Node(DEFAULT_DOM_CONTEXT, tag, cs, as)
m(ctx::Context, tag::AbstractString, cs...; as...) = Node(ctx, tag, cs, as)

# DOM tags macros
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

macro tags_noescape(args::Symbol...)
    blk = Expr(:block)
    for tag in args
        push!(blk.args, quote
            const $(esc(tag)) = m(NOESCAPE_DOM_CONTEXT, $(string(tag)))
        end)
    end
    push!(blk.args, nothing)
    blk
end

## CSS

ismedia(node::Node{CSS}) = startswith(tag(node), "@media")

function render(io::IO, ctx::CSS, node::Node)
    @assert ctx == context(node)

    etag = escapetag(ctx)
    eattrname = escapeattrname(ctx)
    eattrvalue = escapeattrvalue(ctx)

    printescaped(io, tag(node), etag)
    print(io, " {") # \n

    for (name, value) in pairs(attrs(node))
        printescaped(io, name, eattrname)
        print(io, ": ")
        printescaped(io, value, eattrvalue)
        print(io, ";") # \n
    end

    nestchildren = ismedia(node)
    nestchildren && for child in children(node)
        @assert typeof(child) <: Node{CSS}
        render(io, child)
    end

    print(io, "}") # \n

    !nestchildren && for child in children(node)
        @assert typeof(child) <: Node "CSS child elements must be `Node`s."
        childctx = context(child)
        render(io, Node{typeof(childctx)}(childctx, tag(node) * " " * tag(child), children(child), attrs(child)))
    end
end

normalizetag(ctx::CSS, tag) = strip(tag)

stringify(ctx::CSS, tag, (name, value)::Pair) = "$tag { $name: $value; }"

function validatetag(ctx::DOM, tag)
    isempty(tag) && error("Tag cannot be empty.")
    tag
end

function validateattr(ctx::CSS, tag, attr)
    name, value = attr
    last(attr) == nothing && error("CSS attribute value may not be `nothing`: $(stringify(ctx, tag, attr))")
    last(attr) == "" && error("CSS attribute value may not be the empty string: $(stringify(ctx, tag, attr))")
    if !ctx.allow_nan_attr_values && typeof(value) <: AbstractFloat && isnan(value)
        error("NaN values are not allowed for CSS nodes: $(stringify(ctx, tag, attr))")
    end
    attr
end

function validatechild(ctx::CSS, tag, child)
    typeof(child) <: Node{CSS} || error("CSS nodes may only have Node{CSS} children. Found $(typeof(child)): $child")
    child
end

normalizeattr(ctx::CSS, tag, attr::Pair) = kebab(string(first(attr))) => last(attr)
normalizechild(ctx::CSS, tag, child) = child

escapetag(ctx::CSS) = NO_ESCAPES
escapeattrname(ctx::CSS) = NO_ESCAPES
escapeattrvalue(ctx::CSS) = NO_ESCAPES

const DEFAULT_CSS_CONTEXT = CSS(false)
css(tag, children...; attrs...) = Node(DEFAULT_CSS_CONTEXT, tag, children, attrs)

## Scoped CSS

# A `Styled` node results from the application of a `Style` to a `Node`.
# It serves as a cascade barrier — parent styles do not bleed into nested styled nodes.
struct Styled <: AbstractNode{DOM}
    node::Node{DOM}
    style
end

# delegate
tag(x::Styled) = tag(x.node)
attrs(x::Styled) = attrs(x.node)
children(x::Styled) = children(x.node)
context(x::Styled) = context(x.node)
(x::Styled)(cs...; as...) = Styled(x.node((augmentdom(x.style.id, c) for c in  cs)...; as...), x.style)
render(io::IO, x::Styled) = render(io, x.node)
render(x::Styled) = render(x.node)
Base.show(io::IO, x::Styled) = render(io, x.node)

struct Style
    id::Int
    styles::Vector{Node{CSS}}
    augmentcss(id, node) = Node{CSS}(
        context(node),
        isempty(attrs(node)) || ismedia(node) ? tag(node) : tag(node) * "[v-style$id]",
        augmentcss.(id, children(node)),
        attrs(node)
    )
    Style(id::Int, styles) = new(id, [augmentcss(id, node) for node in styles])
end

style_id = 0
function Style(styles...)
    global style_id
    Style(style_id += 1, styles)
end

styles(x::Style) = x.styles

render(io::IO, x::Style) = for node in x.styles
    render(io, node)
end

augmentdom(id, x) = x # Literals and other non-DOM objects
augmentdom(id, x::Styled) = x # `Styled` nodes act as cascade barriers
augmentdom(id, node::Node{T}) where {T} = Node{T}(
    context(node),
    tag(node),
    augmentdom.(id, children(node)),
    push!(copy(attrs(node)), "v-style$id" => nothing) # note: makes a defensive copy
)
(s::Style)(x::Node) = Styled(augmentdom(s.id, x), s)

#=
future enhancements
    - when applying a Style to a node only add the `v-style` marker to those nodes that may be affected by a style selector.
    - add linting validations for e.g. <circle x=... />
    - autoprefix css attributes based on some criterion, perhaps from caniuse.com
=#

end # module
