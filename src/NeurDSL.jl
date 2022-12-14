module NeurDSL
using ModelingToolkit
MTK = ModelingToolkit
export @named, @unpack, DelayParentScope, @variables, @parameters, extend, ODESystem, structural_simplify, compose
@variables t
D = Differential(t)

function Chan(;name)
    sts = @variables V(t) I(t)
    ODESystem(Equation[],t,sts,[];name=name)
end

abstract type InheritParameters end

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
        @named channel = Chan()
        @unpack V, I = channel
        $v_assign
        $p_assign
    end,
    eqs.args...,
    quote
        extend(ODESystem(eqs, t, sts, p; name=name), channel)
    end)
    return esc(Expr(:function, Expr(:call, name, Expr(:parameters, :name, call_args...)), body))
end

function Cell(;name, V0=-40.)
    sts = @variables V(t)=V0
    ODESystem([],t,sts,[];name=name)
end

function CellType(chans, cells; name)
    # this makes the channels no pars for the cell level
    _chans = ODESystem[]
    for chan in chans
        eqs = ModelingToolkit.get_eqs(chan)
        sts = ModelingToolkit.get_states(chan)
    end
    # this makes the channels containing parameters only for the celltype level
    for chan in chans
        MTK.@set! chan.eqs = Symbolics.Arr([])
        MTK.@set! chan.states = Symbolics.Arr([])
    end

    map!(cells, cells) do c
        @unpack V = c
        ceqs = vcat(
            [D(V) ~ sum([chan.I for chan in _chans])],
            [chan.V~V for chan in _chans])
        compose(cell, _chans)
    end

    compose(ODESystem(eqs,t,[],ps;name=name), cells)
end

function connect_vpre(cell, syns...)
    [syn.Vpre ~ cell.V for syn in syns]
end

function sym_connect_vpre(cell1,cell2, names...)
    vcat(
        [getproperty(cell1,name).Vpre ~ cell2.V for name in names],
        [getproperty(cell2,name).Vpre ~ cell1.V for name in names],
    )
end

export t, D
export Chan, @Chan, Cell, CellType, connect_vpre, syn_connect_vpre

end
