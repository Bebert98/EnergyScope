import pandas as pd
import os
from pathlib import Path


def get_total_cost(config, case = 'deter'):
    two_up = Path(__file__).parents[2]

    if case == 'deter':
        costs = pd.read_csv(os.path.join(two_up,'case_studies',config['case_study'],'output','cost_breakdown.txt'), index_col=0, sep='\t')
    else:
        costs = pd.read_csv(os.path.join(two_up,'case_studies',config['UQ_case'],config['case_study'],'output','cost_breakdown.txt'), index_col=0, sep='\t')

    return costs.sum().sum()
