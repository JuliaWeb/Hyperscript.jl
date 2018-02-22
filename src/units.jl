struct Unit{S, T} # S = suffix symbol
    value::T
end
Unit{S}(value) where {S} = Unit{S, typeof(value)}(value)

Base.show(io::IO, x::Unit{S}) where {S} = print(io, x.value, S)

# concise scalar * unit construction, e.g. 5px
struct BareUnit{T} end
Base.:*(x::T, ::BareUnit{U}) where {U <: Unit, T<:Number} = U{T}(x)

# diagonal dispatch for unit + unit and unit - unit
Base.:+(x::Unit{S}, y::Unit{S}) where {S} = Unit{S}(x.value + y.value)
Base.:-(x::Unit{S}, y::Unit{S}) where {S} = Unit{S}(x.value - y.value)

# scalar * unit and unit / scalar
Base.:*(x::Number, y::U) where {U <: Unit} = U(x + y.value)
Base.:/(x::U, y::Number) where {U <: Unit} = U(x.value / y)

# calc() expressions
struct Calc
    expr::String
    Calc(expr) = new("($expr)")
end
Base.show(io::IO, x::Calc) = print(io, "calc", x.expr)

# default to calc() for mismatched units
Base.:+(x::Unit,   y::Unit) = Calc("$x + $y")
Base.:-(x::Unit,   y::Unit) = Calc("$x - $y")

# unit + calc(), calc() + unit
Base.:+(x::Unit,   y::Calc) = Calc("$x + $(y.expr)")
Base.:+(x::Calc,   y::Unit) = Calc("$(x.expr) + $y")

# unit - calc(), calc() - unit,
Base.:-(x::Unit,   y::Calc) = Calc("$x - $(y.expr)")
Base.:-(x::Calc,   y::Unit) = Calc("$(x.expr) - $y")

# scalar * calc(), scalar / calc()
Base.:*(x::Number, y::Calc) = Calc("$x * $(y.expr)")
Base.:/(x::Calc, y::Number) = Calc("$(x.expr) / $y")

# common css units (ex, ch excluded)
const px = BareUnit{Unit{:px}}()
const em = BareUnit{Unit{:em}}()
const rem = BareUnit{Unit{:rem}}()
const vh = BareUnit{Unit{:vh}}()
const vw = BareUnit{Unit{:vw}}()
const vmin = BareUnit{Unit{:vmin}}()
const vmax = BareUnit{Unit{:vmax}}()
const pc = BareUnit{Unit{Symbol("%")}}()

# @show 5px

# @show 2px + 2px
# @show 2px + 2.0px

# @show 5 * 2px
# @show 5 * 2.0px
# @show 5.0 * 2px

# @show 5 * (1px + 2em)
# @show 3.2 * (4.3em + 1px + 3px)

