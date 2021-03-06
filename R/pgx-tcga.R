ARCHS4.DIR = "~/.archs4data"

if(0) {

    BiocManager::install("TCGAbiolinks")



    ## See: https://cran.r-project.org/web/packages/TCGAretriever
    BiocManager::install("TCGAretriever")
    library(TCGAretriever)
    ## Define a set of genes of interest
    q_genes <- c("TP53", "MDM2", "E2F1", "EZH2")
    q_cases <- "brca_tcga_pub_complete"
    rna_prf <- "brca_tcga_pub_mrna"
    mut_prf <- "brca_tcga_pub_mutations"
    brca_RNA <- TCGAretriever::get_profile_data(case_id = q_cases, gprofile_id = rna_prf, glist = q_genes)
    head(brca_RNA[, 1:5])


    BiocManager::install("curatedTCGAData")
    BiocManager::install("TCGAutils")
    library(curatedTCGAData)
    library(MultiAssayExperiment)
    library(TCGAutils)
    (mae <- curatedTCGAData("DLBC", c("RNASeq2GeneNorm"), FALSE))
    ##(mae <- curatedTCGAData("DLBC", c("RNASeqGene", "Mutation"), FALSE))
    counts <- assays(mae)[[1]]
    dim(counts)

    genes = c('CD101','CD109','CD14','CD151','CD160','CD163','CD163L1','CD164','CD164L2','CD177')
    studies = c("prad_tcga","ov_tcga")
    
    keyword="brca"
    keyword="*"
    variables="^OS_|^EFS_|^DFS_"        
    pgx.TCGA.selectStudies("prad","^OS_|^EFS_|^DFS_")
    pgx.TCGA.selectStudies("*", "^OS_|^EFS_|^DFS_")


    library("rhdf5")
    library("preprocessCore")
    library("sva")    
    matrix_file = file.path(ARCHS4.DIR, "tcga_matrix.h5")
    file.exists(matrix_file)
    h5ls(matrix_file)[,1:2]
    
    slots <- apply(h5ls(matrix_file)[,1:2],1,paste,collapse="/")
    slots <- grep("^//",slots,value=TRUE,invert=TRUE)
    slots <- grep("meta",slots,value=TRUE)
    meta.heads <- lapply(slots, function(s) head(h5read(matrix_file,s)))
    names(meta.heads) <- slots
    
    ## Retrieve information from compressed data
    id1 = h5read(matrix_file, "/meta/gdc_cases.samples.portions.submitter_id")
    id2 = h5read(matrix_file, "/meta/gdc_cases.samples.submitter_id")
    id3 = h5read(matrix_file, "/meta/gdc_cases.submitter_id")        
}

cancertype="dlbc";variables="OS_"
pgx.TCGA.selectStudies <- function(cancertype, variables)
{
    ## Scan the available TCGA studies for cancertype and clinical
    ## variables.
    ##
    ##
    ##
    library(cgdsr)
    mycgds <- CGDS("http://www.cbioportal.org/")
    all.studies <- sort(getCancerStudies(mycgds)[,1])
    studies <- grep(cancertype, all.studies, value=TRUE)    
    clin <- list()
    samples <- list()
    studies
    mystudy <-  studies[1]

    for(mystudy in studies) {

        mystudy
        myprofiles <- getGeneticProfiles(mycgds,mystudy)[,1]
        myprofiles

        ## mrna datatypes
        mrna.type <- "rna_seq_mrna"
        if(any(grepl("v2_mrna$", myprofiles))) mrna.type <- "rna_seq_v2_mrna"
        pr.mrna <- grep( paste0(mrna.type,"$"), myprofiles,value=TRUE)
        pr.mrna
        if(length(pr.mrna)==0) next()
        
        all.cases <- getCaseLists(mycgds,mystudy)[,1]
        all.cases
        ##if(!any(grepl("complete$",all.cases))) next        
        ##caselist <- grep("complete$",all.cases,value=TRUE)
        caselist <- grep(paste0(mrna.type,"$"),all.cases,value=TRUE)
        caselist
        clin0 <- getClinicalData(mycgds, caselist)
        clin[[mystudy]] <- clin0
        samples[[mystudy]] <- gsub("[.]","-",rownames(clin0))
    }
    
    sel <- sapply(clin, function(v) any(grepl(variables,colnames(v))))
    sel
    sel.studies <- studies[sel]
    sel.clin    <- clin[sel]
    
    res <- list(
        studies = sel.studies,
        ##samples = sel.samples,
        clinicalData = sel.clin
    )
    return(res)
}

