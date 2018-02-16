include("Hyperscript2.jl")

camels = [
    "onehump"
    "1hump"
    "123hump"
    "1Hump"
    "hump1h2"
    "hump1H2"
    "twoHumps"
    "threeHumpCamel"
    "sixHUMPCamel"
    "already-kebab"
    "--css-var"
    "InitialCaps"
    "FinalCapS"
    "ends-with-dash-"
]

# treats numbers like caps so that data9 -> data-9.

for camel in camels
    println(camel, " => ", kebab(camel))
end

