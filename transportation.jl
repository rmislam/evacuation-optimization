using JuMP
import DelimitedFiles
import HiGHS

open(joinpath(@__DIR__, "transp.txt"), "w") do io
    print(
        io,
        """
             . FRA  DET LAN WIN  STL  FRE  LAF EVACUEES
          GARY  39   14  11  14   16   82    8   1400
          CLEV  27    .  12   .   26   95   17   2600
          PITT  24   14  17  13   28    2   20   2900
        VACANCIES 900 1200 900 800 1700 1100 1000 0
        """,
    )
    return
end

function read_data(filename::String)
    data = DelimitedFiles.readdlm(filename)
    rows, columns = data[2:end, 1], data[1, 2:end]
    return Containers.DenseAxisArray(data[2:end, 2:end], rows, columns)
end

data = read_data(joinpath(@__DIR__, "transp.txt"))
print(data)

function solve_transportation_problem(data::Containers.DenseAxisArray)
    # Get the set of supplies and demands
    O, D = axes(data)
    # Drop the EVACUEES and VACANCIES nodes from our sets
    O, D = setdiff(O, ["VACANCIES"]), setdiff(D, ["EVACUEES"])
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x[o in O, d in D] >= 0)
    # Remove arcs with "." cost by fixing them to 0.0.
    for o in O, d in D
        if data[o, d] == "."
            fix(x[o, d], 0.0; force = true)
        end
    end
    @objective(
        model,
        Min,
        sum(data[o, d] * x[o, d] for o in O, d in D if data[o, d] != "."),
    )
    @constraint(model, [o in O], sum(x[o, :]) == data[o, "EVACUEES"])
    @constraint(model, [d in D], sum(x[:, d]) <= data["VACANCIES", d])
    optimize!(model)
    # Pretty print the solution in the format of the input
    print("    ", join(lpad.(D, 7, ' ')))
    for o in O
        print("\n", o)
        for d in D
            if isapprox(value(x[o, d]), 0.0; atol = 1e-6)
                print("      .")
            else
                print(" ", lpad(value(x[o, d]), 6, ' '))
            end
        end
    end
    return
end

print("\nSolution:\n")
solve_transportation_problem(data)