genes=NULL
pgx.TCGA.getExpression <- function(study, genes=NULL)
{
    ## For a specific TCGA study get the expression matrix and
    ## clinical data.
    ##
    
    ##BiocManager::install("cgdsr")    
    library(cgdsr)
    mycgds <- CGDS("http://www.cbioportal.org/")

    ## Gather data from all study
    X <- list()
    clin <- list()
    mystudy <-  study[1]
    for(mystudy in study) {

        cat("getting TCGA expression for",mystudy,"...\n")
        
        mystudy
        ##myprofiles = "ov_tcga_rna_seq_v2_mrna"        
        myprofiles <- getGeneticProfiles(mycgds,mystudy)[,1]
        myprofiles

        ## mrna datatypes
        mrna.type <- "rna_seq_mrna"
        if(any(grepl("v2_mrna$", myprofiles))) mrna.type <- "rna_seq_v2_mrna"
        pr.mrna <- grep( paste0(mrna.type,"$"), myprofiles,value=TRUE)
        pr.mrna
        if(length(pr.mrna)==0) next()
        
        all.cases <- getCaseLists(mycgds,mystudy)[,1]
        all.cases
        ##if(!any(grepl("complete$",all.cases))) next        
        ##caselist <- grep("complete$",all.cases,value=TRUE)
        caselist <- grep(paste0(mrna.type,"$"),all.cases,value=TRUE)
        caselist
        samples <- NULL
        head(genes)
        if(!is.null(genes)) {
            ## If only a few genes, getProfileData is a faster way
            ##
            expression <- t(getProfileData(mycgds, genes, pr.mrna, caselist))
            samples <- gsub("[.]","-",colnames(expression))
            colnames(expression) <- samples            
            dim(expression)
        } else {
            ## For all genes, getProfileData cannot do and we use
            ## locally stored H5 TCGA data file from Archs4.
            ##
            xx <- getProfileData(mycgds, "---", pr.mrna, caselist)
            samples <- gsub("[.]","-",colnames(xx))[3:ncol(xx)]
            head(samples)

            library("rhdf5")
            library("preprocessCore")
            h5closeAll()
            matrix_file = file.path(ARCHS4.DIR, "tcga_matrix.h5")
            has.h5 <- file.exists(matrix_file)
            has.h5
            
            if(!has.h5) {
                stop("FATAL: could not find tcga_matrix.h5 matrix. Please download from Archs4.")
            } else {
                ## Retrieve information from locally stored H5 compressed data            
                h5ls(matrix_file)[,1:2]            
                id1 = h5read(matrix_file, "/meta/gdc_cases.samples.portions.submitter_id")
                id2 = h5read(matrix_file, "/meta/gdc_cases.samples.submitter_id")
                id3 = h5read(matrix_file, "/meta/gdc_cases.submitter_id")    
                id2x <- substring(id2,1,15)
                
                h5.genes = h5read(matrix_file, "/meta/genes")            
                samples = intersect(samples, id2x)
                sample_index <- which(id2x %in% samples)
                gene_index <- 1:length(h5.genes)            
                expression = h5read(
                    matrix_file, "data/expression",
                    index = list(gene_index, sample_index)
                )
                H5close()
                dim(expression)
                colnames(expression) <- substring(id2[sample_index],1,15)
                rownames(expression) <- h5.genes
                expression <- expression[,order(-colSums(expression))]
                expression <- expression[,samples]
            }
            
        }
        dim(expression)
        this.clin <- getClinicalData(mycgds, caselist)
        rownames(this.clin) <- gsub("[.]","-",rownames(this.clin))
        this.clin <- this.clin[samples,,drop=FALSE]
        expression <- expression[,samples,drop=FALSE]
        X[[mystudy]] <- expression
        clin[[mystudy]] <- this.clin
    }


    res <- list(X=X, clin=clin)
    return(res)
}


