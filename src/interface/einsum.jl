struct EinsumEagerStyle end
struct EinsumLazyStyle end
combine_style(::EinsumEagerStyle, ::EinsumEagerStyle) = EinsumEagerStyle()
combine_style(::EinsumLazyStyle, ::EinsumLazyStyle) = EinsumLazyStyle()
combine_style(::EinsumEagerStyle, ::EinsumLazyStyle) = EinsumLazyStyle()

einsum_style(arg) = EinsumEagerStyle()
einsum_style(::LazyTensor) = EinsumLazyStyle()

struct EinsumTensor{Style, Arg <: LazyTensor}
    style::Style
    arg::Arg
end

einsum_tensor(tns) = EinsumTensor(einsum_style(tns), lazy(tns))

struct EinsumArgument{T, Style}
    style::Style
    data::LogicNode
    extrude::Dict{Symbol, Bool}
    default::T
end

EinsumArgument{T}(style::Style, data, extrude, default) where {T, Style} = EinsumArgument{T, Style}(style, data, extrude, default)

Base.eltype(::EinsumArgument{T}) where {T} = T

einsum_access(tns::EinsumTensor, idxs...) = EinsumArgument{eltype(tns.arg)}(
    tns.style,
    relabel(tns.arg.data, map(field, idxs)...),
    Dict(idx => idx_extrude for (idx, idx_extrude) in zip(idxs, tns.arg.extrude)),
    tns.arg.default
)

einsum_op(op, args::EinsumArgument...) = EinsumArgument{combine_eltypes(op, args)}(
    result_style((arg.style for arg in args)...),
    mapjoin(op, (arg.data for arg in args)...),
    mergewith(&, (arg.extrude for arg in args)...),
    op((arg.default for arg in args)...)
)

einsum_immediate(val) = EinsumArgument{typeof(val)}(EinsumEagerStyle(), immediate(val), Dict(), val)

struct EinsumProgram{Style, Arg <: LazyTensor}
    style::Style
    arg::Arg
end

function einsum(::typeof(overwrite), arg::EinsumArgument{T}, idxs...; init = nothing) where {T}
    einsum(initwrite(arg.default), arg, idxs...; init=arg.default)
end

function einsum(op, arg::EinsumArgument{T}, idxs...; init = initial_value(op, T)) where {T}
    extrude = ntuple(n -> arg.extrude[idxs[n]], length(idxs))
    data = reorder(aggregate(immediate(op), immediate(init), arg.data, map(field, setdiff(collect(keys(arg.extrude)), idxs))...), map(field, idxs)...)
    einsum_execute(arg.style, LazyTensor{typeof(init)}(data, extrude, init))
end

function einsum_execute(::EinsumEagerStyle, arg)
    compute(arg)
end

function einsum_execute(::EinsumLazyStyle, arg)
    arg
end

struct EinsumArgumentParserVisitor
    preamble
    space
    output
    inputs
end

function (ctx::EinsumArgumentParserVisitor)(ex)
    if @capture ex :ref(~tns, ~idxs...)
        tns isa Symbol || ArgumentError("Einsum expressions must reference named tensor Symbols.")
        tns != ctx.output || ArgumentError("Einsum expressions must not reference the output tensor.")
        for idx in idxs
            idx isa Symbol || ArgumentError("Einsum expressions must use named index Symbols.")
        end
        my_tns = get!(ctx.inputs, tns) do
            res = freshen(ctx.space, tns)
            push!(ctx.preamble.args, :($res = $einsum_tensor($(esc(tns)))))
            res
        end
        return :($einsum_access($my_tns, $(map(QuoteNode, idxs)...)))
    elseif @capture ex :tuple(~args...)
        return ctx(:(tuple($(args...))))
    elseif @capture ex :comparison(~a, ~cmp, ~b)
        return ctx(:($cmp($a, $b)))
    elseif @capture ex :comparison(~a, ~cmp, ~b, ~tail...)
        return ctx(:($cmp($a, $b) && $(Expr(:comparison, b, tail...))))
    elseif @capture ex :&&(~a, ~b)
        return ctx(:($and($a, $b)))
    elseif @capture ex :||(~a, ~b)
        return ctx(:($or($a, $b)))
    elseif @capture ex :call(~op, ~args...)
        return :($einsum_op($(esc(op)), $(map(ctx, args)...)))
    elseif ex isa Expr
        throw(FinchSyntaxError("Invalid einsum expression: $ex"))
    else
        return :($einsum_immediate($ex))
    end
end

struct EinsumParserVisitor
    preamble
    space
end

function (ctx::EinsumParserVisitor)(ex)
    if ex isa Expr
        if (@capture ex (~op)(~lhs, ~rhs)) && haskey(incs, op)
            return ctx(:($lhs << $(incs[op]) >>= $rhs))
        elseif @capture ex :(=)(~lhs, ~rhs)
            return ctx(:($lhs << $overwrite >>= $rhs))
        elseif @capture ex :>>=(:call(:<<, :ref(~tns, ~idxs...), ~op), ~rhs)
            tns isa Symbol || ArgumentError("Einsum expressions must reference named tensor Symbols.")
            for idx in idxs
                idx isa Symbol || ArgumentError("Einsum expressions must use named index Symbols.")
            end
            arg = EinsumArgumentParserVisitor(ctx.preamble, ctx.space, tns, Dict())(rhs)
            quote
                $(esc(tns)) = $einsum($(esc(op)), $arg, $(map(QuoteNode, idxs)...))
            end
        else
            throw(FinchSyntaxError("Invalid einsum expression: $ex"))
        end
    else
        throw(FinchSyntaxError("Invalid einsum expression type: $ex"))
    end
end

"""
    @einsum tns[idxs...] <<op>>= ex...

Construct an einsum expression that computes the result of applying `op` to the
tensor `tns` with the indices `idxs` and the tensors in the expression `ex`.
The result is stored in the variable `tns`.

`ex` may be any pointwise expression consisting of function calls and tensor
references of the form `tns[idxs...]`, where `tns` and `idxs` are symbols.

The `<<op>>` operator can be any binary operator that is defined on the element
type of the expression `ex`.

The einsum will evaluate the pointwise expression `tns[idxs...] <<op>>= ex...`
over all combinations of index values in `tns` and the tensors in `ex`.

Here are a few examples:
```
@einsum C[i, j] += A[i, k] * B[k, j]
@einsum C[i, j, k] += A[i, j] * B[j, k]
@einsum D[i, k] += X[i, j] * Y[j, k]
@einsum J[i, j] = H[i, j] * I[i, j]
@einsum N[i, j] = K[i, k] * L[k, j] - M[i, j]
@einsum R[i, j] <<max>>= P[i, k] + Q[k, j]
```
"""
macro einsum(ex)
    preamble = Expr(:block)
    space = Namespace()
    res = EinsumParserVisitor(preamble, space)(ex)
    quote
        $preamble
        $res
    end
end