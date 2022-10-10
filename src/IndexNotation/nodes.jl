tab = "  "

abstract type IndexNode end
abstract type IndexStatement <: IndexNode end
abstract type IndexExpression <: IndexNode end
abstract type IndexTerminal <: IndexExpression end

@enum CINHead begin
    value=1
    virtual=2
    name=3
    literal=4
    with=5
    access=6
    call=7
    loop=8
    chunk=9
    sieve=10
    assign=11
    pass=12
end

struct CINNode <: IndexNode
    kind::CINHead
    val::Any
    type::Any
    children::Vector{IndexNode}
end

isvalue(node::CINNode) = node.kind === value
#TODO Delete this one when you can
isvalue(node) = false


SyntaxInterface.istree(node::CINNode) = node.kind > literal
SyntaxInterface.arguments(node::CINNode) = node.children
SyntaxInterface.operation(node::CINNode) = node.kind

#TODO clean this up eventually
function SyntaxInterface.similarterm(::Type{<:Union{IndexNode, CINNode}}, op::CINHead, args)
    @assert istree(CINNode(op, nothing, nothing, []))
    CINNode(op, nothing, nothing, args)
end

function CINNode(kind::CINHead, args::Vector)
    if kind === value
        if length(args) == 1
            return CINNode(value, args[1], Any, IndexNode[])
        elseif length(args) == 2
            return CINNode(value, args[1], args[2], IndexNode[])
        else
            error("wrong number of arguments to value(...)")
        end
    elseif kind === literal
        if length(args) == 1
            return CINNode(kind, args[1], nothing, IndexNode[])
        else
            error("wrong number of arguments to $kind(...)")
        end
    elseif kind === name
        if length(args) == 1
            return CINNode(kind, args[1], nothing, IndexNode[])
        else
            error("wrong number of arguments to $kind(...)")
        end
    elseif kind === virtual
        if length(args) == 1
            return CINNode(kind, args[1], nothing, IndexNode[])
        else
            error("wrong number of arguments to $kind(...)")
        end
    elseif kind === with
        if length(args) == 2
            return CINNode(with, nothing, nothing, args)
        else
            error("wrong number of arguments to with(...)")
        end
    elseif kind === access
        if length(args) >= 2
            return CINNode(access, nothing, nothing, args)
        else
            error("wrong number of arguments to access(...)")
        end
    elseif kind === call
        if length(args) >= 1
            return CINNode(call, nothing, nothing, args)
        else
            error("wrong number of arguments to call(...)")
        end
    elseif kind === loop
        if length(args) == 2
            return CINNode(loop, nothing, nothing, args)
        else
            error("wrong number of arguments to loop(...)")
        end
    elseif kind === chunk
        if length(args) == 3
            return CINNode(chunk, nothing, nothing, args)
        else
            error("wrong number of arguments to chunk(...)")
        end
    elseif kind === sieve
        if length(args) == 2
            return CINNode(sieve, nothing, nothing, args)
        else
            error("wrong number of arguments to sieve(...)")
        end
    elseif kind === assign
        if length(args) == 2
            return CINNode(assign, nothing, nothing, [args[1], literal(nothing), args[2]])
        elseif length(args) == 3
            return CINNode(assign, nothing, nothing, args)
        else
            error("wrong number of arguments to assign(...)")
        end
    elseif kind === pass
        return CINNode(pass, nothing, nothing, args)
    else
        error("unimplemented")
    end
end

function (kind::CINHead)(args...)
    CINNode(kind, Any[args...,])
end

