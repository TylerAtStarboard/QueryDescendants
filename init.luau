--[=[
	Builder for Instance:QueryDescendants() selector strings

	local Query = require(QueryModule)
	
	Top-Level calls (start a query or combine selectors):
			Query.IsA(className)       — match by class
			Query.Tag(tag)             — match by CollectionService tag
			Query.Name(name)           — match by Name
			Query.Prop(prop, value)    — match by property value
			Query.Attr(attr, value?)   — match by attribute, optionally with a value
			Query.Or(...)              — combine selectors as alternatives
			Query.Not(...)             — exclude matches
			Query.Has(...)             — has matching descendants
			Query.DirectChild(selector) — restrict to direct children of root
			Query.From(root, selector) — run the query, returns { Instance }

			Query.First(instances)     — get the first result, or nil
			Query.One(instances)       — get exactly one result, errors otherwise
	
			e.g Query.First(Query.From(...)) , Query.One(Query.From(...))



		Chain methods (refine an existing selector):
			:And(selector)       — compound (A AND B)
			:Not(...)            — exclude matches
			:Has(...)            — must contain a matching descendant
			:Child(selector)     — match direct children
			:Descendant(selector) — match any descendants
			:Or(...)             — add alternatives
			:Build()             — get the raw selector string


	Examples:

	- Find all Parts in workspace
	Query.From(workspace, Query.IsA("Part"))

	- Find all instances named "Coin"
	Query.From(workspace, Query.Name("Coin"))

	- Find all instances tagged "Enemy"
	Query.From(workspace, Query.Tag("Enemy"))

	- Find all anchored Parts
	Query.From(workspace, Query.IsA("Part"):And(Query.Prop("Anchored", true)))

	- Find all instances with a "Health" attribute
	Query.From(workspace, Query.Attr("Health"))

	- Find all instances with a "Health" attribute = 100
	Query.From(workspace, Query.Attr("Health",100))

	- Find SpotLights that are direct children of any Part
	Query.From(workspace, Query.IsA("Part"):Child(Query.IsA("SpotLight")))

	- Find all Parts OR MeshParts
	Query.From(workspace, Query.Or(Query.IsA("Part"), Query.IsA("MeshPart")))

	- Find Models that contain a Humanoid somewhere inside them
	Query.From(workspace, Query.IsA("Model"):Has(Query.IsA("Humanoid")))

	- Find all BaseParts except ones tagged "Invisible"
	Query.From(workspace, Query.IsA("BasePart"):Not(Query.Tag("Invisible")))

	- Find unanchored Parts that are direct children of any Model tagged "Debris"
	Query.From(workspace,
		Query.IsA("Model"):And(Query.Tag("Debris"))
			:Child(Query.IsA("Part"):And(Query.Prop("Anchored", false)))
	)
	
	- Find a MeshPart that: 

		-(is a direct child of the instance AND has a tag "ThisTag" and is not named "Foo")
		
	OR 
		
		- has attribute "SpecialAttribute with the value 5"
	
	
	local results = Query.From(workspace,
		Query.Or(
			Query.DirectChild(
				Query.IsA("MeshPart")
					:And(Query.Tag("ThisTag"))
					:Not(Query.Name("Foo"))
			),
			Query.IsA("MeshPart"):And(Query.Attr("SpecialAttribute", 5))
		)
	)
]=]

local Query = {}

local Selector = {}
Selector.__index = Selector

-- Convert value to string
local function formatValue(value: boolean | number | string): string
	local t = type(value)
	if t == "boolean" then
		return if value then "true" else "false"
	elseif t == "number" then
		local n = value :: number
		if n == math.floor(n) and n == n then -- not nan
			return string.format("%d", n)
		end
		return tostring(n)
	else
		local s = value :: string
		if #s > 0 and string.match(s, "^[%a%d_%-]+$") then -- valid string
			return s
		end
		return '"' .. string.gsub(s, '"', '"') .. '"'
	end
end

-- wrap into selector
local function new(expr: string)
	return setmetatable({ _expr = expr }, Selector)
end

-- comma-joins all expressions from selectors

local function buildAll(...: any): string
	local n = select("#", ...)
	local parts = table.create(n)
	for i = 1, n do
		parts[i] = (select(i, ...) :: any)._expr
	end
	return table.concat(parts, ", ")
end

-- returns the raw selector string

function Selector:Build(): string
	return self._expr
end

-- print out the string instead of the table

function Selector:__tostring(): string
	return self._expr
end

-- appends another selector to this one (compound selector, e.g. MeshPart.Fruit)
function Selector:And(other: any)
	return new(self._expr .. other._expr)
end

-- combines this selector with others as alternatives (A, B, C)
function Selector:Or(...)
	return new(self._expr .. ", " .. buildAll(...))
end

-- matches direct children
function Selector:Child(child: any)
	return new(self._expr .. " > " .. child._expr)
end

-- matches any descendants
function Selector:Descendant(descendant: any)
	return new(self._expr .. " >> " .. descendant._expr)
end

-- filters to instances that contain something matching the given selectors
function Selector:Has(...)
	return new(self._expr .. ":has(" .. buildAll(...) .. ")")
end

-- filters out instances matching the given selectors
function Selector:Not(...)
	return new(self._expr .. ":not(" .. buildAll(...) .. ")")
end

export type Selector = typeof(new(""))

-- matches instances of a class
function Query.IsA(className: string): Selector
	return new(className)
end

-- matches instances with a CollectionService tag
function Query.Tag(tag: string): Selector
	return new("." .. tag)
end

-- matches instances with a specific Name
function Query.Name(name: string): Selector
	return new("#" .. name)
end

-- matches instances where a property equals a value
function Query.Prop(property: string, value: boolean | number | string): Selector
	return new("[" .. property .. " = " .. formatValue(value) .. "]")
end

-- matches instances with an attribute, optionally checking its value
function Query.Attr(attribute: string, value: (boolean | number | string)?): Selector
	if value ~= nil then
		return new("[$" .. attribute .. " = " .. formatValue(value) .. "]")
	end
	return new("[$" .. attribute .. "]")
end

-- standalone :not() — excludes instances matching any of the given selectors
function Query.Not(...: Selector): Selector
	return new(":not(" .. buildAll(...) .. ")")
end

-- standalone :has() — matches instances containing descendants matching the given selectors
function Query.Has(...: Selector): Selector
	return new(":has(" .. buildAll(...) .. ")")
end

-- combines multiple selectors as alternatives (A, B, C)
function Query.Or(...: Selector): Selector
	return new(buildAll(...))
end

-- restricts a selector to only match direct children of the root
function Query.DirectChild(selector: Selector): Selector
	return new("> " .. (selector :: any)._expr)
end

-- runs the query against a root instance and returns matching descendants
function Query.From(root: Instance, selector: Selector): { Instance }
	return root:QueryDescendants((selector :: any)._expr)
end

-- get the first result of a query

function Query.First(instances: { Instance })
	return instances[1]
end

-- get only one result from a query, error otherwise

function Query.One(instances: { Instance })
	assert(#instances == 1, `expected 1 instance from query, instead got {#instances} instances`)
	return instances[1]
end

-- returns the selector string without running a query
function Query.BuildString(selector: Selector): string
	return (selector :: any)._expr
end

return Query
