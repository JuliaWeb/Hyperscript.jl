struct Unit{S, T} # S = suffix symbol
    value::T
end
Unit{S}(value) where {S} = Unit{S, typeof(value)}(value)

Base.show(io::IO, x::Unit{S}) where {S} = print(io, x.value, S)

# diagonal dispatch for unit + unit, unit - unit
Base.:+(x::Unit{S}, y::Unit{S}) where {S} = Unit{S}(x.value + y.value)
Base.:-(x::Unit{S}, y::Unit{S}) where {S} = Unit{S}(x.value - y.value)

# scalar * unit, unit / scalar
Base.:*(x::Number, y::Unit{S}) where {S} = Unit{S}(x * y.value)
Base.:/(x::Unit{S}, y::Number) where {S} = Unit{S}(x.value / y)

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

# scalar * calc(), calc() / scalar
Base.:*(x::Number, y::Calc) = Calc("$x * $(y.expr)")
Base.:/(x::Calc, y::Number) = Calc("$(x.expr) / $y")

# concise scalar * unit construction, e.g. 5px
struct BareUnit{T} end
Base.:*(x::T, ::BareUnit{U}) where {U <: Unit, T<:Number} = U{T}(x)

# common css units (ex, ch excluded)
const px = BareUnit{Unit{:px}}()
const pt = BareUnit{Unit{:pt}}()
const em = BareUnit{Unit{:em}}()
const rem = BareUnit{Unit{:rem}}()
const vh = BareUnit{Unit{:vh}}()
const vw = BareUnit{Unit{:vw}}()
const vmin = BareUnit{Unit{:vmin}}()
const vmax = BareUnit{Unit{:vmax}}()
const pc = BareUnit{Unit{Symbol("%")}}()