import ModelingToolkit: renamespace
using ModelingToolkit: unwrap, Symbolic, value, rename, getname, AbstractSystem
using ModelingToolkit.Symbolics: Operator

import ModelingToolkit.Symbolics: setmetadata
import ModelingToolkit.Symbolics: getmetadata
using ModelingToolkit: AbstractSystem

function setmetadata(s::AbstractSystem, ctx::DataType, val)
    if s.metadata isa AbstractDict
        MTK.@set s.metadata = Symbolics.SymbolicUtils.assocmeta(s.metadata, ctx, val)
    else
        # fresh Dict
        MTK.@set s.metadata = Base.ImmutableDict{DataType, Any}(ctx, val)
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

abstract type ScopeLevels end


count_scope_level(scope::LocalScope, i=0) = i
count_scope_level(scope::GlobalScope, i=0) = 0
count_scope_level(scope::ParentScope, i=0) = count_scope_level(scope.parent, i+1)
function count_scope_level(scope::DelayParentScope, i=0)
    N = scope.N
    if N == 0
        count_scope_level(scope.parent, i+1)  
    else
        count_scope_level(DelayParentScope(scope.parent,N-1), i+1)
    end
end

import ModelingToolkit: compose
using ModelingToolkit: get_systems, get_ps, get_states

function compose(sys::AbstractSystem, systems::AbstractArray; name = nameof(sys))
    nsys = length(systems)
    nsys == 0 && return sys
    
    base_systems = get_systems(sys)
    nsysbase = length(base_systems)
    levels = [NTuple{3,Int64}[],NTuple{3,Int64}[]]
    for (i,s) in enumerate(systems)
        ps = get_ps(s)
        sts = get_states(s)
        pmeta = getmetadata.(ps, SymScope, Ref(LocalScope()))
        vmeta = getmetadata.(sts, SymScope, Ref(LocalScope()))
        plevels = count_scope_level.(pmeta)
        vlevels = count_scope_level.(vmeta)
        oldlvls = getmetadata(s,ScopeLevels,[NTuple{3,Int64}[],NTuple{3,Int64}[]])
        push!(levels[1], [(i+nsysbase,j,e-1) for (i,j,e) in oldlvls[1]]...)
        push!(levels[1], [(i+nsysbase,j,e) for (j,e) in enumerate(plevels) if e>0]...)
        push!(levels[2], [(i+nsysbase,j,e-1) for (i,j,e) in oldlvls[2]]...)
        push!(levels[2], [(i+nsysbase,j,e) for (j,e) in enumerate(vlevels) if e>0]...)
    end
    levels

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



    if all(x -> x[3] != 1, Iterators.flatten(levels))
        @set! sys.name = name
        @set! sys.systems = [base_systems;systems]
        return setmetadata(sys, ScopeLevels, levels)
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
    
    struct ScopeTracker
        distance::Int64
        name::Symbol
        type::Symbol
    end

    count_scope_level(scope::LocalScope, i=0) = i
    count_scope_level(scope::GlobalScope, i=0) = 0
    count_scope_level(scope::ParentScope, i=0) = count_scope_level(scope.parent, i+1)
    function count_scope_level(scope::DelayParentScope, i=0)
        N = scope.N
        if N == 0
            count_scope_level(scope.parent, i+1)  
        else
            count_scope_level(DelayParentScope(scope.parent,N-1), i+1)
        end
    end
    
    import ModelingToolkit: compose
    using ModelingToolkit: get_systems, get_ps, get_states
    
    function compose(sys::AbstractSystem, systems::AbstractArray; name = nameof(sys))
        nsys = length(systems)
        nsys == 0 && return sys

        scope_trackers = getmetadata.(systems, ScopeTracker, Ref(ScopeTracker(0,:_,:_)))

        for s in systems
            m = getmetadata(s,ScopeTracker, def())
            









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
    
    
    
    
end
S