local compat = {}

function compat.set_parameters(combinator, parameters)
	combinator.parameters = { parameters = parameters }
end

function compat.version_ge(major, minor)
	return major < 1 or major == 1 and minor == 0
end

return compat
