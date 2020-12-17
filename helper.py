import pandas as pd
import numpy as np

import random
import pickle
import itertools

import matplotlib.pyplot as plt
import seaborn as sns

from IPython.display import display, HTML


models = pickle.load(open('models/bgmm_1_100_alpha{}.pkl'.format(5), 'rb'))
fuel_cols = ['wind', 'solar', 'solar_rooftop','blackcoal', 'browncoal','gas','diesel','kerosene','hydro','bagasse','batterys', 'net_import']
additional_cols = ['demand', 'rrp', 'export']

# jupyter nbconvert path/to/your/ipynb --to=pdf --TemplateExporter.exclude_input=True
def get_cluster_assignment_idx_month(X):
    X = X[['state', 'year', 'month', 'clust', 'probs']]
    # pick max prob of cluster in a given month     
    idx = X.groupby(['state', 'year', 'month'])['probs'].idxmax()
    return idx


def get_cluster_assignment_idx_day(X):
    X = X[['state', 'year', 'month', 'day', 'clust', 'probs']]
    # pick max prob of cluster in a given day     
    idx = X.groupby(['state', 'year', 'month','day'])['probs'].idxmax()
    return idx


def get_additional_col_month(X, col):
    t = get_cluster_assignment_month(X)
    t1 = X.groupby(['state', 'year', 'month', 'clust'])[col].mean()
    t = pd.merge(t, t1, on = ['state', 'month', 'clust'])
    t['clust_category']  = t['clust'].astype('category').values
    t['day'] = 1
    t['datetime'] = pd.to_datetime(t[['year', 'month', 'day']])
    return t 

def get_cluster_state_shares(X):
    t = X.groupby(['clust', 'state']).size().reset_index(name='count')
    t = t.pivot_table(index = ['clust'], columns = "state", values = "count")
    t = t.fillna(0)
    return t

def get_cluster_assignment_month(X):
    X.loc[:, 'day'] = X.datetime.dt.day
    t = X.groupby(['state', 'year', 'month', 'clust']).size().reset_index(name='clust_count')
    t1 = X.groupby(['state', 'year', 'month']).size().reset_index(name='count')
    t = pd.merge(t, t1, on=['state', 'year', 'month'])
    t = pd.merge(X[['state', 'year', 'month','day', 'clust', 'probs']], t, on=['state', 'year', 'month', 'clust'])
    t.loc[:, 'clust_probs'] = (t['clust_count']/t['count']) * t['probs']
    t = t.groupby(['state', 'year', 'month', 'clust'])['clust_probs'].mean().reset_index(name='clust_probs')
    t = t.loc[t.groupby(['state', 'year', 'month'])['clust_probs'].idxmax()]
    return(t)


def get_cluster_assignment_day(X):
    t = X.groupby(['state', 'year', 'month','day'])['clust'].value_counts()
    t = t.reset_index(name='count')
    t = t.loc[t.groupby(['state', 'year', 'month', 'day'])['count'].idxmax()]
#     if len(temp['count'].unique()) > 1:
#         raise ValueError('tie in cluster')
    t.drop(columns = ['count'], inplace = True)
    return t


def get_data():
    df_orig = pd.read_pickle('data/nem_train.pkl')
    df_orig = df_orig[df_orig.datetime.dt.date.astype('str') != '2020-10-01']
    
    index_cols = [ 'state', 'year', 'month', 'day']
    df_orig = df_orig.sort_values(['state', 'datetime'])

    df_orig['month'] = df_orig.datetime.dt.month
    df_orig['day'] = df_orig.datetime.dt.day
    
    return df_orig


def get_model(idx):
    return models[idx]


def get_cluster_df(df, idx, expected_cluster):
    bgmm = get_model(idx)
    X = df[fuel_cols]
    labels = bgmm.predict(X) + 1
    probs = bgmm.predict_proba(X)

    len(np.unique(labels))
    bgmm.converged_

    df['probs'] = probs.max(1)
    df['clust'] = labels
    
    components = len(np.unique(labels))
    if components != expected_cluster:
        raise('No of components does not match expected cluster')
    if not bgmm.converged_:
        raise('Model not converged, invalid result')
    
    # rearrange cluster
    df_fossil = df.copy()
    df_fossil = df_fossil.groupby(['clust'])[fuel_cols].mean().reset_index().apply(lambda x: round(x, 2))
    df_fossil['fossil'] = df_fossil[['blackcoal', 'browncoal','gas','diesel','kerosene']].sum(axis = 1)
    df_fossil['green'] = df_fossil[['wind', 'solar','solar_rooftop', 'hydro','bagasse','batterys']].sum(axis = 1)
    df_fossil = df_fossil.groupby(['clust'])['fossil','green'].sum().sort_values('fossil', ascending = False)
    df_fossil['clust_new'] = list(range(1, (df_fossil.shape[0] + 1)))

    df = pd.merge(df, df_fossil, on='clust')
    df['clust_old'] = df['clust']
    df['clust'] = df['clust_new']
    df['clust_category']  = df['clust'].astype('category').values
    df.drop(columns = ['clust_new'],inplace = True)
    return df


def print_energy_shares(X, save = False, fname=''):
    X = X[['clust'] + fuel_cols + additional_cols]
    X = X.groupby(['clust']).mean().reset_index().apply(lambda x: round(x, 2))
    X = X.sort_values(['clust'] + fuel_cols + additional_cols)
    with pd.option_context('display.max_rows', None, 'display.max_columns', None): 
        display(HTML(X.to_html(index = False)))
    if save:
        X.to_csv('results/plots/{}_energy_shares.csv'.format(fname))
        
        
def plot_cluster_percentages(df, reorder = False, save = False, fname=''):
    t = df.groupby(['clust']).size().reset_index(name ='count')
    t['percentage'] = np.round(t['count']/18110 * 100, 2)
    if reorder:
        t = t.sort_values('percentage', ascending = False)
    display(HTML(t.to_html(index = False)))
    if save:
        t.to_csv('results/plots/{}_cluster_percentage.csv'.format(fname))
        
        
def print_state_year_month_matrix(X, use_day = False, plot_size = 12, save = False, fname=''):
    if use_day:
        X = X[['state', 'year', 'month', 'day', 'clust', 'probs']]
        X = get_cluster_assignment_day(X)
    else:
        X = X[['datetime', 'state', 'year', 'month', 'clust', 'probs']]
        X = get_cluster_assignment_month(X)
    
    X.loc[:, 'clust'] = X['clust'].astype('int')
    print('unique clusters {}'.format(np.sort(X['clust'].unique())))

    # reshape for plotting    
    if use_day:
        X = X.pivot_table(index = ['month', "day"], columns =['state', 'year'], values = "clust")
        fig, ax = plt.subplots(figsize=(25, 100))
    else:
        X = X.pivot_table(index = ['state', 'month'], columns = "year", values = "clust")
        fig, ax = plt.subplots(figsize=(plot_size, plot_size))  
    
    svm = sns.heatmap(X,annot=True, linewidths=.5, cmap="YlGnBu", ax = ax, cbar = False)
    sns_plot = svm.get_figure()    
    if save:
        sns_plot.savefig('results/plots/{}_heatmap_daily.png'.format(fname), dpi=400)
    