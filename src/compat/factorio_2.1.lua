local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = parameters
end

function compat.version_ge(major, minor)
	return major < 2 or major == 2 and minor <= 1
end

-- 2.1 removed LuaEntity::fluidbox, fluids are accessed through the entity itself
function compat.get_fluid(entity)
	return entity.get_fluid(1)
end

function compat.set_fluid(entity, fluid)
	entity.set_fluid(1, fluid)
end

function compat.clear_fluid(entity)
	entity.clear_fluid(1)
end

function compat.get_fluid_capacity(entity)
	return entity.get_fluid_capacity(1)
end

function compat.set_circuit_connector(entity, circuit_connector)
	if entity.type == "container" or entity.type == "logistic-container" then
		-- 2.1 containers take one circuit connector per direction
		entity.circuit_connector = { circuit_connector }
	else
		entity.circuit_connector = circuit_connector
	end
end

return compat