function Base.getproperty(node::CINNode, sym::Symbol)
    if sym === :kind || sym === :val || sym === :type || sym === :children
        return Base.getfield(node, sym)
    elseif node.kind === value
        error("type CINNode(value, ...) has no property $sym")
    elseif node.kind === literal
        error("type CINNode(literal, ...) has no property $sym")
    elseif node.kind === virtual
        error("type CINNode(virtual, ...) has no property $sym")
    elseif node.kind === name
        if sym === :name
            return node.val::Symbol
        else
            error("type CINNode(virtual, ...) has no property $name")
        end
    elseif node.kind === with
        if sym === :cons
            return node.children[1]
        elseif sym === :prod
            return node.children[2]
        else
            error("type CINNode(with, ...) has no property $sym")
        end
    elseif node.kind === access
        if sym === :tns
            return node.children[1]
        elseif sym === :mode
            return node.children[2]
        elseif sym === :idxs
            return @view node.children[3:end]
        else
            error("type CINNode(access, ...) has no property $sym")
        end
    elseif node.kind === call
        if sym === :op
            return node.children[1]
        elseif sym === :brgs
            return @view node.children[2:end]
        else
            error("type CINNode(call, ...) has no property $sym")
        end
    elseif node.kind === loop
        if sym === :idx
            return node.children[1]
        elseif sym === :body
            return node.children[2]
        else
            error("type CINNode(loop, ...) has no property $sym")
        end
    elseif node.kind === chunk
        if sym === :idx
            return node.children[1]
        elseif sym === :ext
            return node.children[2]
        elseif sym === :body
            return node.children[3]
        else
            error("type CINNode(chunk, ...) has no property $sym")
        end
    elseif node.kind === sieve
        if sym === :cond
            return node.children[1]
        elseif sym === :body
            return node.children[2]
        else
            error("type CINNode(sieve, ...) has no property $sym")
        end
    elseif node.kind === assign
        #TODO move op into update
        if sym === :lhs
            return node.children[1]
        elseif sym === :op
            return node.children[2]
        elseif sym === :rhs
            return node.children[3]
        else
            error("type CINNode(assign, ...) has no property $sym")
        end
    elseif node.kind === pass
        #TODO move op into update
        if sym === :tnss
            return node.children
        else
            error("type CINNode(pass, ...) has no property $sym")
        end
    else
        error("type CINNode has no property $sym")
    end
end

function Base.show(io::IO, mime::MIME"text/plain", node::CINNode) 
    if node.kind === with
        display_statement(io, mime, node, 0)
    else
        display_expression(io, mime, node)
    end
end

function Finch.getunbound(ex::CINNode)
    if ex.kind === name
        return [ex.name]
    elseif ex.kind === loop
        return setdiff(getunbound(ex.body), getunbound(ex.idx))
    elseif ex.kind === chunk
        return setdiff(union(getunbound(ex.body), getunbound(ex.ext)), getunbound(ex.idx))
    elseif istree(ex)
        return mapreduce(Finch.getunbound, union, arguments(ex), init=[])
    else
        return []
    end
end

function display_expression(io, mime, node::CINNode)
    if get(io, :compact, false)
        print(io, "@finch(…)")
    elseif node.kind === value
        print(io, node.val)
        if node.type !== Any
            print(io, "::")
            print(io, node.type)
        end
    elseif node.kind === literal
        print(io, node.val)
    elseif node.kind === name
        print(io, node.name)
    elseif node.kind === virtual
        print(io, "virtual(")
        print(io, node.val)
        print(io, ")")
    elseif node.kind === access
        display_expression(io, mime, node.tns)
        print(io, "[")
        if length(node.idxs) >= 1
            for idx in node.idxs[1:end-1]
                display_expression(io, mime, idx)
                print(io, ", ")
            end
            display_expression(io, mime, node.idxs[end])
        end
        print(io, "]")
    elseif node.kind === call
        display_expression(io, mime, node.op)
        print(io, "(")
        for arg in node.brgs[1:end-1]
            display_expression(io, mime, arg)
            print(io, ", ")
        end
        display_expression(io, mime, node.brgs[end])
        print(io, ")")
    #elseif istree(node)
    #    print(io, operation(node))
    #    print(io, "(")
    #    for arg in arguments(node)[1:end-1]
    #        print(io, arg)
    #        print(io, ",")
    #    end
    #    print(arguments(node)[end])
    else
        error("unimplemented")
    end
end

