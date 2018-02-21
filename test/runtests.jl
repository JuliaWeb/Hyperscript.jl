using Hyperscript
using Test

macro test_html_eq(x, s)
    quote
        Hyperscript.render($x) == $s
    end
end

# plain tag
@test_html_eq m("circle") "<circle />"

# tag with attribute
@test_html_eq m("circle", cx=1) "<circle cx=\"1\" />"

# dot syntax for class attribute
@test_html_eq m("circle").foo "<circle class=\"foo\" />"

# dot syntax for multiple class attributes
@test_html_eq m("circle").foo.bar "<circle class=\"foo bar\" />"

# dot syntax combined with regular class specification
@test_html_eq m("circle", class="moo").foo.bar "<circle class=\"moo foo bar\" />"

# dot syntax with regular class specification as an override
@test_html_eq m("circle", class="moo").foo(class="bar") "<circle class=\"bar\" />"

# nan value
@test_throws ErrorException m("circle", cx=NaN)

