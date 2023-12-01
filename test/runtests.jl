using Hyperscript
using Test

macro errors(expr)
    quote
        @test_throws ErrorException $expr
    end
end

macro renders(x, s)
    quote
        @test Hyperscript.render($x) == $s
    end
end

# Convenience macro for strings with embedded double-quotes
macro s_cmd(x)
    x
end

## Tags
# Can render tags
@renders m("p") "<p></p>"
# Cannot render nonempty tags
@errors m("")
# Tags can be <: AbstractString
@renders m(SubString("xspan", 2)) "<span></span>"
# Tags *must* be <: AbstractString
@test_throws MethodError m(1)
@test_throws MethodError m('1')
@test_throws MethodError m(1.0)
# Tags are normalized to strip whitespace
@test m("p") == m("p")
@test m(" p ") == m("p")
@test m("\tp\t") == m("p")

## Attributes
# Can render a tag with an attribute
@renders m("p", name="value") "<p name=\"value\"></p>"
# Can render a tag with multiple attributes
@test let x = string(m("p", a="x", b="y"))
    # Account for the two possible attribute orderings
    x == s`<p a="x" b="y"></p>` || x == s`<p b="y" a="x"></p>`
end
# Render tags with various non-string attribute values
@renders m("p", name='7') s`<p name="7"></p>`
@renders m("p", name=7) s`<p name="7"></p>`
@renders m("p", name=7.0) s`<p name="7.0"></p>`
# squishcase renders as squishcase
@renders m("p"; squishname=7.0) s`<p squishname="7.0"></p>`
# camelCase renders as kebab-case
@renders m("p"; camelName=7.0) s`<p camel-name="7.0"></p>`
# kebab-case renders as kebab-case
@renders m("p"; [Symbol("kebab-name") => 7]...) s`<p kebab-name="7"></p>`
# Can start attribute names with numbers
@renders m("p"; [Symbol("7-name") => 7]...) s`<p 7-name="7"></p>`

# Disallow NaN attribute values by default
@errors m("p", name=NaN)
# Disallow spaces in attribute names by default
@errors m("p"; [Symbol("7 space name") => 7]...)

# Passing a string as an attribute name preserves it un-normalized
@renders Hyperscript.Node(Hyperscript.DEFAULT_HTMLSVG_CONTEXT, "p", [], ["camelName" => 7.0]) s`<p camelName="7.0"></p>`

# Support boolean values for boolean attributes
@renders m("input", type="checkbox", checked=true) s`<input checked="" type="checkbox" />`
@renders m("input", type="checkbox", checked=false) s`<input type="checkbox" />`
# @errors m("input", type="checkbox", checked="true")
@renders m("input", type="text", value=true) s`<input value="true" type="text" />`

## Children
# Can render children
@renders m("p", "child") s`<p>child</p>`
# Can render multiple children
@renders m("p", "childOne", "childTwo") s`<p>childOnechildTwo</p>`

# Can render multiply-typed children
@renders m("p", "childOne", 2) s`<p>childOne2</p>`
# Can render Node children
@renders m("p", m("p")) s`<p><p></p></p>`
# Can render other non-String children
@renders m("p", 1) s`<p>1</p>`
@renders m("p", 1.0) s`<p>1.0</p>`
@renders m("p", '1') s`<p>1</p>`
# Can render nodes with mixed-type children
@renders m("p", m("span", "child", 1), 2) s`<p><span>child1</span>2</p>`
# Can render mixed-type children inside an array
@renders m("p", [m("span", "child", 1), 2]) s`<p><span>child1</span>2</p>`

## Accessors
@test Hyperscript.tag(m("p")) == "p"
@test Hyperscript.attrs(m("p", attr="value")) == Dict{String,Any}("attr" => "value")
@test Hyperscript.children(m("p", "child")) == Any["child"]

## Generators, arrays, and tuples
# Arrays are flattened
@renders m("p", [1, 2, 3]) s`<p>123</p>`
# AbstractArrays are flattened
@renders m("p", BitArray([0, 1, 0])) s`<p>falsetruefalse</p>`
# Generators are flattened
@renders m("p", (x for x in 1:3)) s`<p>123</p>`
# Tuples are flattened
@renders m("p", (1, 2, 3)) s`<p>123</p>`
# Ranges are not flattened
@renders m("p", 1:3) s`<p>1:3</p>`