function display_statement(io, mime, node::CINNode, level)
    if node.kind === with
        print(io, tab^level * "(\n")
        display_statement(io, mime, node.cons, level + 1)
        print(io, tab^level * ") where (\n")
        display_statement(io, mime, node.prod, level + 1)
        print(io, tab^level * ")\n")
    elseif node.kind === loop
        print(io, tab^level * "@∀ ")
        while node.body.kind === loop
            display_expression(io, mime, node.idx)
            print(io," ")
            node = node.body
        end
        print(io,"(\n")
        display_statement(io, mime, node, level + 1)
        print(io, tab^level * ")\n")
    elseif node.kind === chunk
        print(io, tab^level * "@∀ ")
        display_expression(io, mime, node.idx)
        print(io, " : ")
        display_expression(io, mime, node.ext)
        print(io," (\n")
        display_statement(io, mime, node.body, level + 1)
        print(io, tab^level * ")\n")
    elseif node.kind === sieve
        print(io, tab^level * "@sieve ")
        while node.body.kind === sieve
            display_expression(io, mime, node.cond)
            print(io," && ")
            node = node.body
        end
        display_expression(io, mime, node.cond)
        node = node.body
        print(io," (\n")
        display_statement(io, mime, node, level + 1)
        print(io, tab^level * ")\n")
    elseif node.kind === assign
        print(io, tab^level)
        display_expression(io, mime, node.lhs)
        print(io, " ")
        if (node.op !== nothing && node.op != literal(nothing)) #TODO this feels kinda garbage.
            display_expression(io, mime, node.op)
        end
        print(io, "= ")
        display_expression(io, mime, node.rhs)
        print(io, "\n")
    elseif node.kind === pass
        print(io, tab^level * "(")
        for tns in arguments(node)[1:end-1]
            display_expression(io, mime, tns)
            print(io, ", ")
        end
        if length(arguments(node)) >= 1
            display_expression(io, mime, last(arguments(node)))
        end
        print(io, ")")
    else
        error("unimplemented")
    end
end

function Base.:(==)(a::CINNode, b::CINNode)
    if !istree(a)
        if a.kind === value
            return b.kind === value && a.val == b.val && a.type === b.type
        elseif a.kind === literal
            return b.kind === literal && isequal(a.val, b.val) #TODO Feels iffy idk
        elseif a.kind === name
            return b.kind === name && a.name == b.name
        elseif a.kind === virtual
            return b.kind === virtual && a.val == b.val #TODO Feels iffy idk
        else
            error("unimplemented")
        end
    elseif a.kind === pass
        return b.kind === pass && Set(a.tnss) == Set(b.tnss) #TODO This feels... not quite right
    elseif istree(a)
        return a.kind === b.kind && a.children == b.children
    else
        return false
    end
end

function Base.hash(a::CINNode, h::UInt)
    if !istree(a)
        if a.kind === value
            return hash(value, hash(a.val, hash(a.type, h)))
        elseif a.kind === literal
            return hash(literal, hash(a.val, h))
        elseif a.kind === virtual
            return hash(virtual, hash(a.val, h))
        elseif a.kind === name
            return hash(name, hash(a.name, h))
        else
            error("unimplemented")
        end
    elseif istree(a)
        return hash(a.kind, hash(a.args, h))
    else
        return false
    end
end

IndexNotation.isliteral(node::CINNode) = node.kind === literal

function Finch.getvalue(ex::CINNode)
    ex.kind === literal || error("expected literal")
    ex.val
end

function Finch.getresults(node::CINNode)
    if node.kind === with
        Finch.getresults(node.cons)
    elseif node.kind === access
        [node.tns]
    elseif node.kind === loop
        Finch.getresults(node.body)
    elseif node.kind === chunk
        Finch.getresults(node.body)
    elseif node.kind === sieve
        Finch.getresults(node.body)
    elseif node.kind === assign
        Finch.getresults(node.lhs)
    elseif node.kind === pass
        node.tnss
    else
        error("unimplemented")
    end
end

function Finch.getname(x::CINNode)
    if x.kind === name
        return x.val
    elseif x.kind === virtual
        return Finch.getname(x.val)
    else
        error("unimplemented")
    end
