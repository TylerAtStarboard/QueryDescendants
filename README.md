# QueryDescendants Builder

A wrapper around Roblox's `Instance:QueryDescendants()` that lets you build queries from chained method calls instead of having to remember and hand-write selector strings.

```lua
-- instead of this
local parts = workspace:QueryDescendants('Model.Debris > Part[Anchored = false]')

-- you write this
local parts = Query.From(workspace,
    Query.IsA("Model"):And(Query.Tag("Debris"))
        :Child(Query.IsA("Part"):And(Query.Prop("Anchored", false)))
)
```

## Examples

Find all Parts:
```lua
Query.From(workspace, Query.IsA("Part"))
```

Find anchored Parts:
```lua
Query.From(workspace, Query.IsA("Part"):And(Query.Prop("Anchored", true)))
```

Find Parts OR MeshParts:
```lua
Query.From(workspace, Query.Or(Query.IsA("Part"), Query.IsA("MeshPart")))
```

Find Models that have a Humanoid somewhere inside:
```lua
Query.From(workspace, Query.IsA("Model"):Has(Query.IsA("Humanoid")))
```

Find all BaseParts except ones tagged "Invisible":
```lua
Query.From(workspace, Query.IsA("BasePart"):Not(Query.Tag("Invisible")))
```

Find unanchored Parts that are direct children of any Model tagged "Debris":
```lua
Query.From(workspace,
    Query.IsA("Model"):And(Query.Tag("Debris"))
        :Child(Query.IsA("Part"):And(Query.Prop("Anchored", false)))
)
```

Find MeshParts that are either direct children with tag "ThisTag" (but not named "Foo"), or have a "SpecialAttribute" with the value 5:
```lua
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
```
