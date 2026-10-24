local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = parameters
end

function compat.version_ge(major, minor)
	return major < 2 or major == 2 and minor == 0
end

function compat.get_fluid(entity)
	return entity.fluidbox[1]
end

function compat.set_fluid(entity, fluid)
	entity.fluidbox[1] = fluid
end

function compat.clear_fluid(entity)
	entity.fluidbox[1] = nil
end

function compat.get_fluid_capacity(entity)
	return entity.fluidbox.get_capacity(1)
end

function compat.set_circuit_connector(entity, circuit_connector)
	entity.circuit_connector = circuit_connector
end

return compat