## Normalization of HTML- and SVG-specific attribute nanes
# we don't normalize tag names
@renders m("linearGradient") s`<linearGradient></linearGradient>`
@renders m("magicLinearGradient") s`<magicLinearGradient></magicLinearGradient>`
# for those special attributes we preserve camelCase
@renders m("path", pathLength=7) s`<path pathLength="7" />`
# for those special attributes we convert squishcase
@renders m("path", pathlength=7) s`<path pathLength="7" />`
# for those special attributes you can still bypass HTML normalization (but not validation)
# by sending the value in as a String
@renders Hyperscript.Node(Hyperscript.DEFAULT_HTMLSVG_CONTEXT, "path", [], ["pathlength" => 7]) s`<path pathlength="7" />`
@renders Hyperscript.Node(Hyperscript.DEFAULT_HTMLSVG_CONTEXT, "path", [], ["path-length" => 7]) s`<path path-length="7" />`

# Void tags render as void tags
@renders m("br") s`<br />`
@renders m("stop") s`<stop />`
# Void tags are not allowed to have children
@errors m("stop", "child")

# Non-void tags render as non-void tags
@renders m("div") s`<div></div>`
@renders m("span") s`<span></span>`

# @tags
@tags beep
# The @tags macro declares a tag
@renders beep("hello<") s`<beep>hello&#60;</beep>`

# @tags_noescape
@tags_noescape boop
# The @tags_noescape macro declares a tag with unescaped children
@renders boop("hello<") s`<boop>hello<</boop>`


# escape behavior
# HTML-relevant characters are escaped
@renders m("p", "<") s`<p>&#60;</p>`
@renders m("p", "\"") s`<p>&#34;</p>`
# Non-HTML Non-ASCII characters are not escaped; we assume a utf-8 charset
@renders m("p", "—") s`<p>—</p>`
# Regular characters are not escaped
@renders m("p", "x") s`<p>x</p>`
# Characters are escaped inside attribute names
@renders m("p", attr="<value") s`<p attr="&#60;value"></p>`
# This is weird. Should we allow it?
# m("p"; [Symbol("<attr")=>"<value"]...)

# noescape behavior
@tags_noescape q
@renders q("<") s`<q><</q>`
@renders q("—") s`<q>—</q>`
@renders q("\"") s`<q>"</q>`
@renders q("x") s`<q>x</q>`
# Noescape does not propagate and only applies to children, not attributes.
# This is the most useful behavior — you only really want to not-escape the
# contents of e.g. of<script> and <style> tags
@renders q(attr="<value", "<") s`<q attr="&#60;value"><</q>`
@renders q(m("p", "<")) "<q><p>&#60;</p></q>"


# Node application
const p = m("p")
@renders p("child") s`<p>child</p>`
@renders p(attr="value") s`<p attr="value"></p>`

const pstuff = m("p", attr="valueOne", "childOne")
# Children in node application append to existing children
@renders pstuff("childTwo") s`<p attr="valueOne">childOnechildTwo</p>`
# Attributes in node application add to existing attributes
@test let x = string(pstuff(attrTwo="valueTwo"))
    # Account for the two possible attribute orderings
    x == s`<p attr-two="valueTwo" attr="valueOne">childOne</p>` ||
        x == s`<p attr="valueOne" attr-two="valueTwo">childOne</p>`
end
# New values for attributes in node application override existing values
@renders pstuff(attr="valueTwo") s`<p attr="valueTwo">childOne</p>`

# Dot syntax for class attributes
@renders m("p").a s`<p class="a"></p>`
# Dot syntax desugars to kebab-case
@renders m("p").fooBar s`<p class="foo-bar"></p>`
# Dot syntax with a String survives kebab normalization
@renders m("p")."fooBar" s`<p class="fooBar"></p>`
# Dot syntax with a String can add multiple classes
@renders m("p")."fooBar baz" s`<p class="fooBar baz"></p>`
# Regular class attribute combined with dot syntax
@renders m("p", class="a").b s`<p class="a b"></p>`
# Dot syntax with regular class specification as an override
@renders m("p", class="a")(class="b") s`<p class="b"></p>`

## CSS nodes
# Tags must be strings
@renders css("p") s`p {}`
@test_throws MethodError css(7)

