import Hyperscript
import Hyperscript: m, m_html, m_svg, m_novalidate
using Test

#=
    tests validation errors
        - HTML
        - SVG
        - Combined

    types of errors
        - nan value
        - invalid tag name
        - invalid attribute name in general
        - invalid attribute name for the specific tag

=#

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

# invalid tag name
@test_throws ErrorException m("smirkle")

# enforce the lowercase idiom as an error
@test_throws ErrorException m("Circle")

# disallow SVG tags in HTML validation mode
@test_throws ErrorException m_html("circle")

# disallow HTML tags in SVG validation mode
@test_throws ErrorException m_svg("div")

# allow all tags with no validation mode
@test_html_eq m_novalidate("smirkle") "<smirkle />"

# allow all attributes with no validation mode
@test_html_eq m_novalidate("div", mood="facetious") "<div mood=\"facetious\" />"

# invalid attribute name in general
@test_throws ErrorException m("circle", snoopy=1)

# invalid attribute name for the specific tag
@test_throws ErrorException m("circle", x=1)

