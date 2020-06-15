#!/usr/bin/julia
# -*- coding: utf-8 -*-

#################################### Help ###################################

doc = """Generate data sets to explore scoring of differences in high-dimensional point clouds in presence of noise and outliers.  
See 0_Generate_Datasets.ipynb for a more verbose description of this script.
This script output the following datasets:
* `matR.csv` - Reference dataset.
* `matN.csv` - Negative control dataset.
* `matPS.csv` - Positive control dataset, shifted.
* `matPR.csv` - Positive control dataset, with different covariance.
As well as `matRo.csv`, `matNo.csv`, `matPSo.csv` and `matPRo.csv` which follow the same rules but include outliers.
Author: Loan Vulliard @ Menche Lab, CeMM.

Usage:
  0_Generate_Datasets.jl [-r <referencePoints> -p <perturbationPoints> -d <dimensions> -o <proportionOutliers> -s <scalingParameter> -f <outputFolder>]
  0_Generate_Datasets.jl --help

Options:
  -r --reference=<referencePoints>         Number of points in reference set [default: 3000]
  -p --perturbation=<perturbationPoints>   Number of points in each other set [default: 1000]
  -d --dim=<dimensions>                    Number of dimensions (measurements) [default: 100]
  -o --outlier=<proportionOutliers>        Portion of the data contaminated [default: 0.4]
  -s --scaling=<scalingParameter>          Strength of simulated perturbations [default: 1]
  -f --folder=<outputFolder>               Where datasets are saved [default: Data/]
  -h --help                                Show this screen.
"""


################################## Import #################################

using Random, Distributions
using DataFrames, CSV, DocOpt

using LinearAlgebra: I, Diagonal, diag, det, qr, Symmetric

# This line corrects syntax highlighting in Sublime text"""

################################## Parameters #################################

args = docopt(doc, version=v"1.0.0")

# Number of points in control dataset
NR = parse(Int, args["--reference"])
# Number of points in other datasets
N = parse(Int, args["--perturbation"])
# Number of dimensions in each dataset
D = parse(Int, args["--dim"])
# Percentage of datasets contaminated with outliers
pOutliers = parse(Float64, args["--outlier"])
# Scaling of the transformation for positive controls
posScaling = parse(Float64, args["--scaling"])
# Folder in which the datasets will be saved
outDir = args["--folder"];

"""
## Dataset 1 - Reference R
We assume our data of interest to follow a multivariate normal distribution: In a morphological profiling, components are to some extent *independent (by removing correlated morphological features) and* normally distributed (by using a log-transformation).
"""

Random.seed!(1);

# The reference is centered on 0
µ = zeros(D);

# Diagonal: variances follow a Gamma distribution of shape and scale parameters equal to 1 and 2
# Rationale: Some variability in scales with some high values, and no negative values
# NB: Beta distribution could be used instead of Gamma distribution if long-tail is not needed
# NB: Effects are smoothed by the orthogonal transformation anyway
distrib = Gamma(1,2)
sigma_diag = rand(distrib, D);

# Now we transform this space by multiplying by a random orthogonal matrix
s = rand(D,D)
Q, R = qr(s);

# NB: becomes really slow, do not try with D > 500
∑ = Q' * Diagonal(sigma_diag) * Q;

# Check that the matrix is symmetrical (up to machine error)
@assert all([∑[i,j] ≈ ∑[j,i] for i in 1:D for j in 1:D if j>i])
# Make it perfectly symmetrical
[∑[i,j] = ∑[j,i] for i in 1:D for j in 1:D if j>i]
# Sylvester's criterion of positive semidefinite matrices
@assert all([det(∑[1:size,1:size]) > 0 for size in 1:D])

# The data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µ, ∑);

