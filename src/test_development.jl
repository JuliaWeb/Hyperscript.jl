using Hyperscript
using Test

macro errors(expr)
    quote
        @test_throws ErrorException $expr
    end
end


## Tags
# Can render tags
@show m("p")
# Tags can be <: AbstractString
@show m(SubString("xspan", 2))
# Tags *must* be <: AbstractString
@test_throws MethodError m(1)
@test_throws MethodError m('1')
@test_throws MethodError m(1.0)

## Attributes
# Can render a tag with an attribute
@show m("p", name="value")
# Can render a tag with multiple attributes
@show m("p", name="value", nameTwo="valueTwo")
# Render tags with various non-string attribute values
@show m("p", name='7')
@show m("p", name=7)
@show m("p", name=7.0)
# Squishcase renders as squishcase
@show m("p"; squishname=7.0)
# cameCase renders as kebab-case
@show m("p"; camelName=7.0)
# kebab-case renders as kebab-case
@show m("p"; [Symbol("kebab-name") => 7]...)
# Can start attribute names with numbers
@show m("p"; [Symbol("7-name") => 7]...)
# We prevent NaN attribute values by default
@errors m("p", name=NaN)
# We prevent spaces in attribute names by default
@errors m("p"; [Symbol("7 space name") => 7]...)
# Passing a string as an attribute name preserves it un-normalized
@show Hyperscript.Node(Hyperscript.DEFAULT_DOM_CONTEXT, "p", [], ["camelName" => 7.0])

## Children
# Can render children
@show m("p", "child")
# Can render multiple children
@show m("p", "childOne", "childTwo")
# Can render multiply-typed children
@show m("p", "childOne", 2)
# Can render Node children
m("p", m("p"))
# Can render other non-String children
@show m("p", 1)
@show m("p", '1')
@show m("p", 1.0)
# Can render nodes with mixed-type children
@show m("p", m("span", "child", 1), 2)
# Can render mixed-type children inside an array
@show m("p", [m("span", "child", 1), 2])

## Generators, arrays, and tuples
# Arrays are flattened
@show m("p", [1, 2, 3])
# Generators are flattened
@show m("p", (x for x in 1:3))
# Tuples are flattened
@show m("p", (1, 2, 3))
# Ranges are not flattened
@show m("p", 1:3)

## Normalization of HTML- and SVG-specific attribute nanes
# we don't normalize tag names
@show m("linearGradient")
@show m("magicLinearGradient")
# for those special attributes we preserve camelCase
@show m("path", pathLength=7)
# for those special attributes we convert squishcase
@show m("path", pathlength=7)
# for those special attributes you can still bypass HTML normalization (but not validation)
# by sending the value in as a String
@show Hyperscript.Node(Hyperscript.DEFAULT_DOM_CONTEXT, "path", [], ["pathlength" => 7])
@show Hyperscript.Node(Hyperscript.DEFAULT_DOM_CONTEXT, "path", [], ["path-length" => 7])

# Void tags render as void tags
@show m("br")
@show m("stop")
# void tags are not allowed to have children
@errors m("stop", "child")

# Non-void tags render as non-void tags
@show m("div")
@show m("span")

# @tags
@tags beep
# The @tags macro declares a tag
beep("hello<")

# @tags_noescape
@tags_noescape boop
# The @tags_noescape macro declares a tag with unescaped children
boop("hello<")

# escape behavior
# HTML-relevant characters are escaped
@show m("p", "<")
@show m("p", "\"")
# Non-HTML Non-ASCII characters are not escaped; we assume a utf-8 charset
@show m("p", "—")
# Regular characters are not escaped
@show m("p", "x")
# Characters are escaped inside attribute names
@show m("p", attr="<value")
# This is weird.
# @show m("p"; [Symbol("<attr")=>"<value"]...)

# noescape behavior
@tags_noescape q
@show q("<")
@show q("—")
@show q("\"")
@show q("x")
# Noescape only applies to the contents of immediate children
# as that is the most useful behavior
@show q(attr="<value", "<")

# Node application
const p = m("p")
p("child")
p(attr="value")

const pstuff = m("p", attr="valueOne", "childOne")
pstuff("childTwo")
pstuff(attrTwo="valueTwo")

# New attributes are added
pstuff(attrTwo="valueTwo")
# New children are added
pstuff("childTwo")
# Existing attributes override
pstuff(attr="valueTwo")

# Dot syntax for class attributes
@show m("p").a
# Dot syntax desugars to kebab-case
@show m("p").fooBar
# Dot syntax with a String survives attribute name-mangling
@show m("p")."fooBar"
# Dot syntax with a String can add multiple classes
@show m("p")."fooBar baz"
# Regular class attribute combined with dot syntax
@show m("p", class="a").b
# Dot syntax with regular class specification as an override
@show m("p", class="a")(class="b")

# No class attribute override for CSS nodes
@errors css("p").a

# todo: tests for CSS
# todo: tests for Styled
