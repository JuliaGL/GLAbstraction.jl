using GLAbstraction, Compat, Base.Test
dicta = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
)

dictb = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
)

@materialize a,b,c = dicta
@test a == dicta[:a]
@test b == dicta[:b]
@test c == dicta[:c]

@materialize! a,b,c = dictb
@test a == dicta[:a]
@test b == dicta[:b]
@test c == dicta[:c]
@test isempty(dictb)

@materialize a,b,c = @compat Dict(
	:a => 2332,
	:b => 777,
	:c => 999,
)
@test a == dicta[:a]
@test b == dicta[:b]
@test c == dicta[:c]

println("macros successfully tested")