matR = DataFrame(rand(distrib, NR)')

mkpath(outDir)
CSV.write(outDir*"matR.csv", matR; delim=",", writeheader = false)


"""
## Dataset 2 - Negative control N
This is generated with the same generator as the positive control
"""

Random.seed!(2);

matN = DataFrame(rand(distrib, N)')

CSV.write(outDir*"matN.csv", matN; delim=",", writeheader = false)

"""
## Dataset 3 - Positive control (shifted) PS
"""

Random.seed!(3);

# The reference is not centered on 0 anymore
distrib = Normal(0, 0.5*posScaling)
µmod = rand(distrib, D)

# The data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µmod, ∑);

matPS = DataFrame(rand(distrib, N)')

CSV.write(outDir*"matPS.csv", matPS; delim=",", writeheader = false)

"""
## Dataset 4 - Positive control (reshaped) PR
This is generated with a covariance increased in all direction, so the reshaped data is more spread than reference.
"""

Random.seed!(4);

# We increase the variation in all direction
∑mod = ∑^(1+posScaling)

# Check that the matrix is symmetrical (up to machine error)
@assert all([∑mod[i,j] ≈ ∑mod[j,i] for i in 1:D for j in 1:D if j>i])
# Make it perfectly symmetrical
if !(∑mod isa Symmetric)
    [∑mod[i,j] = ∑mod[j,i] for i in 1:D for j in 1:D if j>i]
end
# Sylvester's criterion of positive semidefinite matrices
@assert all([det(∑mod[1:size,1:size]) > 0 for size in 1:D])

# The data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µ, ∑mod);

matPR = DataFrame(rand(distrib, N)')

CSV.write(outDir*"matPR.csv", matPR; delim=",", writeheader = false)

"""
## Dataset 5 - Reference with outliers Ro
We add outliers from a different distribution to our reference set: In a morphological profiling, some outliers often result from technical artifacts (e.g. dye precipitation, bubbles) or biological confounders (e.g. cell cycle).
"""

Random.seed!(5);

# The reference still is centered (center µ)
# The outliers are not centered on 0 anymore
distrib = Normal(0, 1)
µOutliers = rand(distrib, D)

# The covariance of the outliers is similar but independent of the reference points
distrib = Gamma(1,2)
sigma_diagOutliers = rand(distrib, D);

# Now we transform this space by multiplying by a random orthogonal matrix
s = rand(D,D)
Q, R = qr(s);

# NB: becomes really slow, do not try with D > 500
∑Outliers = Q' * Diagonal(sigma_diagOutliers) * Q;

# Check that the matrix is symmetrical (up to machine error)
@assert all([∑Outliers[i,j] ≈ ∑Outliers[j,i] for i in 1:D for j in 1:D if j>i])
# Make it perfectly symmetrical
[∑Outliers[i,j] = ∑Outliers[j,i] for i in 1:D for j in 1:D if j>i]
# Sylvester's criterion of positive semidefinite matrices
@assert all([det(∑Outliers[1:size,1:size]) > 0 for size in 1:D])

# 80% of the data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µ, ∑);
distribOutliers = MvNormal(µOutliers, ∑Outliers);

matRo = DataFrame(hcat(rand(distrib, Int(round(NR*(1-pOutliers)))),
                      rand(distribOutliers, Int(round(NR*pOutliers))))')

CSV.write(outDir*"matRo.csv", matRo; delim=",", writeheader = false)

"""
## Dataset 6 - Negative control with outliers No
This is generated with the same generator as the positive control
"""

Random.seed!(6);

matNo = DataFrame(hcat(rand(distrib, Int(round(N*(1-pOutliers)))),
                      rand(distribOutliers, Int(round(N*pOutliers))))')

CSV.write(outDir*"matNo.csv", matNo; delim=",", writeheader = false)

"""
## Dataset 7 - Positive control (shifted) with outliers PSo
"""

Random.seed!(7);

# The data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µmod, ∑);

matPSo = DataFrame(hcat(rand(distrib, Int(round(N*(1-pOutliers)))),
                        rand(distribOutliers, Int(round(N*pOutliers))))')

CSV.write(outDir*"matPSo.csv", matPSo; delim=",", writeheader = false)

"""
## Dataset 8 - Positive control (reshaped) with outliers PRo
"""

Random.seed!(8);

# The data will follow a multivariate normal distribution with the parameters
# we generated previously
distrib = MvNormal(µ, ∑mod);

matPRo = DataFrame(hcat(rand(distrib, Int(round(N*(1-pOutliers)))),
                        rand(distribOutliers, Int(round(N*pOutliers))))')

CSV.write(outDir*"matPRo.csv", matPRo; delim=",", writeheader = false)
