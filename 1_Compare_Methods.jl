#!/usr/bin/julia
# -*- coding: utf-8 -*-

#################################### Help ###################################

doc = """Compares the ability of different approaches to quantify and identify significant changes in statistical distributions of samples, corresponding to synthetic datasets having similarities to actual morphological measurement datasets from high-content imaging and including outliers.  
See 1_Compare_Methods.ipynb for a more verbose description of this script.
Author: Loan Vulliard @ Menche Lab, CeMM.

Usage:
  1_Compare_Methods.jl [-r <repetitions>  -d <dimensions>  -f <inputFolder> -o <outliers> -c <maxCorrelation>]
  1_Compare_Methods.jl --help

Options:
  -r --rep=<repetitions>         Minimum number of iterations for empirical p-values [default: 10]
  -d --dim=<dimensionUMAP>       Number of reduced dimensions on UMAP [default: 10]
  -f --folder=<inputFolder>      Where datasets are read and outputs are saved [default: Data/]
  -o --outliers=<outliers>       Proceed with clean (false) or noisy data (true) [default: true]
  -c --corr=<maxCorrelation>     Filter features correlated below this threshold [default: 0.6]
  -h --help                      Show this screen.
"""

################################## Import #################################

using CSV, StatsBase, Statistics, DataFrames, UMAP, RCall
using Distributed, RMP, Random, DocOpt
using MultivariateStats, MultipleTesting
using Dates: now

R"""
# Used later for MCD computation

library(robustbase)
"""

args = docopt(doc, version=v"1.0.0")

PROCESS_DATA_WITH_OUTLIERS = parse(Bool, args["--outliers"])
dataDir = args["--folder"]
FILT_MAX_CORR = parse(Float64, args["--corr"]) # Keep uncorrelated variables
dimUMAP = parse(Int, args["--dim"])
minNbRep = parse(Int, args["--rep"])

if PROCESS_DATA_WITH_OUTLIERS
    R = CSV.read(dataDir*"matRo.csv", header = false) # Reference
    N = CSV.read(dataDir*"matNo.csv", header = false) # Negative control
    PS = CSV.read(dataDir*"matPSo.csv", header = false) # Shifted
    PR = CSV.read(dataDir*"matPRo.csv", header = false) # Rescaled
else
    R = CSV.read(dataDir*"matR.csv", header = false) # Reference
    N = CSV.read(dataDir*"matN.csv", header = false) # Negative control
    PS = CSV.read(dataDir*"matPS.csv", header = false) # Shifted
    PR = CSV.read(dataDir*"matPR.csv", header = false) # Rescaled
end;

dataset = vcat(R, N, PS, PR)

# Remember how these records were generated
origDataset = vcat(repeat(["Reference"], size(R, 1)),
                   repeat(["Negative control"], size(N, 1)),
                   repeat(["Shifted control"], size(PS, 1)),
                   repeat(["Rescaled control"], size(PR, 1)))


################################# Functions #################################

""" Compute the Mahalanobis Distance to center (MDC)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef'."""
function MDC(data, iPert, iRef)
    setPert = Matrix(data[iPert,:])
    setRef = Matrix(data[iRef,:])

    mdCenter = dropdims(mean(setRef, dims = 1), dims = 1)
    mdCov = cov(setRef)

    pertCenter = dropdims(mean(setPert, dims = 1), dims = 1)
    
    MD = mahalanobis(pertCenter, mdCenter, mdCov)
    
    return(MD)
end

""" Permute labels and compute the Mahalanobis Distance to center (MDC)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef', to create an empirical distribution."""
function shuffMDC(data, iPert, iRef; nbRep = 250)
    setPert = data[iPert,:]
    setRef = data[iRef,:]  
    set = Matrix(vcat(setRef, setPert))
    
    function iterShufMD()
        nset = size(set, 1)
        shuffSet = set[sample(1:nset, nset; replace = false),:]
        # Take random subsets of corresponding sizes
        shuffSetPert = shuffSet[1:nrow(setPert),:]
        shuffSetRef = shuffSet[(nrow(setPert)+1):(nrow(setPert)+nrow(setRef)),:]

        # Compute Mahalanobis Distance
        
        mdCenter = dropdims(mean(shuffSetRef, dims = 1), dims = 1)
        mdCov = cov(shuffSetRef)
        
        pertCenter = dropdims(mean(shuffSetPert, dims = 1), dims = 1)
    
        MD = mahalanobis(pertCenter, mdCenter, mdCov)
        return(MD)
    end       
    
    return(map(x -> iterShufMD(), 1:nbRep))
