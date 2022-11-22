module NeurDSL
using ModelingToolkit
@variables t
D = Differential(t)

function Chan(;name)
    sts = @variables V(t) I(t)
    ODESystem(Equation[],t,sts,[];name=name)
end

macro Chan(name, ps, ics, eqs)
    p_ex = filter( x -> x isa Expr, ps.args)
    p_call_args = if !isempty(p_ex)
        [Expr(:kw, x.args[1], x.args[2]) for x in p_ex if x.head == :(=)]
    else [] end
    p_assign_args =
        [x.head==:(=) ? :($(x.args[1])=$(x.args[1])) : x for x in p_ex]
    v_ex = ics isa Nothing ? [] : filter( x -> x isa Expr, ics.args)
    v_call_args = if !isempty(v_ex)
        [Expr(:kw, Symbol(x.args[1],0), x.args[2]) for x in v_ex if x.head == :(=)]
    else [] end
    v_assign_args =
        [x.head==:(=) ? :($(x.args[1])(t)=$(Symbol(x.args[1],0))) : :($x(t)) for x in v_ex]
    call_args = union(p_call_args, v_call_args)
    v_assign = if isempty(v_ex)
        :(sts = [])
        else Expr(:(=), :sts, Expr(:macrocall,
            Symbol("@variables"),LineNumberNode(1), v_assign_args...))
    end
    p_assign = if isempty(p_ex)
        :(p = [])
        else Expr(:(=), :p, Expr(:macrocall,
            Symbol("@parameters"),LineNumberNode(1), p_assign_args...))
    end
    body = Expr(:block, quote
        @named channel = Channel()
        @unpack V, I = channel
        $v_assign
        $p_assign
    end,
    eqs.args...,
    quote
        inherit_parameters && @. p = DelayParentScope(p)
        extend(ODESystem(eqs, t, sts, p; name=name), channel)
    end)
    return esc(Expr(:function, Expr(:call, name, Expr(:parameters,
        :name, Expr(:kw, :inherit_parameters, true), call_args...)), body))
end

function Cell(chans ;name,
    Iapp = 0., V0=0.)
    sts = @variables V(t)=V0 I(t)
    p = @parameters Iapp=Iapp
    eqs = vcat([
        D(V) ~ -I + Iapp
        I ~ sum([c.I for c in chans])
    ],[
        c.V ~ V for c in chans
    ])
    sys = ODESystem(eqs,t,sts,p;name=name)
    compose(sys, channels)
end

function CellType(cells; name)
    compose(ODESystem(Equation[],t,[],[];name=name), cells)
end

function connect_vpre(cell, syns...)
    [syn.Vpre ~ cell.V for syn in syns]
end

export ModelingToolkit
export t, D
export Chan, @Chan, Cell, CellType, connect_vpre

end