end

function Finch.setname(x::CINNode, sym)
    if x.kind === name
        return name(sym)
    elseif x.kind === virtual
        return Finch.setname(x.val, sym)
    else
        error("unimplemented")
    end
end


function Base.show(io::IO, mime::MIME"text/plain", stmt::IndexStatement)
    if get(io, :compact, false)
        print(io, "@finch(…)")
    else
        display_statement(io, mime, stmt, 0)
    end
end

function Base.show(io::IO, mime::MIME"text/plain", ex::IndexExpression)
	display_expression(io, mime, ex)
end

display_expression(io, mime, ex) = show(IOContext(io, :compact=>true), mime, ex)

function Base.show(io::IO, ex::IndexNode)
    if istree(ex)
        print(io, operation(ex))
        print(io, "(")
        for arg in arguments(ex)[1:end-1]
            show(io, arg)
            print(io, ", ")
        end
        if length(arguments(ex)) >= 1
            show(io, last(arguments(ex)))
        end
        print(io, ")")
    else
        invoke(show, Tuple{IO, Any}, io, ex)
    end
end

function Base.hash(a::IndexNode, h::UInt)
    if istree(a)
        for arg in arguments(a)
            h = hash(arg, h)
        end
        hash(operation(a), h)
    else
        invoke(hash, Tuple{Any, UInt}, a, h)
    end
end

Finch.IndexNotation.isliteral(ex::IndexNode) =  false
#=
function Base.:(==)(a::T, b::T) with {T <: IndexNode}
    if istree(a) && istree(b)
        (operation(a) == operation(b)) && 
        (arguments(a) == arguments(b))
    else
        invoke(==, Tuple{Any, Any}, a, b)
    end
end
=#


struct Workspace <: IndexTerminal
    n
end

SyntaxInterface.istree(::Workspace) = false
Base.hash(ex::Workspace, h::UInt) = hash((Workspace, ex.n), h)

function display_expression(io, ex::Workspace)
    print(io, "{")
    display_expression(io, mime, ex.n)
    print(io, "}[...]")
end

setname(tns::Workspace, name) = Workspace(name)



struct Protocol{Idx<:IndexNode, Val} <: IndexExpression
    idx::Idx
    val::Val
end
Base.:(==)(a::Protocol, b::Protocol) = a.idx == b.idx && a.val == b.val

protocol(args...) = protocol!(vcat(args...))
protocol!(args) = Protocol(args[1], args[2])

Finch.getname(ex::Protocol) = Finch.getname(ex.idx)
SyntaxInterface.istree(::Protocol) = true
SyntaxInterface.operation(ex::Protocol) = protocol
SyntaxInterface.arguments(ex::Protocol) = Any[ex.idx, ex.val]
SyntaxInterface.similarterm(::Type{<:IndexNode}, ::typeof(protocol), args) = protocol!(args)

function display_expression(io, mime, ex::Protocol)
    display_expression(io, mime, ex.idx)
    print(io, "::")
    display_expression(io, mime, ex.val)
end

struct Multi <: IndexStatement
    bodies::Vector{IndexNode}
end
Base.:(==)(a::Multi, b::Multi) = a.bodies == b.bodies

multi(args...) = multi!(vcat(args...))
multi!(args) = Multi(args)

SyntaxInterface.istree(::Multi) = true
SyntaxInterface.operation(stmt::Multi) = multi
SyntaxInterface.arguments(stmt::Multi) = stmt.bodies
SyntaxInterface.similarterm(::Type{<:IndexNode}, ::typeof(multi), args) = multi!(args)

function display_statement(io, mime, stmt::Multi, level)
    print(io, tab^level * "begin\n")
    for body in stmt.bodies
        display_statement(io, mime, body, level + 1)
    end
    print(io, tab^level * "end\n")
end

Finch.getresults(stmt::Multi) = mapreduce(Finch.getresults, vcat, stmt.bodies)

struct Read <: IndexTerminal end
struct Write <: IndexTerminal end
struct Update <: IndexTerminal end
