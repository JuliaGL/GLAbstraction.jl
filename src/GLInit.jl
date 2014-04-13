const INIT_FUNCTION_LIST = Function[]

export initAfterContextCreation, initGLUtils

function initAfterContextCreation(f::Function)
	push!(INIT_FUNCTION_LIST, f)
end

function initGLUtils()
	for elem in INIT_FUNCTION_LIST
		elem()
	end
end
