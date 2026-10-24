local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = { parameters = parameters }
end

function compat.version_ge(major, minor)
	return major == 0 and minor <= 17
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
	entity.circuit_wire_connection_points = circuit_connector.points
	entity.circuit_wire_connection_point = circuit_connector.points
	entity.circuit_connector_sprites = circuit_connector.sprites
	entity.circuit_wire_max_distance = 9
end

return compat