end

""" Compute the median Mahalanobis Distance (MD)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef'."""
function MD(data, iPert, iRef)
    setPert = data[iPert,:]
    setRef = Matrix(data[iRef,:])

    mdCenter = dropdims(mean(setRef, dims = 1), dims = 1)
    mdCov = cov(setRef)
    
    MD = median(map(x -> mahalanobis(x, mdCenter, mdCov), eachrow(setPert)))
    return(MD)
end

""" Permute labels and compute the median Mahalanobis Distance (RMD)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef', to create an empirical distribution."""
function shuffMD(data, iPert, iRef; nbRep = 250)
    setPert = data[iPert,:]
    setRef = data[iRef,:]  
    set = Matrix(vcat(setRef, setPert))
    
    function iterShufMD()
        nset = size(set, 1)
        shuffSet = set[sample(1:nset, nset; replace = false),:]
        # Take random subsets of corresponding sizes
        shuffSetPert = shuffSet[1:nrow(setPert),:]
        shuffSetRef = shuffSet[(nrow(setPert)+1):(nrow(setPert)+nrow(setRef)),:]

        # Compute Mahalanobis Distance
        
        mdCenter = dropdims(mean(shuffSetRef, dims = 1), dims = 1)
        mdCov = cov(shuffSetRef)

        MD = median(map(x -> mahalanobis(x, mdCenter, mdCov), eachrow(DataFrame(shuffSetPert))))
        return(MD)
    end       
    
    return(map(x -> iterShufMD(), 1:nbRep))
end

""" Compute the median Robust Mahalanobis Distance (RMD)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef'.
    See https://e-archivo.uc3m.es/bitstream/handle/10016/24613/ws201710.pdf """
function RMD(data, iPert, iRef)
    setPert = data[iPert,:]
    setRef = data[iRef,:] 

    # Ensure that we have enough points to compute distance
    if ((size(setPert)[1] < 2*size(data, 2))|(size(setRef)[1] < 2*size(data, 2)))
        return(missing)
    end
    # NB: having less points than twice the number of dimensions leads to singularity
    
    # Compute Minimum Covariance Determinant and corresponding Robust Mahalanobis Distance
    @rput setRef

    R"""
    set.seed(3895)
    mcd <- covMcd(setRef)
    mcdCenter <- mcd$center
    mcdCov <- mcd$cov
    """
    @rget mcdCenter
    @rget mcdCov
    
    RMD = median(map(x -> mahalanobis(x, mcdCenter, mcdCov), eachrow(setPert)))
    return(RMD)
end

""" Permute labels and compute the median Robust Mahalanobis Distance (RMD)
    in a dataset 'data' for a given perturbation of indices 'iPert' 
    compared to a reference of indices 'iRef', to create an empirical distribution."""
function shuffRMD(data, iPert, iRef; nbRep = 250)
    setPert = data[iPert,:]
    setRef = data[iRef,:]  
    set = vcat(setRef, setPert)
    
    # Ensure that we have enough points to compute distance
    if ((size(setPert)[1] < 2*size(data, 2))|(size(setRef)[1] < 2*size(data, 2)))
        return(repeat([missing], nbRep))
    end
    # NB: having less points than twice the number of dimensions leads to singularity
    
    function iterShufRMD()
        shuffSet = set[sample(1:nrow(set), nrow(set); replace = false),:]
        # Take random subsets of corresponding sizes
        shuffSetPert = shuffSet[1:nrow(setPert),:]
        shuffSetRef = shuffSet[(nrow(setPert)+1):(nrow(setPert)+nrow(setRef)),:]

        # Compute Minimum Covariance Determinant and corresponding Robust Mahalanobis Distance
        @rput shuffSetRef
        
        R"""
        set.seed(3895)
        mcd <- covMcd(shuffSetRef)
        mcdCenter <- mcd$center
        mcdCov <- mcd$cov
        """
        @rget mcdCenter
        @rget mcdCov

        RMD = median(map(x -> mahalanobis(x, mcdCenter, mcdCov), eachrow(shuffSetPert)))
        return(RMD)
    end       
    
    return(map(x -> iterShufRMD(), 1:nbRep))
