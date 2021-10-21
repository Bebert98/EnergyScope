import pandas as pd
import os


def get_total_cost(config):
    costs = pd.read_csv('../case_studies/' + config['case_study'] + '/output/cost_breakdown.txt', index_col=0, sep='\t')

    return costs.sum().sum()