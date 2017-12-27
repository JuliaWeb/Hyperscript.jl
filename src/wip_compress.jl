using Base.Iterators
include("constants.jl")

const COMBINED_TAGS  = union(SVG_TAGS, HTML_TAGS)
const COMBINED_ATTR_NAMES = union(collect(values(HTML_ATTR_NAME)), collect(values(SVG_ATTR_NAME)))

const strings = union(COMBINED_TAGS, COMBINED_ATTR_NAMES)
const codes = UInt16[1:length(strings)...]
const encoded = Dict(zip(strings, codes))
const decoded = Dict(zip(codes, strings))

encode(x::String) = UInt16(encoded[x])
decode(x::UInt16) = decoded[x]

encode(x::String, y::String) = encode(encode(x), encode(y))
decode(x::UInt32) = decode(UInt16(x >> 16)), decode(UInt16(x & (typemax(UInt32)>>16)))

@show COMBINED_ATTR_NAMES

# COMBINED_ATTR_NAME
# HTML_ATTR_NAME
# SVG_ATTR_NAME
# COMBINED_ATTRS
# HTML_ATTRS
# SVG_ATTRS
# COMBINED_TAGS
# HTML_TAGS
# SVG_TAGS


# tag ∈ tags(v)
# valid = attr ∈ ATTRS[tag] || attr ∈ ATTRS["*"]
# attr = get(sym_to_attr, sym) do error(...) end

# is a tag valid? [does this 16-bit int exist in this set]
# - is valid for svg = [is it valid and also less than this number]
# is an attribute valid for the given tag? [does this 32-bit int exist in this set]
#=
tag_valid_lookup =

struct Validation
    name::String
    tag_codes::Set
    tag_attr_codes::Set
end

const V_COMBINED = Validation(

isvalidtag(v::Validation, tag) = tag ∈ v.tag_codes)
isvalidattr(v::Validation, attr, tag) = haskey(encode(tag, attr), v.tag_attr_codes)

validateattr(v::ValidateCombined, attr, tag) =
# validateattr(v::ValidateHTML, attr, tag) =
# validateattr(v::ValidateSVG, attr, tag) =
# validateattr(v::ValidateNone, attr, tag) =




#=
HTML_TAGS = Set(["basefont", "figcaption", "rb", "ul", "data"
SVG_TAGS = Set(["solidcolor", "feBlend", "tspan", "feTile", "
HTML_ATTRS = Dict("basefont"=>["color", "face", "size"],"ul"=
SVG_ATTRS = Dict("glyph"=>["alignment-baseline", "arabic-form

HTML_ATTR_NAME = Dict(:for=>"for",:formaction=>"formaction",:
SVG_ATTR_NAME = Dict(:alignmentBaseline=>"alignment-baseline"
COMBINED_VOID_TAGS = Set(["param", "ellipse", "link", "hr", "
HTML_SVG_TAG_INTERSECTION_MD = "`audio`, `svg`, `a`, `canvas`
=#



# encode(x::UInt16, y::UInt16) = UInt32(x) << 16 + UInt32(y)
# decode(x::UInt32) = decode(UInt16(x>>16)), decode(UInt16(x&(typemax(UInt32)>>16)))


# @show COMBINED_ATTR_NAMES

# strings = union(COMBINED_TAGS, unique(values(COMBINED_ATTR_NAME)))
# codes = UInt16[1:length(strings)...]
# ENCODE = Dict(zip(strings, codes))
# DECODE = Dict(zip(codes, strings))

# encode(x::UInt16, y::UInt16) = UInt32(x) << 16 + UInt32(y)
# decode(x::UInt32) = decode(UInt16(x>>16)), decode(UInt16(x&(typemax(UInt32)>>16)))

# encode(x::String) = UInt16(ENCODE[x])
# decode(x::UInt16) = DECODE[x]

# encode(x::String, y::String) = encode(encode(x), encode(y))

# @show encode("hr")
# @show encode("hr") |> typeof
# @show decode(encode("hr"))

# @show encode("hr", "align")
# @show encode("hr", "align") |> typeof
# @show decode(encode("hr", "align"))

# keymap(f, d) = Dict(f(key) => value for (key, value) in pairs(d))

# for ATTRS in [COMBINED_ATTRS HTML_ATTRS SVG_ATTRS]
#     star = pop!(ATTRS, "*")
#     for val in values(ATTRS)
#         append!(val, star)
#     end
# end
# denormalize(d) = Set(encode(tag, attr) for (tag, attrs) in pairs(d) for attr in attrs)

# D_HTML_ATTRS     = denormalize(HTML_ATTRS)
# D_SVG_ATTRS      = denormalize(SVG_ATTRS)
# D_COMBINED_ATTRS = denormalize(COMBINED_ATTRS)
# @show length(D_COMBINED_ATTRS)

# # can we get rid of combined attrs and just check if svg || html?=#