end

""" Compute the Robust Hellinger Distance (RHD)
    in a dataset `data` for a given perturbation of indices `iPert` 
    compared to a reference of indices `iRef`."""
function RHD(data, iPert, iRef)
    setPert = data[iPert,:]
    setRef = data[iRef,:] 

    # Ensure that we have enough points to compute distance
    if ((size(setPert)[1] < 2*size(data, 2))|(size(setRef)[1] < 2*size(data, 2)))
        return(missing)
    end
    # NB: having less points than twice the number of dimensions leads to singularity
    
    # Compute Minimum Covariance Determinant and corresponding Robust Hellinger Distance
    @rput setRef
    @rput setPert

    R"""
    set.seed(3895)
    mcd1 <- covMcd(setRef)
    mcdCenter1 <- mcd1$center
    mcdCov1 <- mcd1$cov
    
    # We set the seed twice to always
    # find the same estimators given
    # the same sample
    set.seed(3895)
    mcd2 <- covMcd(setPert)
    mcdCenter2 <- mcd2$center
    mcdCov2 <- mcd2$cov
    """
    @rget mcdCenter1
    @rget mcdCov1
    @rget mcdCenter2
    @rget mcdCov2
    
    RHD = hellinger(mcdCenter1, mcdCov1, mcdCenter2, mcdCov2)
    return(RHD)
end

""" Permute labels and compute the Robust Hellinger Distance (RHD)
    in a dataset `data` for a given perturbation of indices `iPert` 
    compared to a reference of indices `iRef`, to create an empirical distribution."""
function shuffRHD(data, iPert, iRef; nbRep = 250)
    setPert = data[iPert,:]
    setRef = data[iRef,:]  
    set = vcat(setRef, setPert)
    
    # Ensure that we have enough points to compute distance
    if ((size(setPert)[1] < 2*size(data, 2))|(size(setRef)[1] < 2*size(data, 2)))
        return(repeat([missing], nbRep))
    end
    # NB: having less points than twice the number of dimensions leads to singularity
    
    function iterShufRHD()
        shuffSet = set[sample(1:nrow(set), nrow(set); replace = false),:]
        # Take random subsets of corresponding sizes
        shuffSetPert = shuffSet[1:nrow(setPert),:]
        shuffSetRef = shuffSet[(nrow(setPert)+1):(nrow(setPert)+nrow(setRef)),:]

        # Compute Minimum Covariance Determinant and corresponding Robust Mahalanobis Distance
        @rput shuffSetRef
        @rput shuffSetPert
        
        R"""
        set.seed(3895)
        mcd <- covMcd(shuffSetRef)
        mcdCenter1 <- mcd$center
        mcdCov1 <- mcd$cov
        
        # We set the seed twice to always
        # find the same estimators given
        # the same sample
        set.seed(3895)
        mcd <- covMcd(shuffSetPert)
        mcdCenter2 <- mcd$center
        mcdCov2 <- mcd$cov
        """
        @rget mcdCenter1
        @rget mcdCov1        
        @rget mcdCenter2
        @rget mcdCov2
        

        RHD = hellinger(mcdCenter1, mcdCov1, mcdCenter2, mcdCov2)
        return(RHD)
    end       
    
    return(map(x -> iterShufRHD(), 1:nbRep))
end


################################# Analysis #################################

# Used to store results
benchmarkRMPV = DataFrame(R = Float64[], N = Float64[], PS = Float64[], PR = Float64[])

# Center and scale on control values
indRef = origDataset .== "Reference"
normDataset = DataFrame(map(x -> normtransform(x, x[indRef]), eachcol(dataset)))

# Order features from biggest mad to smallest mad
# Since features have mad(reference) = 1, it means that we rank features by how more variable they are
# for all conditions compared to the reference
orderFt = sortperm(convert(Array, map(x -> mad(x, normalize = true), eachcol(normDataset))), rev=true)

