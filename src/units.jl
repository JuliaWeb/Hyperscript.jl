# Fooling around. Does not work in the current state.

abstract type Unit{T<:Number} end

# convenient concise scalar * unit constructor, e.g. 5px
struct BareUnit{T} end
Base.:*(x::Number, ::BareUnit{T}) where {T} = Unit(x)

struct Unit{suffix, T} <: Unit{T}
    value::T
end
Base.show(io::IO, x::Unit{suffix}) where {suffix} = print(io, x.value, suffix)

const px = BareUnit{Unit}()


# macro unit(typ, shortname, suffix)
#     #=
#     struct Px{T} <: Unit{T}
#         value::T
#     end
#     const px = BareUnit{Px}()
#     baseunit(::Type{T}) where {T <: Px} = Px
#     Base.show(io::IO, x::Px) = print(io, x.value, "px")
#     =#
#     quote
#         struct $typ{T} <: Unit{T}
#             value::T
#         end
#         const $(esc(shortname)) = BareUnit{$typ}()
#         $(esc(:baseunit))(::Type{T}) where {T <: $typ} = $typ
#         Base.show(io::IO, x::$typ) = print(io, x.value, $suffix)
#     end
# end

# # common css units (ex, ch excluded)
# @unit Px px "px"
# @unit Em em "em"
# @unit Rem rem "rem"
# @unit Pc pc "%"
# @unit Vh vh "vh"
# @unit Vw vw "vw"
# @unit Vmin vmin "vmin"
# @unit Vmax vmax "vmax"

# scalar * unit
Base.:*(x::Number, y::U) where {U <: Unit} = baseunit(U)(x * y.value)

# diagonal dispatch for unit + unit
Base.:+(x::U, y::U) where {U <: Unit} = baseunit(U)(x.value + y.value)

# calc() expressions
struct Calc
    expr::String
    Calc(expr) = new("($expr)")
end
Base.show(io::IO, x::Calc) = print(io, "calc", x.expr)

# fallback to calc() for mismatched units
Base.:+(x::Unit,   y::Unit) = Calc("$x + $y")

# scalar * calc(), unit + calc(), calc + unit
Base.:*(x::Number, y::Calc) = Calc("$x * $(y.expr)")
Base.:+(x::Unit,   y::Calc) = Calc("$x + $(y.expr)")
Base.:+(x::Calc,   y::Unit) = Calc("$(x.expr) + $y")

# todo: division, substraction

# @show 1px, 2px, 1px + 2px
# @show 1px, 2em, 1px + 2em
# @show 5 * (1px + 2em)
# @show 3.2 * (4.3em + 1px + 3px)
