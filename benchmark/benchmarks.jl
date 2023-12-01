#!/usr/bin/env julia

using Hyperscript
using Markdown, BenchmarkTools
using Plots

default(size=(800, 400))


# Define a parent BenchmarkGroup to contain the suite
suite = BenchmarkGroup()


@tags span h1 p
@tags_noescape script style
const entry = span.entry

# Create a scoped `Style` object
s1 = Style(css("p", fontWeight="bold"), css("span", color="red"))

# Create a second scoped style
s2 = Style(css("p", color="blue"))


suite["HTML"] = BenchmarkGroup()
suite["HTML"]["empty node"] = @benchmarkable begin
    m("span")
end
suite["HTML"]["single attribute"] = @benchmarkable begin
    m("span", class="entry")
end
suite["HTML"]["single string child"] = @benchmarkable begin
    m("span", "An Important Announcement")
end
suite["HTML"]["single node child"] = @benchmarkable begin
    m("span", m("h1"))
end
suite["HTML"]["each"] = @benchmarkable begin
    m("span", class="entry", m("h1"))
end
suite["HTML"]["each template"] = @benchmarkable begin
    span(class="entry", h1)
end
suite["HTML"]["each template dot"] = @benchmarkable begin
    span.entry(h1)
end
suite["HTML"]["each template entry"] = @benchmarkable begin
    entry(h1)
end
suite["HTML"]["each template dot chained"] = @benchmarkable begin
    span.header.entry(h1)
end
suite["HTML"]["flatten vector"] = @benchmarkable begin
    span(entry.(["$n Fast $n Furious" for n in 1:10])) # joke © Glen Chiacchieri
end
suite["HTML"]["flatten generator"] = @benchmarkable begin
    span(entry.("$n Fast $n Furious" for n in 1:10)) # joke © Glen Chiacchieri
end
suite["HTML"]["flatten tuple"] = @benchmarkable begin
    span(entry.(tuple("$n Fast $n Furious" for n in 1:10))) # joke © Glen Chiacchieri
end
suite["HTML"]["hyphens attributes"] = @benchmarkable begin
    m("meta", httpEquiv="refresh")
    # turns into <meta http-equiv="refresh" />
end
suite["HTML"]["camelCase attributes"] = @benchmarkable begin
    m("svg", viewBox="0 0 100 100")
    # turns into <svg viewBox="0 0 100 100"><svg>
end
suite["HTML"]["keyword attributes"] = @benchmarkable begin
    m("input"; :type => "text")
    # turns into <input type="text" />
end
suite["HTML"]["HTML-escape"] = @benchmarkable begin
    m("p", "I am a paragraph with a < inside it")
    # turns into <p>I am a paragraph with a &#60; inside it</p>
end
suite["HTML"]["HTML-noescape"] = @benchmarkable begin
    script("console.log('<(0_0<) <(0_0)> (>0_0)> KIRBY DANCE')")
end
suite["HTML"]["pretty printing"] = @benchmarkable begin
    Pretty(m("span", class="entry", m("h1", "An Important Announcement")))
    # <span class="entry">
    #  <h1>An Important Announcement</h1>
    # </span>
end


suite["CSS"] = BenchmarkGroup()
suite["CSS"]["css function"] = @benchmarkable begin
    css(".entry", fontSize="14px")
    # turns into .entry { font-size: 14px; }
end
suite["CSS"]["nested styles"] = @benchmarkable begin
    css(".entry",
        fontSize="14px",
        css("h1", textDecoration="underline"),
        css("> p", color="#999"))
    # turns into
    # .entry { font-size: 14px; }
    # .entry h1 { text-decoration: underline; }
    # .entry > p { color: #999; }
end
suite["CSS"]["@media query"] = @benchmarkable begin
    css("@media (min-width: 1024px)",
        css("p", color="red"))
    # turns into
    # @media (min-width: 1024px) {
    #   p { color: red; }
    # }
end


suite["Scoped Styles"] = BenchmarkGroup()
suite["Scoped Styles"]["scoped style dom"] = @benchmarkable begin
    # Apply the style to a DOM node
    s1(p("hello"))
    # turns into <p v-style1>hello</p>
end
suite["Scoped Styles"]["scoped style tag"] = @benchmarkable begin
    # Insert the corresponding styles into a <style> tag
    style(styles(s1))
    # turns into
    # <style>
    #   p[v-style1] {font-weight: bold;}
    #   span[v-style1] {color: red;}
    # </style>
end
suite["Scoped Styles"]["barrier style dom"] = @benchmarkable begin
    # Apply `s1` to the parent and `s2` to a child.
    # Note the `s1` style does not apply to the child styled with `s2`.
    s1(p(p("outer"), s2(p("inner"))))
    # turns into
    # <p v-style1>
    #   <p v-style1>outer</p>
    #   <p v-style2>inner</p>
    # </p>
end
suite["Scoped Styles"]["barrier style tag"] = @benchmarkable begin
    style(styles(s1), styles(s2))
    # turns into
    # <style>
    #   p[v-style1] {font-weight: bold;}
    #   span[v-style1] {color: red;}
    #   p[v-style2] {color: blue;}
    # </style>
end


suite["CSS Units"] = BenchmarkGroup()
suite["CSS Units"]["no arithmetic"] = @benchmarkable begin
    css(".foo", width=50px)
    # turns into .foo {width: 50px;}
end
suite["CSS Units"]["arithmetic same units"] = @benchmarkable begin
    css(".foo", width=50px + 2 * 100px)
    # turns into .foo {width: 250px;}
end
suite["CSS Units"]["arithmetic diff. units"] = @benchmarkable begin
    css(".foo", width=(50px + 50px) + 2em)
    # turns into .foo {width: calc(100px + 2em);}
end


# If a cache of tuned parameters already exists, use it, otherwise, tune and cache
# the benchmark parameters. Reusing cached parameters is faster and more reliable
# than re-tuning `suite` every time the file is included.
paramspath = joinpath(dirname(@__FILE__), "params.json")
if isfile(paramspath)
    loadparams!(suite, BenchmarkTools.load(paramspath)[1], :evals);
else
    tune!(suite)
    BenchmarkTools.save(paramspath, params(suite));
end


# Generate a simple HTML report of the benchmarks.
# Usage: savereport(run(suite))
function savereport(results, path=joinpath(dirname(@__FILE__), "report.html"))
    p(k) = bar(
        collect(keys(results[k])),
        (x -> minimum(x).time).(values(results[k])),
        xticks=:all,
        xrotation=25,
        yscale=:log10,
        ylabel="min. time (ns)",
        # title=k,
        label=:none,
    )

    report = m("html",
        m("head", m("title", "Benchmarks")),
        m("body", style="text-align: center",
            m("h1", "Benchmarks"),
            m("h2", "HTML"), p("HTML"),
            m("h2", "CSS"), p("CSS"),
            m("h2", "CSS Units"), p("CSS Units"),
            m("h2", "Scoped Styles"), p("Scoped Styles"),
        ),
    )

    open(path, "w") do io
        print(io, "<!DOCTYPE html>")
        show(io, "text/html", report)
    end
end
