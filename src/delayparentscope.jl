import ModelingToolkit: renamespace
using ModelingToolkit: unwrap, Symbolic, value, rename, getname, AbstractSystem
using ModelingToolkit.Symbolics: Operator

struct DelayParentScope <: SymScope
    parent::SymScope
    N::Int
end

function DelayParentScope(sym::Union{Num, Symbolic}, N)
    setmetadata(sym, SymScope,
        DelayParentScope(getmetadata(value(sym), SymScope, LocalScope()),N))
end
DelayParentScope(sym::Union{Num, Symbolic}) = DelayParentScope(sym,1)

function renamespace(sys, x)
    sys === nothing && return x
    x = unwrap(x)
    if x isa Symbolic
        if istree(x) && operation(x) isa Operator
            return similarterm(x, operation(x), Any[renamespace(sys, only(arguments(x)))])
        end
        let scope = getmetadata(x, SymScope, LocalScope())
            if scope isa LocalScope
                rename(x, renamespace(getname(sys), getname(x)))
            elseif scope isa ParentScope
                setmetadata(x, SymScope, scope.parent)
            elseif scope isa DelayParentScope
                if scope.N > 0
                    x = setmetadata(x, SymScope,
                        DelayParentScope(scope.parent, scope.N-1))
                    rename(x, renamespace(getname(sys), getname(x)))
                else
                    #rename(x, renamespace(getname(sys), getname(x)))
                    setmetadata(x, SymScope, scope.parent)
                end
            else # GlobalScope
                x
            end
        end
    elseif x isa AbstractSystem
        rename(x, renamespace(sys, nameof(x)))
    else
        Symbol(getname(sys), :₊, x)
    end
end
