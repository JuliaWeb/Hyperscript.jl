
#=
println()
@show css(".selector", x="<foo")
htmlnode = div(align=true, patternunits=4, patternFnits=4,
    span(patternUnits=3, "child span"), "and then some") #m("div", align="foo", m("div", moo="false", boo=true)("x<x >", extra=nothing, boo=5))
cssnode = css("@media(foo < 3)",
    css(".foo .bar", arcGis=3, flip="flap", css("nest nest", color="red"))
)
styl = Style(cssnode)
styl2 = Style(cssnode)
@show styl(span(span("nest", span(styl2(span("h<iiii"))))))
@show htmlnode

=#

#=
    notes
        - we do not escape CSS attribute names or values.
    todo
        - a way to not escape e.g. the contents of script or style tags
    future
        - a way to have per-node-kind configuration structs -- rather than
        the context being forced to accomodate both use cases.

=#



#=
    todo
        how do mime-types fit into all this?
            # mime = MIME(mimewritable(MIME("text/html"), x) ? "text/html" : "text/plain")
            # Base.show(io::IO, ::MIME"text/html", node::Node{Context{HTML}}) = render(io, node)
        css escapes
            https://www.w3.org/International/questions/qa-escapes
        css validation
            prevent non-cssnode children
            prevent eg. nothing attr values
        scoped css
            can this be handled as a layer atop? probably yes for the thing we have so far;
            but there is the other thing of auto-extract csses from a page and put them in a
            style tag in the head
        css autoprefixing
        html validation
            nan attr values
        html/svg normalization
            squishcase kebabcase data-attrs kebab-with-numbers camel case for the legit camels
        html/svg isvoid
    bonus
        pretty-printing option for indentation

=#

module Hyperscript

abstract type NodeKind end

struct CSS  <: NodeKind end
struct HTML <: NodeKind end # means html & svg

struct Context{kind <: NodeKind}
end

normalizetag(ctx, tag) = tag
normalizeattr(ctx, tag, attr) = attr
normalizechild(ctx, tag, child) = child

validatetag(ctx, tag) = tag
validateattr(ctx, tag, attr) = attr
validatechild(ctx, tag, child) = child

const DEFAULT_ESCAPES = Dict{Char, String}()
escapetag(ctx) = DEFAULT_ESCAPES
escapeattrname(ctx) = DEFAULT_ESCAPES
escapeattrvalue(ctx) = DEFAULT_ESCAPES
escapechild(ctx) = DEFAULT_ESCAPES

function flat(xs::Union{Base.Generator, Tuple, Array})
    out = [] # eltype(xs)[]
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

vn_children(ctx, tag, children) =
    validatechild.(ctx, tag, normalizechild.(ctx, tag, flat(children)))
vn_attrs(ctx, tag, attrs) =
    (validateattr(ctx, tag, normalizeattr(ctx, tag, attr)) for attr in attrs)

struct Node{C <: Context}
    context::C
    tag::String
    children::Vector{Any}
    attrs::Dict{String, Any}
end

function Node(ctx::C, tag, children, attrs) where C
    tag = validatetag(ctx, normalizetag(ctx, tag))
    Node{C}(ctx, tag, vn_children(ctx, tag, children), Dict(vn_attrs(ctx, tag, attrs)))
end

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)
context(x::Node) = Base.getfield(x, :context)

function (node::Node)(cs...; as...)
    Node(
        context(node),
        tag(node),
        isempty(cs) ? children(node) : prepend!(vn_children(context(node), tag(node), cs), children(node)),
        isempty(as) ? attrs(node)    : merge(attrs(node), Dict(vn_attrs(context(node), tag(node), as)))
    )
end

printescaped(io::IO, x::String, escapes) = for c in x # todo: turn this into something like an escaping IO pipe to avoid the necessity to allocate x
    print(io, get(escapes, c, c))
end
printescaped(io::IO, x, escapes) = printescaped(io, sprint(show, x), escapes)

render(io::IO, node::Node) = render(io, context(node), node)
render(node::Node) = sprint(render, node)
render(io::IO, ctx, x) = printescaped(io, x, escapechild(ctx)) # non-nodes

