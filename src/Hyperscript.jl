#=

future
    clojure-style :attr val :attr val pairs for concision. how do things nest?

discussion points
    at what level do we want to stringify things? early, for validation?
    css autoprefixing
    css: rule order matters, but attrs are a dict. fortunately, order only matters when a later value overrides a previous value with the same key -- exactly what julia handles gracefully at call sites where attributes are specified as key-value pairs
    kebabification except for known properties
    odd cases: code in a <script> (could be js or other), css in a <style>

    nested svg in a html / nested html inside a foreignObject in a svg are handled by just treating them the same

    immutable nodes

    `nothing` for pure key attributes

    single-level noescaping

    note: scoped styles are not dynamic – they are shared between all instances of a component.
    hence our separation into a style that is applied to "instances of a component".

    the pipeline

       normalize => validate => escape => render

       actions:  normalize / validate / escape / render
       subjects: tag / attrname / attrvalue / child
       contexts: CSS / HTML / SVG + validation/escape options
=#

__precompile__()
module Hyperscript

export @tags, @tags_noescape, m, css, Style

## Basic definitions

@enum NodeKind CSS DOM

struct Context{kind, noescape}
    allow_nan_attr_values::Bool
end
kind(::Context{T}) where {T} = T

# Return the normalized property value
normalizetag(ctx, tag) = tag
normalizeattr(ctx, tag, attr) = attr
normalizechild(ctx, tag, child) = child

# Return the property value or throw a validation error
validatetag(ctx, tag) = tag
validateattr(ctx, tag, attr) = attr
validatechild(ctx, tag, child) = child

abstract type AbstractNode{T} end

struct Node{T} <: AbstractNode{T}
    context::Context{T}
    tag::String
    children::Vector{Any}
    attrs::Dict{String, Any}
end

function Node(ctx::Context{T}, tag, children, attrs) where T
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

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
context(x::Node) = Base.getfield(x, :context)

## Node utils

function processchildren(ctx, tag, children)
    # Any[] for type-stability Node construction (children::Vector{Any})
    Any[validatechild(ctx, tag, normalizechild(ctx, tag, child)) for child in flat(children)]
end

# A single attribute is allowed to normalize to multiple attributes,
# for example when normalizing CSS attribute names.
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
    out = [] # for type-stability for node children and attribute values
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
kebab(camel::String) = join(islower(c) || isnumeric(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)

## DOM

function render(io::IO, ctx::Context{DOM}, node::Node{DOM})
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
renderdomchild(io, ctx::Context{DOM}, node::AbstractNode{DOM}) = render(io, node)

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

# The simplest normalization — don't pay attention to the tag and do kebab-case by default.
# Allows both squishcase and camelCase for the attributes above.
# A more targeted version could camelize targeted attributes per-tag.
# Another idea would be to only normalize attributes passed in as Symbols and
# leave strings alone, allowing all attribute names to be specified.
function normalizeattr(ctx::Context{DOM}, tag, (name, value)::Pair)
    name = string(name)
    get(() -> kebab(name), HTML_SVG_CAMELS, lowercase(name)) => value
end

# Nice printing in errors
stringify(ctx::Context{DOM}, tag, attr::String=" ") = "<$tag>$attr $(isvoid(tag) ? " />" : ">")"
stringify(ctx::Context{DOM}, tag, (name, value)::Pair) = stringify(ctx, tag, " $name=$value")

function validateattr(ctx::Context{DOM}, tag, attr)
    (name, value) = attr
    if !ctx.allow_nan_attr_values && typeof(value) <: AbstractFloat && isnan(value)
        error("NaN values are not allowed for DOM nodes: $(stringify(ctx, tag, attr))")
    end
    attr
end

# Creates an DOM escaping dictionary
chardict(chars) = Dict(c => "&#$(Int(c));" for c in chars)

# See: https://stackoverflow.com/questions/7753448/how-do-i-escape-quotes-in-html-attribute-values
const ATTR_VALUE_ESCAPES = chardict("&<>\"\n\r\t")

# See: https://stackoverflow.com/a/9189067/1175713
const HTML_ESCAPES = chardict("&<>\"'`!@\$%()=+{}[]")

# Used for CSS nodes, as well as children of tag nodes defined with @tags_noescape
const NO_ESCAPES = Dict{Char, String}()

escapetag(ctx::Context{DOM}) = HTML_ESCAPES
escapeattrname(ctx::Context{DOM}) = HTML_ESCAPES
escapeattrvalue(ctx::Context{DOM}) = ATTR_VALUE_ESCAPES
escapechild(ctx::Context{DOM}) = HTML_ESCAPES
escapechild(ctx::Context{DOM, true}) = NO_ESCAPES

# Concise CSS class shorthand
addclass(attrs, class) = haskey(attrs, "class") ? string(attrs["class"], " ", class) : class
Base.getproperty(x::Node{DOM}, class::Symbol) = x(class=addclass(attrs(x), kebab(String(class))))
Base.getproperty(x::Node{DOM}, class::String) = x(class=addclass(attrs(x), class))

const DEFAULT_DOM_CONTEXT = Context{DOM, false}(false)
const NOESCAPE_DOM_CONTEXT = Context{DOM, true}(false)
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

function render(io::IO, ctx::Context{CSS}, node::Node)
    @assert ctx == context(node)

    etag = escapetag(ctx)
    eattrname = escapeattrname(ctx)
    eattrvalue = escapeattrvalue(ctx)

    printescaped(io, tag(node), etag)
    print(io, " {\n")

    for (name, value) in pairs(attrs(node))
        printescaped(io, name, eattrname)
        print(io, ": ")
        printescaped(io, value, eattrvalue)
        print(io, ";\n")
    end

    nestchildren = ismedia(node)
    nestchildren && for child in children(node)
        @assert typeof(child) <: Node{CSS}
        render(io, child)
    end

    print(io, "}\n")

    !nestchildren && for child in children(node)
        @assert typeof(child) <: Node "CSS child elements must be `Node`s."
        childctx = context(child)
        render(io, Node{kind(childctx)}(childctx, tag(node) * " " * tag(child), children(child), attrs(child)))
    end
end

function validateattr(ctx::Context{CSS}, tag, attr)
    last(attr) != nothing || error("CSS attribute value may not be `nothing`.")
    attr
end

function validatechild(ctx::Context{CSS}, tag, child)
    typeof(child) <: Node{CSS} || error("CSS nodes may only have Node{CSS} children. Found $(typeof(child)): $child")
    child
end
normalizeattr(ctx::Context{CSS}, tag, attr::Pair) = kebab(string(first(attr))) => last(attr)

escapetag(ctx::Context{CSS}) = NO_ESCAPES
escapeattrname(ctx::Context{CSS}) = NO_ESCAPES
escapeattrvalue(ctx::Context{CSS}) = NO_ESCAPES

const DEFAULT_CSS_CONTEXT = Context{CSS, false}(false)
css(tag, children...; attrs...) = Node(DEFAULT_CSS_CONTEXT, tag, children, attrs)

## Scoped CSS

# A `Styled` node results from the application of a `Style` to a `Node`.
# It serves as a cascade barrier — parent styles do not bleed into nested styled nodes.
struct Styled{T} <: AbstractNode{T}
    node::Node{T}
    style
end

# delegate
tag(x::Styled) = tag(x.node)
attrs(x::Styled) = attrs(x.node)
children(x::Styled) = children(x.node)
context(x::Styled) = context(x.node)
(x::Styled)(cs...; as...) = Styled(x.node(cs...; as...))
render(io::IO, x::Styled) = render(io, x.node)
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

end # module
