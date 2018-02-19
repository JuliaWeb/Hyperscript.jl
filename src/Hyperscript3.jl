module Hyperscript

@enum NodeKind CSS HTML

struct Context{kind}
end

normalizetag(ctx, tag) = tag
normalizeattr(ctx, tag, attr) = attr
normalizechild(ctx, tag, child) = child

processchildren(ctx, tag, children) =
    validatechild.(ctx, tag, normalizechild.(ctx, tag, flat(children)))

validatetag(ctx, tag) = tag
validateattr(ctx, tag, attr) = attr
validatechild(ctx, tag, child) = child

processattrs(ctx, tag, attrs) =
    (validateattr(ctx, tag, normalizeattr(ctx, tag, attr)) for attr in attrs)

function flat(xs::Union{Base.Generator, Tuple, Array})
    out = eltype(xs)[]
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

struct Node{T <: Context}
    context::T
    tag::String
    children::Vector
    attrs::Dict{String, Any}
end

function Node(ctx::T, tag, children, attrs) where T
    tag = validatetag(ctx, normalizetag(ctx, tag))
    Node{T}(ctx, tag, processchildren(ctx, tag, children), Dict(processattrs(ctx, tag, attrs)))
end

function (node::Node)(cs...; as...)
    Node(
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

## Rendering

render(io::IO, node::Node) = render(io, context(node), node)
render(node::Node) = sprint(render, node)

Base.show(io::IO, node::Node) = render(io, node)

# todo: turn this into something like an escaping IO pipe to avoid the necessity of allocating x
# so that we can say something like sprint(printescaped, x, escapes)
printescaped(io::IO, x::AbstractString, escapes) = for c in x
    print(io, get(escapes, c, c))
end
printescaped(io::IO, x, escapes) = printescaped(io, sprint(show, x), escapes)

###

kebab(camel::String) = join(islower(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)

# HTML

function render(io::IO, ctx::Context{HTML}, node::Node)
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

    if isvoid(ctx, tag(node))
        @assert isempty(children(node))
        print(io, " />")
    else
        print(io, ">")
        for child in children(node)
            renderchild(io, ctx, child)
        end
        print(io, "</")
        printescaped(io, tag(node), etag)
        print(io, ">")
    end
end

isvoid(ctx::Context{HTML}, tag) = false

# Render child nodes in their own context
renderchild(io, ctx, node::Node) = render(io, context(node), node)

# Render child non-nodes in their parent's context
renderchild(io, ctx, x) = printescaped(io, x, escapechild(ctx))

# note: we will want to mandate camelCase and not squishcase for e.g. stop-color.
# and we should allow camelCase and squishcase for e.g. viewBox.
normalizeattr(ctx::Context{HTML}, tag, attr::Pair) = kebab(string(first(attr))) => last(attr)
# validateattr(ctx:Context{HTML}, tag, attr) = ...

# Creates an HTML escaping dictionary
chardict(chars) = Dict(c => "&#$(Int(c));" for c in chars)

# See: https://stackoverflow.com/questions/7753448/how-do-i-escape-quotes-in-html-attribute-values
const ATTR_VALUE_ESCAPES = chardict("&<>\"\n\r\t")

# See: https://stackoverflow.com/a/9189067/1175713
const HTML_ESCAPES = chardict("&<>\"'`!@\$%()=+{}[]")

escapetag(ctx::Context{HTML}) = HTML_ESCAPES
escapeattrname(ctx::Context{HTML}) = HTML_ESCAPES
escapeattrvalue(ctx::Context{HTML}) = ATTR_VALUE_ESCAPES
escapechild(ctx::Context{HTML}) = HTML_ESCAPES

# Concise CSS class shorthand
addclass(attrs, class) = haskey(attrs, "class") ? string(attrs["class"], " ", class) : class
Base.getproperty(x::Node{Context{HTML}}, class::Symbol) = x(class=addclass(attrs(x), kebab(class)))
Base.getproperty(x::Node{Context{HTML}}, class::String) = x(class=addclass(attrs(x), class))

m_html(tag, children...; attrs...) = Node(Context{HTML}() #= might be useful to pull out into a const once it has parameters =#, tag, children, attrs)

# HTML tags macro
macro tags(args::Symbol...)
    blk = Expr(:block)
    for tag in args
        push!(blk.args, quote
            const $(esc(tag)) = m_html($(string(tag)))
        end)
    end
    push!(blk.args, nothing)
    blk
end

# CSS

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
        # todo: assert value != nothing in validation
        printescaped(io, value, eattrvalue)
        print(io, ";\n")
    end

    ismedia = startswith(tag(node), "@media")

    ismedia && for child in children(node)
        @assert typeof(child) <: Node
        render(io, child)
    end

    print(io, "}\n")

    !ismedia && for child in children(node)
        @assert typeof(child) <: Node "CSS child elements must be `Node`s."
        childctx = context(child)
        render(io, Node{typeof(childctx)}(childctx, tag(node) * " " * tag(child), children(child), attrs(child)))
    end
end

normalizeattr(ctx::Context{CSS}, tag, attr::Pair{<:Any, <:Any}) = kebab(string(first(attr))) => last(attr)

const NO_ESCAPE = Dict{Char, String}()
escapetag(ctx::Context{CSS}) = NO_ESCAPE
escapeattrname(ctx::Context{CSS}) = NO_ESCAPE
escapeattrvalue(ctx::Context{CSS}) = NO_ESCAPE

m_css(tag, children...; attrs...) = Node(Context{CSS}(), tag, children, attrs)

###

@tags div span

htmlnode = div(align="foo", span("child span"), "and then some") #m_html("div", align="foo", m_html("div", moo="false", boo=true)("x<x >", extra=nothing, boo=5))
cssnode = m_css("@media(foo < 3)",
    m_css(".foo .bar", arcGis=3, flip="flap", m_css("nest nest", color="red"))
)
@show htmlnode


end # module