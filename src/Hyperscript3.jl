__precompile__()
module Hyperscript

export @tags, m, css, Style

## Basic definitions

@enum NodeKind CSS DOM

struct Context{kind}
    allow_nan_attr_values::Bool
    Context{T}(;allow_nan_attr_values) where {T} = new(allow_nan_attr_values)
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

struct Node{T}
    context::Context{T}
    tag::String
    children::Vector{Any}
    attrs::Dict{String, Any}
end

function Node(ctx::Context{T}, tag, children, attrs) where T
    tag = validatetag(ctx, normalizetag(ctx, tag))
    Node{T}(ctx, tag, processchildren(ctx, tag, children), Dict(processattrs(ctx, tag, attrs)))
end

function (node::Node{T})(cs...; as...) where T
    Node{T}(
        context(node),
        tag(node),
        isempty(cs) ? children(node) : prepend!(processchildren(context(node), tag(node), cs), children(node)),
        isempty(as) ? attrs(node)    : merge(attrs(node), Dict(processattrs(context(node), tag(node), as)))
    )
end

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
context(x::Node) = Base.getfield(x, :context)

## Node utils

processchildren(ctx, tag, children) =
    Any[validatechild(ctx, tag, normalizechild(ctx, tag, child)) for child in flat(children)] # for prepend! type-stability at Vector{Any}

processattrs(ctx, tag, attrs) =
    (validateattr(ctx, tag, normalizeattr(ctx, tag, attr)) for attr in attrs)

function flat(xs::Union{Base.Generator, Tuple, Array})
    out = [] # for type-stability with Node.children::Vector{Any}
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

## Rendering

render(io::IO, node::Node) = render(io, context(node), node)
render(node::Node) = sprint(render, node)

Base.show(io::IO, node::Node) = render(io, node)

printescaped(io::IO, x::AbstractString, escapes) = for c in x
    print(io, get(escapes, c, c))
end

# todo: turn the above into something like an escaping IO pipe to avoid
# sprint allocation. future use: sprint(printescaped, x, escapes))
printescaped(io::IO, x, escapes) = printescaped(io, sprint(show, x), escapes)

# pass numbers through untrammelled
kebab(camel::String) = join(islower(c) || isnumeric(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)

## DOM

function render(io::IO, ctx::Context{DOM}, node::Node)
    @assert ctx == context(node)

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
    "track", "hr", "col", "embed", "br", "circle", "input", "base", "use",
    "source", "polyline", "param", "ellipse", "link", "img", "path",
    "keygen", "wbr", "line", "stop", "rect", "area", "meta", "polygon"
])
isvoid(tag) = tag ∈ VOID_TAGS

# Render child nodes in their own context
renderdomchild(io, ctx, node::Node) = render(io, context(node), node)

# Render child non-nodes in their parent's context
renderdomchild(io, ctx, x) = printescaped(io, x, escapechild(ctx))

# Found using filter(x -> any(isupper, x), union(values(COMBINED_ATTRS)...))
# using attribute data from from the previous iteration of Hyperscript
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
stringify(ctx::Context{DOM}, tag) = string("<", tag, isvoid(tag) ? " />" : ">")
stringify(ctx::Context{DOM}, tag, (name, value)::Pair) = string("<", tag, " ", name, "=\"", value, "\"", isvoid(tag) ? " />" : ">")

function validateattr(ctx::Context{DOM}, tag, attr::Pair)
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

escapetag(ctx::Context{DOM}) = HTML_ESCAPES
escapeattrname(ctx::Context{DOM}) = HTML_ESCAPES
escapeattrvalue(ctx::Context{DOM}) = ATTR_VALUE_ESCAPES
escapechild(ctx::Context{DOM}) = HTML_ESCAPES

# Concise CSS class shorthand
addclass(attrs, class) = haskey(attrs, "class") ? string(attrs["class"], " ", class) : class
Base.getproperty(x::Node{DOM}, class::Symbol) = x(class=addclass(attrs(x), kebab(class)))
Base.getproperty(x::Node{DOM}, class::String) = x(class=addclass(attrs(x), class))

const DEFAULT_DOM_CONTEXT = Context{DOM}(allow_nan_attr_values=false)
m(tag, children...; attrs...) = Node(DEFAULT_DOM_CONTEXT, tag, children, attrs)

# DOM tags macro
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

    nest = ismedia(node) # should we nest children inside this node?

    nest && for child in children(node)
        @assert typeof(child) <: Node
        render(io, child)
    end

    print(io, "}\n")

    !nest && for child in children(node)
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
normalizeattr(ctx::Context{CSS}, tag, attr::Pair{<:Any, <:Any}) = kebab(string(first(attr))) => last(attr)

const NO_ESCAPE = Dict{Char, String}()
escapetag(ctx::Context{CSS}) = NO_ESCAPE
escapeattrname(ctx::Context{CSS}) = NO_ESCAPE
escapeattrvalue(ctx::Context{CSS}) = NO_ESCAPE

const DEFAULT_CSS_CONTEXT = Context{CSS}(allow_nan_attr_values=false)
css(tag, children...; attrs...) = Node(DEFAULT_CSS_CONTEXT, tag, children, attrs)

## Scoped CSS

# A `Styled` (styled node) is returned from the application of a `Style` to a `Node`.
# `Styled` serves as a cascade barrier — parent styles do not affect nested styled nodes.
struct Styled{T}
    node::Node{T}
end

# delegate
tag(x::Styled) = tag(x.node)
attrs(x::Styled) = attrs(x.node)
children(x::Styled) = children(x.node)
context(x::Styled) = context(x.node)
(x::Styled)(cs...; as...) = Styled(x.node(cs...; as...))
render(io::IO, x::Styled) = render(io, x.node)
renderdomchild(io, ctx, x::Styled) = render(io, ctx, x.node)
Base.show(io::IO, x::Styled) = render(io, x.node)

struct Style
    id::Int
    nodes::Vector{Node{CSS}}
    augmentcss(id, node) = Node{CSS}(
        context(node),
        isempty(attrs(node)) || ismedia(node) ? tag(node) : tag(node) * "[v-style-$id]",
        augmentcss.(id, children(node)),
        attrs(node)
    )
    Style(id::Int, nodes) = new(id, [augmentcss(id, node) for node in nodes])
end

style_id = 0
function Style(nodes...)
    global style_id
    Style(style_id += 1, nodes)
end

render(io::IO, x::Style) = for node in x.nodes
    render(io, node)
end

augmentdom(id, x) = x # Literals and other non-DOM objects
augmentdom(id, x::Styled) = x # `Styled` nodes act as cascade barriers
augmentdom(id, node::Node{T}) where {T} = Node{T}(
    context(node),
    tag(node),
    augmentdom.(id, children(node)),
    push!(copy(attrs(node)), "v-style-$id" => nothing) # note: makes a defensive copy
)
(s::Style)(x::Node) = Styled(augmentdom(s.id, x))

end # module