Base.show(io::IO, node::Node) = render(io, node)

# invariant: a node always renders in its own context.
# the ctx argument is used only for rendering _non-nodes_ in the context of their parent node.

###

isnothing(x) = x == nothing
kebab(camel::String) = join(islower(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)
# kebab(camel::Symbol) = kebab(String(camel))

# contains(s, r"^data[0-9A-Z]") && return "data-" * lowercase(s[5]) * kebab(s[6:end])

# HTML

# Creates an HTML escaping dictionary
chardict(chars) = Dict(c => "&#$(Int(c));" for c in chars)
# See: https://stackoverflow.com/questions/7753448/how-do-i-escape-quotes-in-html-attribute-values
const ATTR_VALUE_ESCAPES = chardict("&<>\"\n\r\t")
# See: https://stackoverflow.com/a/9189067/1175713
const HTML_ESCAPES = chardict("&<>\"'`!@\$%()=+{}[]")

# note: can avoid extra stringification by overriding attr::Pair{String, <:Any} and so forth
normalizeattr(ctx::Context{HTML}, tag, attr::Pair{<:Any, <:Any}) = kebab(string(first(attr))) => last(attr)
# validateattr(ctx:Context{HTML}, tag, attr) => isnan(last(attr)) && error(xxxx)

escapetag(ctx::Context{HTML}) = HTML_ESCAPES
escapeattrname(ctx::Context{HTML}) = HTML_ESCAPES
escapeattrvalue(ctx::Context{HTML}) = ATTR_VALUE_ESCAPES
escapechild(ctx::Context{HTML}) = HTML_ESCAPES

addclass(attrs, class) = haskey(attrs, "class") ? string(attrs["class"], " ", class) : class
Base.getproperty(x::Node{Context{HTML}}, class::Symbol) = x(class=addclass(attrs(x), kebab(class)))
Base.getproperty(x::Node{Context{HTML}}, class::String) = x(class=addclass(attrs(x), class))

isvoid(ctx::Context{HTML}, tag) = false

# note: how do we e.g. render css or script text unescaped?
# something like escapechild(ctx::Context{HTML}, x::ScriptRaw) = x?

# Render child nodes in their own context
renderchild(io, ctx, node::Node) = render(io, context(node), node)

# Render child non-nodes in their parent's context
renderchild(io, ctx, x) = render(io, ctx, x)

function render(io::IO, ctx::Context{HTML}, node::Node)
    @assert ctx == context(node)
    etag, eattrname, eattrvalue = escapetag(ctx), escapeattrname(ctx), escapeattrvalue(ctx)

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


m_html(tag, children...; attrs...) = Node(Context{HTML}(), tag, children, attrs)

###


# CSS

function render(io::IO, ctx::Context{CSS}, node::Node)
    @assert ctx == context(node)
    etag, eattrname, eattrvalue = escapetag(ctx), escapeattrname(ctx), escapeattrvalue(ctx)

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
    if ismedia
        for child in children(node)
            @assert typeof(child) <: Node
            render(io, child) # could just use render here; these should always be nodes (todo: validate)
        end
    end

    print(io, "}\n")

    if !ismedia
        for child in children(node)
            @assert typeof(child) <: Node "CSS child elements must be `Node`s."
            childctx = context(child)
            render(io, Node{typeof(childctx)}(childctx, tag(node) * " " * tag(child), children(child), attrs(child)))
        end
    end
end

normalizeattr(ctx::Context{CSS}, tag, attr::Pair{<:Any, <:Any}) = kebab(string(first(attr))) => last(attr)

escapetag(ctx::Context{CSS}) = DEFAULT_ESCAPES
escapeattrname(ctx::Context{CSS}) = DEFAULT_ESCAPES
escapeattrvalue(ctx::Context{CSS}) = DEFAULT_ESCAPES
# there are no children for css trees
# escapechild(ctx::Context{CSS}) = DEFAULT_ESCAPES

m_css(tag, children...; attrs...) = Node(Context{CSS}(), tag, children, attrs)




















###


# m("div", malign="noo"))#
node = m_html("div", align="foo", m_html("div", moo="false", boo=true)("x<x >", extra=nothing, boo=5))
cssnode = m_css("@media(foo < 3)",
    m_css(".foo .bar", arcGis=3, flip="flap", m_css("nest nest", color="red"))
)
@show cssnode

# 1.
# Node(Context{HTML}(), "div", [
#     Node(Context{HTML}(), "div", [], Dict("moo" => "false"))
# ], Dict("align" => "true"))
# 2.
# m("div", align="foo", m("div", moo="false"))


#= questions

at what level do we want to stringify things? probably early, so we can validate the values.

what do we want to use for stringification? `string()` uses `print`.

how do we turn a single attr into multiple attrs, e.g. -webkit- and -moz- versions of a css rule?
    maybe we do this at output time.

does order matter for css rules? yes, but julia's keyword-splatting & rules about repeated keywords just make it all work out.

we could have a DOM node representation with e.g. className and so on, and no kebabification.
if so, would we still want Dict{String, String} for attrs, or Dict{Symbol, String}, or even Dict{Symbol, Any}?

=#


# idea: use clojure-style :attr val :attr val pairs for the concise macro. question: how do things nest?




#=

struct NormalizeConfig end
struct ValidateConfig end
struct EscapeConfig end

# todo: what context do the various pieces need?

# Throw an error if the thing is invalid; otherwise do nothing
function validatetag(ctx, tag)
end
function validateattr(ctx, tag, name, value)
end
function validatechild(ctx, tag, child)
end

# Return the escaped version of the thing.

=#



#=  the pipeline

    normalize => validate => escape => render

    actions:  normalize / validate / escape / render
    subjects: tag / attrname / attrvalue / child
    contexts: CSS / HTML / SVG + validation/escape options (treat nan as invalid?)

    further nuance: specific versions of the specs

    validatetag(::CSS, tag)
    validateattrname(::CSS, tag, attrname)
    validateattrvalue(::CSS, tag, attrname, attrvalue)
    validatechild(::CSS, tag, child)


    normalizetag
    normalizeattr(::CSS, name, value)
    normalizechild(::CSS, name, value)



    normalizeattrname(::CSS,
    normalizeattrvalue(:CSS,
    normalizechild(::CSS
=#


#= odd cases

code in a <script>
    js or otherwise

css in a <style>

nested svg in a html
nested html inside a foreignObject in a svg


=#

#=
design note
    at the lowest level, we should not transform user input to
    conform to any particular scheme, e.g. kebabcase. the most
    basic use should be to store input as it was provided and
    output it in the same format.

    sugar for adding attributes and children is fine; but sugar
    for e.g. class="..." should be constrained to those node types
    that support it.
=#

#=
concerns
    early-as-possible detection of errors
        invalid attributes
        invalid tagnames
        nan values

    deal with void tags [but only in html/svg!]

    html, svg, css
    scoped css — an orthogonal toolkit for creating scoped-css "components"
    css prefixing
    media queries – use tree nesting behavior rather than selector flattening to render
    prettyprinting with indentation
    html/svg attributes without value (use nothing) — but not with css.
    html escaping for html/svg
    different escaping rules for css and script tags

    think about what it might be like to make this do dom nodes rather than html nodes -- e.g. class -> className
=#



#=
    normalization
        attribute names
        attribute values
        child values

    validation
        attribute names
        attribute values
        child values

    escaping behavior
        attribute names
        attribute values
        child values

    allowed children - do we want to validate here, or just allow anything stringifiable?
        attribute names
        attribute values
        child values


    parameters
        content escaping on output
            attributes - e.g. attribute escape
            children - e.g. html escape, css/script escape
        normalization on input
            attributes - e.g. kebab case
            children
        allowed children
            css rules can nest
            css rules are unwelcome inside html/svg trees
            html trees are unwelcome inside css rules
        in fact, the only real interface between these things
        might be the stylednode concept.
=#


#=
    things you do with nodes
        render them
        add children
        add attributes

    any differences between html and svg?
        validation
    any differences betwen html/svg nodes and css nodes?
        validation
        normalization [possibly]
        rendering
        autoprefixing [may be seen as part of rendering]



=#


#=
    what is the most useful behavior for extending css nodes using function application syntax,
    or otherwise reusing them? E.g. putting one existing node inside another, or splatting one in
    (should that splat attrs?)
=#

#=
    use cases for nodes

        html node
            - can have html children, including <svg>, which can have only svg children
        svg node
            - can have svg children, including <foreignObject>, which can have only html children
        css node
=#

#= the bostock take: https://beta.observablehq.com/@mbostock/saving-svg
serialize = {
  const xmlns = "http://www.w3.org/2000/xmlns/";
  const xlinkns = "http://www.w3.org/1999/xlink";
  const svgns = "http://www.w3.org/2000/svg";
  return function serialize(svg) {
    svg = svg.cloneNode(true);
    if (!svg.hasAttributeNS(xmlns, "xmlns")) {
      svg.setAttributeNS(xmlns, "xmlns", svgns);
    }
    if (!svg.hasAttributeNS(xmlns, "xmlns:xlink")) {
      svg.setAttributeNS(xmlns, "xmlns:xlink", xlinkns);
    }
    const serializer = new window.XMLSerializer;
    const string = serializer.serializeToString(svg);
    return new Blob([string], {type: "image/svg+xml"});
  };
}
=#



# Recursively flattens generators, tuples, and arrays.
# Wraps scalars in a single-element tuple.
# todo: We could do something trait-based, so custom lazy collections can opt into compatibility
# todo: What does broadcast do? Do we want Array or AbstractArray?
# function flat

#= this may only make sense for some types of nodes — or maybe not?
function (node::Node)(cs...; as...)
    Node(
        tag(node),
        isempty(as) ? attrs(node)    : merge(attrs(node), as),
        isempty(cs) ? children(node) : prepend!(flat(cs), children(node))
    )
end
=#

# [Escape can directly write to io if more efficient]

# we use attr rather than attrname and attrvalue for validation/normalization
# due to the brevity gains. it was terribly verbose otherwise.

# q: do we even store attrs in a dict? what if we had parallel arrays?

# we need to preserve nothing until printing.
# this gives another perspective:
# everything is _aligned_ -- all the way through the stack.
# from representation up here, through normalization and validation.
# rather than string-ing early, we can keep some things in a more type-rich format.
# for example, then we could provide a 'trim-numbers' for ctxs.
# also, if we want OTHER contexts to control our printing, then some things need
# to be done at print time rather than eagerly.
# we should do as much eagerly as is needed to give early errors. and perhaps not more.
# another argument: storing numbers allows us to check for nan in validation; otherwise
# normalization would stringify and we couldn't tell NaN from "NaN" without yet another
# normalization step. And stringifying only on out is less work to do, particularly with
# our new relaxed attitude towards validation.
# number, nothing, string


# todo: do an allocation optimization pass

#=
normalization and validation of tags, attributes, and children
should function differently for each; hence there is no central
point of override for the set.

escaping of tags, attributes, and children, however, has potential
to be uniform across all three types; hence there is an `escape`
fallback for the three separate methods.
^ untrue; even html attr/otherwise escapes are different.
=#

#=

The ctx argument in the render(io, ctx, node) method may render a node
in a modified context from its own — for example in order to nest one
type of node inside another.

^ Not sure if this is coherent, but it feels like a potentially useful
source of functionality.

It is at least useful for dispatch — the context type parameters function
as traits.

=#

# node children:  # should we make this not-any but rather specialized per node? might make rendering faster for lots of same-type children

# todo: maybe don't define these by default, forcing explicit non-escaping?
# or even better: define methods for "replacements", which are applied upon
# print — with the escape functions below, you can return a non-string that
# ends up having invalid characters. hrm. what is the least amount of temp
# stringing plus guaranteed escapingness?
# escapetag(ctx, tag) = HTML_ESCAPES # sort of thing

#=
actions:  normalize / validate / escape / render
subjects: tag / attr name / attr value / child
contexts: CSS / HTML / SVG + per-action options

Nodes are normalized and validated on input and escaped upon output.

The core is free of mention of any specific output target; HTML/SVG/CSS
are implemented separately.

Contexts are loci for target-specific parameterization; e.g. `isvoid`
might be a function only of HTML and SVG targets.

=#

end # module