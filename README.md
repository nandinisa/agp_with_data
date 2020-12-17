# README #

Clustering of Australian Generation Profiles (AGP). Data from NEM site, study period: Nov 2010- Sept 2020


### Requirements ###
* Fit-SNE: https://github.com/KlugerLab/FIt-SNE
* Add folder as Fit-SNE-master


### Download data ###

* Run scripts/download.sh script file to download raw NEM data files (change dates according to study period). 
    - The script downloads dipatch data (5 min interval), dispatch price (30 min interval) and demand (30 min interval)
* Run scripts/split_date.awk - The scripts splits datetime columns into date and time columns
* Helper files
    - duid.sh - get all the unique DUIDs from the dispatch data csv files (used to bucket DUIDs to energy profiles)
    - Map duid to https://www.aemo.com.au/-/media/Files/Electricity/NEM/Participant_Information/NEM-Registration-and-Exemption-List.xls (NEM registration list - worksheet 4)

### Files ####

* 1.raw_data_creator.ipynb - Merges individual download raw data files (dispatch, price, demand) into daily energy profile percentages
* 2.data_preprocess.ipynb - Generic plots, dimensionality reduction: PCA and TSNE
* 3.optimal_cluster_bgmm.ipynb - Optimal cluster count determined using different alpha using bayesian clustering
* 4.cluster_results_bgmm.ipynb - Cluster result analysis

