using ModelingToolkit
using ModelingToolkit: unwrap, Symbolic, value, rename, getname, @set, @set!, get_systems, get_ps, get_states

using ModelingToolkit: AbstractSystem, LocalScope, SymScope, ParentScope, DelayParentScope, get_var_to_name
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

function update_scope_tracker(tracker::ScopeTracker{S,P}, name) where {S<:Union{LocalScope,GlobalScope}, P}
    tracker
end

function update_scope_tracker(tracker::ScopeTracker{S,P}, name) where {S<:ParentScope, P}
    ScopeTracker(tracker.scope.parent, [name; tracker.path], tracker.parent)
end

function update_scope_tracker(tracker::ScopeTracker{S,P}) where {S<:DelayParentScope, P}
    N = scope.N
    if N == 0
        ScopeTracker(tracker.scope.parent, [name; tracker.path], tracker.parent)
    else
        ScopeTracker(S(tracker.scope.parent,tracker.scope.n-1), [name; tracker.path], tracker)
    end
end
tracker = ScopeTracker(ParentScope(LocalScope()), [:e], STPar())
update_scope_tracker(tracker, :s1)
name = :s1
ScopeTracker(tracker.scope.parent, [name; tracker.path], tracker.parent)

[getmetadata(p,SymScope,LocalScope()) for p in get_ps(level0)]

function compose(sys::AbstractSystem, systems::AbstractArray; name = nameof(sys))
    
    @set! sys.name = name

    nsys = length(systems)
    nsys == 0 && return sys
    
    #data from nested subsystemsystems
    tracker_arrays = map(systems) do s
        getmetadata(s, ScopeTracker, ScopeTracker[])
    end
        
    #data from subsystems
    for (i,s) in enumerate(systems)
        arr = []
        for p in get_ps(s)
            scope = getmetadata(p,SymScope,LocalScope())
            scope isa LocalScope ||
            push!(arr, ScopeTracker(scope, [nameof(p)], STPar))
        end
        for u in get_states(s)
            scope = getmetadata(u,SymScope,LocalScope())
            scope isa LocalScope ||
            push!(arr, ScopeTracker(scope, [nameof(u)], STVar))
        end
        tracker_arrays[i] = [tracker_arrays[i]; arr]
    end

    if all(isempty, tracker_arrays)
        @set! sys.systems = [get_systems(sys); systems]
        return sys
    end

    return tracker_arrays
    
    for (i,trackers) in enumerate(tracker_arrays)
        s = systems[i]
        update_by_tracker!.(tracker, s)
    end

    @set! sys.systems = [get_systems(sys); systems]
    return sys
end

function update_by_tracker!(tracker:ScopeTracker{S,P}, s) where {S<:LocalScope, P<:STPar}
    @set! s.parameters = deleteat!
end
function update_by_tracker!(s,tracker:ScopeTracker{S,P}) where {S, P<:STVar}

end

function update_by_tracker!(s,tracker::ScopeTracker{S,P}) where {S<:LocalScope,P}
    if length(tracker.path) == 1
        i = findfirst(x -> nameof(tracker.path[1]))

        @set! s.systems
        return update_scope_subsystem!(ODESystem)
    end
end
function update_by_tracker!(s,tracker::ScopeTracker{S,P}) where {S<:ParentScope,P}
    nothing
end
function update_by_tracker!(s,tracker::ScopeTracker{S,P}) where {S<:LocalScope,P}

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