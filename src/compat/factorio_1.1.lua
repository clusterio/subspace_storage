local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = parameters
end

function compat.version_ge(major, minor)
	return major > 1 or major == 1 and minor >= 1
end

return compat