# No class attribute override for CSS nodes
@errors css("p").a
# empty rules are allowed
@renders css("p") s`p {}`
# empty tags are disallowed
@errors css("")
# attributes render inside nodes
@renders css("p", color="red") s`p {color: red;}`
# NaN attributes are disallowed
@errors css("p", color=NaN)
# empty attributes are disallowed
@errors css("p", color="")
# child nodes render flattened
@renders css("p", css("q", color="blue")) s`p {}p q {color: blue;}`
# child nodes of @media nodes render nested
@renders css("@media (min-width: 1024px)", css("p", color="red")) s`@media (min-width: 1024px) {p {color: red;}}`
# camelCase renders as kebab-case
@renders css("p", fontSize="12px") s`p {font-size: 12px;}`


# Tags are normalized to strip whitespace
@test css(" p ") == css("p")
@test css("\tp\t") == css("p")

# Media tags are recognized
@test Hyperscript.ismedia(css("@media (min-width: 700px)"))
# Non-media tags are not recognized as media tags
@test !Hyperscript.ismedia(css("p"))

# CSS children can be CSS nodes
@renders css("p", css("q")) s`p {}p q {}`
# CSS children cannot be non-CSS nodes
@errors css("p", m("p"))

# CSS tags are not escaped
@renders css("p <") s`p < {}`
# CSS attribute names are not escaped
@renders css("p"; [Symbol("attr<") => "<"]...) s`p {attr-<: <;}`
# CSS attribute values are not escaped
@renders css("p", attr="value<") s`p {attr: value<;}`

# todo: test a css node with an attribute that autoprefixes into multiple attributes.
# We currently don't do antoprefixing so there is no way to test the capability
# short of creating our own node type.

## `Style`s and `StyledNode`s
# `Style`s can be created
s1 = Style(css("p", color="red"))
# `Style`s can be created from multiple CSS rules
s2 = Style(css("p", color="red"), css("span", color="blue"))

# `Style` styles can be accessed via `styles`
@tags_noescape style
style(styles(s1)) == s`<style>p[v-style1] {color: red;}</style>`

# The tag, children, and attrs functions for `Styled` nodes are defined
# and return the right things
@test Hyperscript.tag(s1(m("p"))) == "p"
@test Hyperscript.children(s1(m("p"))) == Any[]
@test Hyperscript.attrs(s1(m("p"))) == Dict{String,Any}(["v-style1" => nothing])

# Applied styles label children with a v-style
@renders s1(m("p")) s`<p v-style1></p>`
# Applied styles label children recursively
@renders s1(m("p", m("p"))) s`<p v-style1><p v-style1></p></p>`
# Applied styles do not propagate to `Styled` children
@renders s1(m("p", s2(m("p")))) s`<p v-style1><p v-style2></p></p>`
# Applying a styled node to a new node styles those new children
@renders s1(m("p"))(m("span")) s`<p v-style1><span v-style1></span></p>`
# Applying a styled node to a non-Node continues to work as usual
@renders s1(m("p"))("string") s`<p v-style1>string</p>`
# Applying a styled node to a Styled child preserves the child's style attribute
@renders s1(m("p"))(s2(m("p"))) s`<p v-style1><p v-style2></p></p>`

## CSS Units
import Hyperscript: px, em
@test string(5px) == "5px"
@test string(2px + 2px) == "4px"
@test string(2px + 2.0px) == "4.0px"
@test string(2.0px + 2px) == "4.0px"
@test string(5 * 2px) == "10px"
@test string(5 * 2.0px) == "10.0px"
@test string(5.0 * 2px) == "10.0px"
@test string(5 * (1px + 2em)) == "calc(5 * (1px + 2em))"
@test string(5 * (1px + 3px + 4.3em)) == "calc(5 * (4px + 4.3em))"
@test string(3.2 * (4.3em + 1px + 3px)) == "calc(3.2 * ((4.3em + 1px) + 3px))"

# IOContext passthrough.
struct MyType
end
Base.show(io::IO, ::MIME"text/html", ::MyType) = print(io, get(io, :key, ""))

let
    io = IOBuffer()
    show(io, MIME("text/html"), m("div")(MyType()))
    @test String(take!(io)) == "<div></div>"

    ctx = IOContext(io, :key => "value")
    show(ctx, MIME("text/html"), m("div")(MyType()))
    @test String(take!(io)) == "<div>value</div>"
end
