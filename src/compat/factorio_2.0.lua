local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = parameters
end

function compat.version_ge(major, minor)
	return major < 2 or major == 2 and minor == 0
end

return compat
