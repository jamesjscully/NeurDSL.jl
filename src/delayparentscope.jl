using ModelingToolkit
using ModelingToolkit: unwrap, Symbolic, value, rename, getname, @set, @set!
using ModelingToolkit: AbstractSystem, LocalScope, SymScope, ParentScope, DelayParentScope
import ModelingToolkit:compose
import ModelingToolkit.Symbolics: setmetadata, getmetadata

function setmetadata(s::AbstractSystem, ctx::DataType, val)
    if s.metadata isa AbstractDict
        @set s.metadata = Symbolics.SymbolicUtils.assocmeta(s.metadata, ctx, val)
    else
        # fresh Dict
        @set s.metadata = Base.ImmutableDict{DataType, Any}(ctx, val)
    end
end

function getmetadata(s::AbstractSystem, ctx)
    md = s.metadata
    if md isa AbstractDict
        md[ctx]
    else
        throw(ArgumentError("$s does not have metadata for $ctx"))
    end
end

function getmetadata(s::AbstractSystem, ctx, default)
    md = s.metadata
    md isa AbstractDict ? get(md, ctx, default) : default
end

struct ScopeTracker{S,P}
    scope::S
    path
    parent::P
end

struct STVar end
struct STPar end
struct STSys 
    parent
end

function update_scope_tracker(tracker::ScopeTracker{S,P}, name, i=0) where {S<:Union{LocalScope,GlobalScope}, P}
    tracker
end

function update_scope_tracker(tracker::ScopeTracker{S,P}, name, i=0) where {S, P}
    update_scope_tracker(T([name]),scope.parent, name, i+1)
end
function update_scope_tracker(tracker, scope::DelayParentScope, i=0)
    N = scope.N
    if N == 0
        update_scope_tracker(ScopeDatum(tracker.parent, [name; tracker.name]), scope.parent, i+1)  
    else
        update_scope_tracker(ScopeDatum(tracker, [name]), DelayParentScope(scope.parent,N-1), i+1)
    end
end

track_scope(STVar, ParentScope(ParentScope(LocalScope())), :s1, 0)

import ModelingToolkit: compose
using ModelingToolkit: get_systems, get_ps, get_states
using Base.Cartesian

function compose(sys::AbstractSystem, systems::AbstractArray; name = nameof(sys))
    nsys = length(systems)
    nsys == 0 && return sys
    
    #data from nested subsystemsystems
    scope_trackers = getmetadata.(systems, ScopeTracker, Ref([]))
    #data from subsystems
    for s in systems
        arr = []
        for p in get_ps(s)
            scope = getmetadata(p,SymScope,LocalScope())
            scope isa LocalScope && break
            push!(arr, ScopeTracker(scope, [nameof(p)], STPar))
        end
        for u in get_states(s)
            scope = getmetadata(u,SymScope,LocalScope())
            scope isa LocalScope && break
            push!(arr, ScopeTracker(scope, [nameof(u)], STPar))
        end
        scope_trackers = [scope_trackers; arr]
    end
    
    @set! sys.name = name

    if all(isempty, scope_trackers)   
        @set! sys.systems = [get_systems(sys); systems]
        return sys
    end
    
    new_states = []
    new_u = []
    new_systems = []
    for (i,trackarr) in scope_trackers
        s = systems[i]
        for d in trackarr
            if d.counter == 1
                _s = s
                for i = 1:(length(d.s)-1)
                    j = findfirst(e -> nameof(e) == d.name, _syss)
                    isnothing(j) && throw(ErrorException("the metadata for variable scoping does not match the system structure"))
                    _s = _syss[findfirst(e -> nameof(e) == d.name, _s)]
                    _syss = get_systems(_sys)
                end

                if d.type == :ps
                    N = length(d.s)
                    @nexprs
                    ps = get_ps(sys)
                    _p = ps[d.idxs[end]]
                    p = nameof(_p) == d.name ? _p : findfirst(e -> nameof(e) == d.name, ps)
                    push!(new_p, p)
                elseif d.type == :states
                    sts = get_states(sys)
                    _u = sts[d.idxs[end]]
                    u = nameof(_u) == d.name ? _u : findfirst(e -> nameof(e) == d.name, sts)
                    push!(new_u, u)
                end
            end
        #update scope_trackers
    end


    for (i,s) in enumerate(systems)
        ps = get_ps(s)
        sts = get_states(s)
        pmeta = getmetadata.(ps, SymScope, Ref(LocalScope()))
        vmeta = getmetadata.(sts, SymScope, Ref(LocalScope()))
        plevels = count_scope_level.(pmeta)
        vlevels = count_scope_level.(vmeta)
        oldlvls = getmetadata(s,ScopeLevels,[Int64[],Int64[]])
        push!(levels[1], (oldlvls[1].-1)...)
        push!(levels[1], plevels...)
        push!(levels[2], (oldlvls[2].-1)...)
        push!(levels[2], vlevels...)
    end

    if all(x -> x[3] != 1, Iterators.flatten(levels))
        ps_lvls_to_update = filter(x -> x[3] == 0, levels[1])
        vs_lvls_to_update = filter(x -> x[3] == 0, levels[2])
    
        for (i,j,lvl) in ps_lvls_to_update
            _sys = systems[i]
            p = get_ps(_sys)[j]
            deleteat!()
        end
    
    
        return sys

end


@parameters t a b c d e f
p = [a
    ParentScope(b)
    ParentScope(ParentScope(c))
    DelayParentScope(d)
    DelayParentScope(e, 2)
    GlobalScope(f)]

level0 = ODESystem(Equation[], t, [], p; name = :level0)
level1 = ODESystem(Equation[], t, [], []; name = :level1) ∘ level0
level2 = ODESystem(Equation[], t, [], []; name = :level2) ∘ level1
level3 = ODESystem(Equation[], t, [], []; name = :level3) ∘ level2

ps = ModelingToolkit.getname.(parameters(level3))

@test isequal(ps[1], :level2₊level1₊level0₊a)
@test isequal(ps[2], :level2₊level1₊b)
@test isequal(ps[3], :level2₊c)
@test isequal(ps[4], :level2₊level0₊d)
@test isequal(ps[5], :level1₊level0₊e)
@test isequal(ps[6], :f)