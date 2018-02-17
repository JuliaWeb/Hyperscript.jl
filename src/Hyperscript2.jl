# idea: use clojure-style :attr val :attr val pairs for the concise macro. question: how do things nest?

isnothing(x) = x == nothing
kebab(camel::String) = join(islower(c) || c == '-' ? c : '-' * lowercase(c) for c in camel)
kebab(camel::Symbol) = kebab(String(camel))

#=  the pipeline

    normalize => validate => escape => render

    actions:  normalize / validate / escape / render
    subjects: tag / attrname / attrvalue / child
    contexts: CSS / HTML / SVG + validation/escape options (treat nan as invalid?)

    further nuance: specific versions of the specs

    validate_tag(::CSS, tag)
    validate_attr_name(::CSS, tag, attr_name)
    validate_attr_value(::CSS, tag, attr_name, attr_value)
    validate_child(::CSS, tag, child)


    normalize_tag
    normalize_attr(::CSS, name, value)
    normalize_child(::CSS, name, value)



    normalize_attr_name(::CSS,
    normalize_attr_value(:CSS,
    normalize_child(::CSS
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