uncorrFt = decorrelate(normDataset, orderCol = orderFt, threshold = FILT_MAX_CORR)
normDataset = normDataset[uncorrFt]


################################## UMAP ####################################

# Run UMAP with multiple dimensions (to preserve more of the total information)
Random.seed!(3895)
umND = umap(convert(Matrix, normDataset)', dimUMAP; min_dist = 1, spread = 10, n_epochs = 200)
umND = convert(DataFrame, umND')
names!(umND, Symbol.(string.("UMAP", 1:dimUMAP)))

umND[:Condition] = origDataset


# Actual observed MD to center
allMDC = map(x -> MDC(umND[:,1:dimUMAP], umND.Condition.==x, umND.Condition.=="Reference"), unique(umND.Condition))

@time allShuffMDC = map(x -> shuffMDC(umND[:,1:dimUMAP], umND.Condition .== x, 
                        umND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMDC))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMDC, allShuffMDC)], BenjaminiHochberg())
plateRMPV[:MD] = allMDC
plateRMPV[:Condition] = unique(umND.Condition);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed MD
allMD = map(x -> MD(umND[:,1:dimUMAP], umND.Condition.==x, umND.Condition.=="Reference"), unique(umND.Condition))

@time allShuffMD = map(x -> shuffMD(umND[:,1:dimUMAP], umND.Condition .== x, 
                        umND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMD))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMD, allShuffMD)], BenjaminiHochberg())
plateRMPV[:MD] = allMD
plateRMPV[:Condition] = unique(umND.Condition);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RMD
allRMD = map(x -> RMD(umND[:,1:dimUMAP], umND.Condition.==x, umND.Condition.=="Reference"), unique(umND.Condition))

@time allShuffRMD = map(x -> shuffRMD(umND[:,1:dimUMAP], umND.Condition .== x, 
                        umND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRMD))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRMD, allShuffRMD)], BenjaminiHochberg())
plateRMPV[:RMD] = allRMD
plateRMPV[:Condition] = unique(umND.Condition);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RHD
allRHD = map(x -> RHD(umND[:,1:dimUMAP], umND.Condition.==x, umND.Condition.=="Reference"), unique(umND.Condition))

@time allShuffRHD = map(x -> shuffRHD(umND[:,1:dimUMAP], umND.Condition .== x, 
                        umND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRHD))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRHD, allShuffRHD)], BenjaminiHochberg())
plateRMPV[:RHD] = allRHD
plateRMPV[:Condition] = unique(umND.Condition)

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);



################################## PCA ####################################

Random.seed!(3895)
modelPCA = fit(PCA, convert(Matrix, normDataset)'; pratio = 0.9)
dimPCA = outdim(modelPCA)
pcaND = MultivariateStats.transform(modelPCA, convert(Matrix, normDataset)')
pcaND = convert(DataFrame, pcaND')
# Scale by importance of each principal component
pcaND = DataFrame(principalvars(modelPCA) .* eachcol(pcaND))
names!(pcaND, Symbol.(string.("PC", 1:dimPCA)))

pcaND[:Condition] = origDataset

# Actual observed MD to center
allMDCpca = map(x -> MDC(pcaND[:,1:dimPCA], pcaND.Condition.==x,
             pcaND.Condition.=="Reference"), unique(pcaND.Condition))

@time allShuffMDCpca = map(x -> shuffMDC(pcaND[:,1:dimPCA], pcaND.Condition .== x, 
                        pcaND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(pcaND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMDCpca))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMDCpca, allShuffMDCpca)], BenjaminiHochberg())
plateRMPV[:MD] = allMDCpca
plateRMPV[:Condition] = unique(pcaND.Condition);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed MD
allMDpca = map(x -> MD(pcaND[:,1:dimPCA], pcaND.Condition.==x, 
                       pcaND.Condition.=="Reference"), unique(pcaND.Condition))

@time allShuffMDpca = map(x -> shuffMD(pcaND[:,1:dimPCA], pcaND.Condition .== x, 
                        pcaND.Condition .== "Reference", nbRep = 10*minNbRep), 
    unique(pcaND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMDpca))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMDpca, allShuffMDpca)], BenjaminiHochberg())
