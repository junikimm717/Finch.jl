@kwdef struct ScopeVisitor
    freshen = Freshen()
    vars = Dict(index(:(:)) => index(:(:)))
    regularVars = set()
    scope = Set()
    global_scope = scope
end

"""
    enforce_scopes(prgm)

A transformation which gives all loops unique index names and enforces that
tensor roots are declared in a containing scope and enforces that variables are
decared once within their scope. . Note that `loop` and `sieve` both introduce new scopes.
"""
enforce_scopes(prgm) = ScopeVisitor()(prgm)

struct ScopeError
    msg
end

function open_scope(prgm, ctx::ScopeVisitor)
    prgm = ScopeVisitor(;kwfields(ctx)..., vars = copy(ctx.vars),
        regularVars = copy(ctx.regularVars), scope = Set())(prgm)
end

function (ctx::ScopeVisitor)(node::FinchNode)
    if @capture node loop(~idx, ~ext, ~body)
        ctx.vars[idx] = index(ctx.freshen(idx.name))
        loop(ctx(idx), ctx(ext), open_scope(body, ctx))
    elseif @capture node sieve(~cond, ~body)
        sieve(ctx(cond), open_scope(body, ctx))
    elseif @capture node declare(~tns, ~init)
        push!(ctx.scope, tns)
        declare(ctx(tns), init)
    elseif @capture node freeze(~tns)
        node.tns in ctx.scope || ctx.scope === ctx.global_scope || throw(ScopeError("cannot freeze $tns not defined in this scope"))
        freeze(ctx(tns))
    elseif @capture node thaw(~tns)
        node.tns in ctx.scope || ctx.scope === ctx.global_scope || throw(ScopeError("cannot thaw $tns not defined in this scope"))
        thaw(ctx(tns))
    elseif node.kind === variable
        if !(node in ctx.scope)
            push!(ctx.global_scope, node)
        end
        node
    elseif node.kind === index
        haskey(ctx.vars, node) || throw(ScopeError("unbound index $node"))
        ctx.vars[node]
    elseif node.kind == define
        if node.lhs.kind != variable
            throw(ScopeError("cannot define a non-variable $node.lhs")
        end
        var = node.lhs
        var in ctx.regularVars || throw(ScopeError("In node $(node) variable $(var) is already bound in $(keys(ctx.bindings))."))
        push!(ctx.regularVars, var)
    elseif istree(node)
        return similarterm(node, operation(node), map(ctx, arguments(node)))
    else
        return node
    end
end
