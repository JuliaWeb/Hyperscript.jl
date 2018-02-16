isnothing(x) = x == nothing
kebab(camel::String) = join(islower(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)
kebab(camel::Symbol) = kebab(String(camel))

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
    scoped css
    css prefixing
    media queries
    prettyprinting with indentation
    html/svg attributes without value (use nothing)
    html escaping for html/svg
    different escaping rules for css and script tags

    think about what it might be like to make this do dom nodes rather than html nodes -- e.g. class -> className
=#

#=
    parameters

        content escaping on output
            attributes - e.g. attribute escape
            children - e.g. html escape, css/script escape
        transformation on input
            attributes - e.g. kebab case
            children
        allowed children
            css rules can nest
            css rules are unwelcome inside html/svg trees
            html trees are unwelcome inside css rules
        in fact, the only real interface between these things
        might be the stylednode concept.
=#

struct Node
    tag::String
    children::Vector{Any}
    attrs::Dict{String, Any}
    Node(tag, children, attrs) = new(tag, flat(children), attrs)
end

tag(x::Node) = Base.getfield(x, :tag)
attrs(x::Node) = Base.getfield(x, :attrs)
children(x::Node) = Base.getfield(x, :children)

# Recursively flatten generators, tuples, and arrays. Wrap scalars in a single-element tuple.
# todo: We could do something trait-based, so custom lazy collections can opt into compatibility
# todo: What does broadcast do? Do we want Array or AbstractArray?
function flat(xs::Union{Base.Generator, Tuple, Array})
    out = []
    for x in xs
        append!(out, flat(x))
    end
    out
end
flat(x) = (x,)

# Allow extending a node using function application syntax.
# Overrides attributes and appends children.
function (node::Node)(cs...; as...)
    Node(
        tag(node),
        isempty(as) ? attrs(node)    : merge(attrs(node), as),
        isempty(cs) ? children(node) : prepend!(flat(cs), children(node))
    )
end

Base.show(io::IO, node::Node) = render(io, node)

#=
    things you do with nodes
        render them
        add children
        add attributes

    any differences between html and svg?
        validation
    any differences betwen html/svg nodes and css nodes?
        validation
        rendering
        autoprefixing [may be seen as part of rendering]



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
