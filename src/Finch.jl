module Finch

using SyntaxInterface
using RewriteTools
using RewriteTools.Rewriters
using MacroTools
using DataStructures
using Base.Iterators
using Base: @kwdef

export @index

export Fiber, HollowList, HollowHash, HollowCoo, Solid, Element, FiberArray

include("util.jl")

include("semantics.jl")
include("IndexNotation/IndexNotation.jl")
using .IndexNotation
include("virtualize.jl")
include("style.jl")
include("transform_ssa.jl")
include("dimensionalize.jl")
include("lower.jl")
include("annihilate.jl")
include("chunks.jl")
include("runs.jl")
include("spikes.jl")
include("cases.jl")
include("steppers.jl")
include("jumpers.jl")
include("phases.jl")
include("execute.jl")
include("virtual_abstractarray.jl")
include("fibers.jl")
include("hollowlistlevels.jl")
include("hollowhashlevels.jl")
include("hollowcoolevels.jl")
include("solidlevels.jl")
include("elementlevels.jl")

end