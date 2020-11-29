local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = { parameters = parameters }
end

function compat.version_ge(major, minor)
	return major > 0 or major == 0 and minor >= 17
end

return compat
