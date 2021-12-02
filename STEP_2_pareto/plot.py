import matplotlib.pyplot as plt

import energyscope as es


if __name__ == '__main__':

    case_study_path = "/home/duboisa1/Global_Grid/code/EnergyScope/case_studies"
    test_case = 'pareto/run2'
    epsilons = [0.0125, 0.025, 0.05, 0.1, 0.15]  # [e/100 for e in range(1, 13)]

    cost_opt_cost = es.get_total_cost(f"{case_study_path}/{test_case}")
    einv_opt_cost = es.get_total_einv(f"{case_study_path}/{test_case}")
    print(f"Optimal Cost {cost_opt_cost:.2f}")
    print(f"Einv at optimal cost {einv_opt_cost:.2f}")

    cost_opt_einv = es.get_total_cost(f"{case_study_path}/{test_case}_einv")
    einv_opt_einv = es.get_total_einv(f"{case_study_path}/{test_case}_einv")
    print(f"Cost at optimal einv {cost_opt_einv:.2f}")
    print(f"Optimal einv {einv_opt_einv:.2f}")
    print()

    x = [0.]
    y = [einv_opt_cost/einv_opt_einv-1]
    print(y)
    for epsilon in epsilons:
        dir = f"{case_study_path}/{test_case}_epsilon_{epsilon}"
        print(dir)
        cost = es.get_total_cost(dir)
        einv = es.get_total_einv(dir)
        print(cost, einv)
        x += [cost/cost_opt_cost-1]
        y += [einv/einv_opt_einv-1]

    # Adding CO2 extreme point
    x += [cost_opt_einv/cost_opt_cost-1]
    y += [0.]

    print([round(i, 2) for i in x])
    print([round(j, 3) for j in y])
    plt.plot(x, y,)
    plt.plot(x, y, 'o')
    plt.grid()
    plt.xlabel("Deviation from cost optimal")
    plt.ylabel("Deviation from Einv optimal")
    plt.title("Pareto front (Cost vs Einv)")
    plt.show()