pgx.getTCGA.multiomics.TOBEFINISHED <- function(studies, genes=NULL, batch.correct=TRUE,
                                                tcga.only=TRUE )
{
    ## Better use curatedTCGA bioconductor package!!!!
    ##
    
    ##BiocManager::install("cgdsr")    
    library(cgdsr)
    mycgds <- CGDS("http://www.cbioportal.org/")
    if(0) {
        all.studies <- sort(getCancerStudies(mycgds)[,1])
        tcga.studies <- grep("_tcga$",all.studies, value=TRUE)
        all.studies <- tcga.studies
        all.studies
        mystudy <- "ov_tcga"
        mystudy <- "brca_tcga"
        mystudy <- "thca_tcga"
    }
    ## all.profiles <- list()
    ## for(mystudy in all.studies) {    
    ##     myprofiles <- getGeneticProfiles(mycgds,mystudy)[,1]
    ##     all.profiles[[mystudy]] <- myprofiles
    ## }

    GENE = "CIITA"
    GENE = "NLRC5"

    ## Gather data from all cancers
    all.X <- list()
    mystudy <-  studies[1]
    for(mystudy in studies) {
        mystudy
        ##myprofiles = "ov_tcga_rna_seq_v2_mrna"        
        myprofiles <- getGeneticProfiles(mycgds,mystudy)[,1]
        myprofiles

        ## prioritize datatypes
        pr.mrna <- grep("rna_seq_v2_mrna$|rna_seq_mrna$",myprofiles,value=TRUE)[1]
        ## pr.prot <- paste0(mystudy,"_protein_quantification")
        pr.cna <- grep("_log2CNA$|_linear_CNA$",myprofiles,value=TRUE)[1]
        pr.gistic <- grep("_gistic$",myprofiles,value=TRUE)[1]
        pr.me  <- grep("_methylation_hm450|_methylation_hm27",myprofiles,value=TRUE)[1]
        pr.mut <- grep("_mutations",myprofiles,value=TRUE)[1]    

        all.cases <- getCaseLists(mycgds,mystudy)[,1]
        all.cases
        if(!any(grepl("complete$",all.cases))) next
        
        caselist <- grep("complete$",all.cases,value=TRUE) 
        cna=counts=cna.gistic=me=mut=gx=NULL    
        counts <- getProfileData(mycgds, genes, pr.mrna, caselist)
        cna    <- getProfileData(mycgds, GENE, pr.cna, caselist)
        ##prot <- getProfileData(mycgds, GENE, pr.prot, caselist)
        cna.gistic <- getProfileData(mycgds, GENE, pr.gistic, caselist)
        me   <- getProfileData(mycgds, GENE, pr.me, caselist)
        mut  <- getProfileData(mycgds, GENE, pr.mut, caselist)
        mut  <- 1*!is.na(mut)
        gx   <- log2(10 + as.matrix(counts))
        cna[is.na(cna)] <- NA
        if(grepl("linear",pr.cna)) cna <- log2(0.01 + 2 + cna)  ## assume diploid
    
        ##colnames(counts) <- paste0("GX:",colnames(counts))
        if(!is.null(cna)) colnames(cna) <- paste0("CN:",colnames(cna))
        if(!is.null(cna.gistic)) colnames(cna.gistic) <- paste0("CNA:",colnames(cna.gistic))
        if(!is.null(me))  colnames(me) <- paste0("ME:",colnames(me))
        if(!is.null(mut)) colnames(mut) <- paste0("MT:",colnames(mut))
        ##colnames(prot) <- paste0("PX:",colnames(prot))
        
        ##xx <- list(gx, cna, cna.gistic, me, mut)
        xx <- list(gx, cna.gistic, me, mut)
        xx <- xx[sapply(xx,nrow)>0]    
        X <- do.call(cbind, xx)
        dim(X)
        
        if(!is.null(X) && ncol(X)>=4 ) {
            X <- X[,colMeans(is.na(X)) < 0.5,drop=FALSE]
            X <- X[rowMeans(is.na(X)) < 0.5,,drop=FALSE]
            dim(X)
            all.X[[mystudy]] <- X
        }        
    }
}
