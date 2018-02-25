using Hyperscript
using Test

macro test_renders(x, s)
    quote
        Hyperscript.render($x) == $s
    end
end

# plain tag
@test_renders m("circle") "<circle />"

# tag with attribute
@test_renders m("circle", cx=1) "<circle cx=\"1\" />"

# dot syntax for class attribute
@test_renders m("circle").foo "<circle class=\"foo\" />"

# dot syntax for multiple class attributes
@test_renders m("circle").foo.bar "<circle class=\"foo bar\" />"

# dot syntax combined with regular class specification
@test_renders m("circle", class="moo").foo.bar "<circle class=\"moo foo bar\" />"

# dot syntax with regular class specification as an override
@test_renders m("circle", class="moo").foo(class="bar") "<circle class=\"bar\" />"

# nan attribute value
@test_throws ErrorException m("circle", cx=NaN)