plateRMPV[:MD] = allMDpca
plateRMPV[:Condition] = unique(umND.Condition);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RMD
allRMDpca = map(x -> RMD(pcaND[:,1:dimPCA], pcaND.Condition.==x, 
                pcaND.Condition.=="Reference"), unique(pcaND.Condition))

@time allShuffRMDpca = map(x -> shuffRMD(pcaND[:,1:dimPCA], pcaND.Condition .== x, 
                        pcaND.Condition .== "Reference", nbRep = minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRMDpca))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRMDpca, allShuffRMDpca)], BenjaminiHochberg())
plateRMPV[:RHD] = allRMDpca
plateRMPV[:Condition] = unique(pcaND.Condition)

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RHD
allRHDpca = map(x -> RHD(pcaND[:,1:dimUMAP], pcaND.Condition.==x, pcaND.Condition.=="Reference"),
                unique(pcaND.Condition))

@time allShuffRHDpca = map(x -> shuffRHD(pcaND[:,1:dimPCA], pcaND.Condition .== x, 
                        pcaND.Condition .== "Reference", nbRep = minNbRep), 
    unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRHDpca))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRHDpca, allShuffRHDpca)], BenjaminiHochberg())
plateRMPV[:RHD] = allRHDpca
plateRMPV[:Condition] = unique(pcaND.Condition)

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);


################################# Raw PCA ####################################

Random.seed!(3895)
dimRaw = size(normDataset, 2)

# Actual observed MD to center
allMDCraw = map(x -> MDC(normDataset, origDataset.==x,
                origDataset.=="Reference"), unique(origDataset))

@time allShuffMDCraw = map(x -> shuffMDC(normDataset, origDataset .== x, 
                        origDataset .== "Reference", nbRep = 10*minNbRep), unique(origDataset))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMDCraw))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMDCraw, allShuffMDCraw)], BenjaminiHochberg())
plateRMPV[:MD] = allMDCraw
plateRMPV[:Condition] = unique(origDataset);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed MD
allMDraw = map(x -> MD(normDataset, origDataset.==x,
                       origDataset.=="Reference"), unique(origDataset))

@time allShuffMDraw = map(x -> shuffMD(normDataset, origDataset .== x, 
                        origDataset .== "Reference", nbRep = 10*minNbRep), unique(origDataset))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allMDraw))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:MPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allMDraw, allShuffMDraw)], BenjaminiHochberg())
plateRMPV[:MD] = allMDraw
plateRMPV[:Condition] = unique(origDataset);

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RMD
allRMDraw = map(x -> RMD(normDataset, origDataset.==x, 
                origDataset.=="Reference"), unique(origDataset))

@time allShuffRMDraw = map(x -> shuffRMD(normDataset, origDataset .== x, 
                        origDataset .== "Reference", nbRep = minNbRep), unique(origDataset))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRMDraw))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRMDraw, allShuffRMDraw)], BenjaminiHochberg())
plateRMPV[:RMD] = allRMDraw
plateRMPV[:Condition] = unique(origDataset)

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Actual observed RHD
allRHDraw = map(x -> RHD(normDataset, origDataset.==x, origDataset.=="Reference"),
                unique(origDataset))

@time allShuffRHDraw = map(x -> shuffRHD(normDataset, origDataset .== x, 
                           origDataset .== "Reference", nbRep = minNbRep), unique(umND.Condition))

# Missing values need to be handled in real case applications
@assert !any(ismissing.(allRHDraw))

# Compute the Robust Morphological Perturbation Value
plateRMPV = DataFrame()
plateRMPV[:RMPV] = adjust([mean(obs .< sim) for (obs, sim) 
            in zip(allRHDraw, allShuffRHDraw)], BenjaminiHochberg())
plateRMPV[:RHD] = allRHDraw
plateRMPV[:Condition] = unique(origDataset)

# Compile results in DataFrame
@assert plateRMPV.Condition == ["Reference", "Negative control", "Shifted control", "Rescaled control"]
push!(benchmarkRMPV, plateRMPV[1]);

# Export results
outFile = dataDir*"Benchmark_Outliers_"*string(PROCESS_DATA_WITH_OUTLIERS)*".csv"
CSV.write(outFile, benchmarkRMPV)
