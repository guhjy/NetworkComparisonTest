NCT_bootnet <- function(object1, object2, it = 100, paired=FALSE, weighted=TRUE, AND=TRUE, test.edges=FALSE, edges, progressbar=TRUE){ 
  
  data1 <- object1$data
  data2 <- object2$data
  
  # Some extra stuff of Sacha:
  # If 'edges' is missing, default to all possible edges:
  if (isTRUE(test.edges) && missing(edges)){
    combs <- t(combn(1:ncol(data1),2))
    edges <- list()
    for (i in 1:nrow(combs)){
      edges[[i]] <- combs[i,]
    }
  }
  
  #### June 13 2017
  #### Note that the use of cor_auto in combination with NCT is not validated
  #### When treating the data as ordinal, you assume that the data comes from a normal distribution and is thresholded into ordinal categories. When using that in NCT, you make the additional assumption that the thresholding is similar in both groups. It is the question whether this is a plausible assumption. If you do not want to assume this, you might want to treat the data as normal in the ordinary NCT. 
  if (progressbar==TRUE) pb <- txtProgressBar(max=it, style = 3)
  x1 <- data1
  x2 <- data2
  nobs1 <- nrow(x1)
  nobs2 <- nrow(x2)
  dataall <- rbind(x1,x2)
  data.list <- list(x1,x2)
  b <- 1:(nobs1+nobs2)
  nvars <- ncol(x1)
  nedges <- nvars*(nvars-1)/2
  
  glstrinv.perm <- glstrinv.real <- nwinv.real <- nwinv.perm <- c()
  diffedges.perm <- matrix(0,it,nedges) 
  diffedges.permtemp <- matrix(0, nvars, nvars)
  einv.perm.all <- array(NA,dim=c(nvars, nvars, it))
  edges.pval.HBall <- matrix(NA,nvars,nvars)
  edges.pvalmattemp <- matrix(0,nvars,nvars)
  
  #####################################
  ### procedure for estimateNetwork objects ###
  #####################################
  ## Real data
  nw1 <- object1$graph
  nw2 <- object2$graph
  if(weighted==FALSE){
    nw1=(nw1!=0)*1
    nw2=(nw2!=0)*1
  }
  
  ##### Invariance measures #####
  
  ## Global strength invariance
  glstrinv.real <- abs(sum(abs(nw1[upper.tri(nw1)]))-sum(abs(nw2[upper.tri(nw2)])))
  # global strength of individual networks
  glstrinv.sep <- c(sum(abs(nw1[upper.tri(nw1)])), sum(abs(nw2[upper.tri(nw2)])))
  
  ## Individual edge invariance
  diffedges.real <- abs(nw1-nw2)[upper.tri(abs(nw1-nw2))] 
  diffedges.realmat <- matrix(diffedges.real,it,nedges,byrow=TRUE)
  diffedges.realoutput <- abs(nw1-nw2)
  
  ## Network structure invariance
  nwinv.real <- max(diffedges.real)
  
  
  ## permuted data
  for (i in 1:it)
  {
    if(paired==FALSE)
    {
      s <- sample(1:(nobs1+nobs2),nobs1,replace=FALSE)
      x1perm <- dataall[s,]
      x2perm <- dataall[b[-s],]
      # r1perm <- EBICglasso(cor_auto(x1perm, verbose=FALSE),nrow(x1perm),gamma=gamma)
      # r2perm <- EBICglasso(cor_auto(x2perm, verbose=FALSE),nrow(x2perm),gamma=gamma)
      args1 <- c(list(x1perm),object1$arguments)
      args1$verbose <- FALSE
      r1perm <- do.call(object1$estimator,args1)
      
      args2 <- c(list(x2perm),object2$arguments)
      args2$verbose <- FALSE
      r2perm <- do.call(object2$estimator,args2)
      
      if (is.list(r1perm)){
        r1perm <- r1perm$graph
      }
      if (is.list(r2perm)){
        r2perm <- r2perm$graph
      }
      if(weighted==FALSE){
        r1perm=(r1perm!=0)*1
        r2perm=(r2perm!=0)*1
      }
    }
    
    if(paired==TRUE)
    {
      s <- sample(c(1,2),nobs1,replace=TRUE)
      x1perm <- x1[s==1,]
      x1perm <- rbind(x1perm,x2[s==2,])
      x2perm <- x2[s==1,]
      x2perm <- rbind(x2perm,x1[s==2,])
      args1 <- c(list(x1perm),object1$arguments)
      args1$verbose <- FALSE
      r1perm <- do.call(object1$estimator,args1)
      
      args2 <- c(list(x2perm),object2$arguments)
      args2$verbose <- FALSE
      r2perm <- do.call(object2$estimator,args2)
      
      if (is.list(r1perm)){
        r1perm <- r1perm$graph
      }
      if (is.list(r2perm)){
        r2perm <- r2perm$graph
      }
      if(weighted==FALSE){
        r1perm=(r1perm!=0)*1
        r2perm=(r2perm!=0)*1
      }
    }
    
    ## Invariance measures for permuted data
    glstrinv.perm[i] <- abs(sum(abs(r1perm[upper.tri(r1perm)]))-sum(abs(r2perm[upper.tri(r2perm)])))
    diffedges.perm[i,] <- abs(r1perm-r2perm)[upper.tri(abs(r1perm-r2perm))]
    diffedges.permtemp[upper.tri(diffedges.permtemp, diag=FALSE)] <- diffedges.perm[i,]
    diffedges.permtemp <- diffedges.permtemp + t(diffedges.permtemp)
    einv.perm.all[,,i] <- diffedges.permtemp
    nwinv.perm[i] <- max(diffedges.perm[i,])
    
    if (progressbar==TRUE) setTxtProgressBar(pb, i)
  }
  
  if(test.edges==TRUE)
  {
    # vector with uncorrected p values
    edges.pvaltemp <- colSums(diffedges.perm >= diffedges.realmat)/it 
    # matrix with uncorrected p values
    edges.pvalmattemp[upper.tri(edges.pvalmattemp,diag=FALSE)] <- edges.pvaltemp
    edges.pvalmattemp <- edges.pvalmattemp + t(edges.pvalmattemp)
    
    if(is.character(edges))
    {
      ept.HBall <- p.adjust(edges.pvaltemp, method='holm')
      # matrix with corrected p values
      edges.pval.HBall[upper.tri(edges.pval.HBall,diag=FALSE)] <- ept.HBall 
      rownames(edges.pval.HBall) <- colnames(edges.pval.HBall) <- colnames(data1)
      einv.pvals <- melt(edges.pval.HBall, na.rm=TRUE, value.name = 'p-value')
      einv.perm <- einv.perm.all
      einv.real <- diffedges.realoutput
    }
    
    if(is.list(edges))
    {
      einv.perm <- matrix(NA,it,length(edges))
      colnames(einv.perm) <- edges
      uncorrpvals <- einv.real <- c()
      for(j in 1:length(edges))
      {
        uncorrpvals[j] <- edges.pvalmattemp[edges[[j]][1],edges[[j]][2]]
        einv.real[j] <- diffedges.realoutput[edges[[j]][1],edges[[j]][2]]
        for(l in 1:it){
          einv.perm[l,j] <- einv.perm.all[,,l][edges[[j]][1],edges[[j]][2]]
        }
      }
      HBcorrpvals <- p.adjust(uncorrpvals, method='holm')
      einv.pvals <- HBcorrpvals
    }
    
    edges.tested <- colnames(einv.perm)
    
    res <- list(glstrinv.real = glstrinv.real,
                glstrinv.sep = glstrinv.sep,
                glstrinv.pval = sum(glstrinv.perm >= glstrinv.real)/it, 
                glstrinv.perm = glstrinv.perm,
                nwinv.real = nwinv.real,
                nwinv.pval = sum(nwinv.perm >= nwinv.real)/it, 
                nwinv.perm = nwinv.perm,
                edges.tested = edges.tested,
                einv.real = einv.real,
                einv.pvals = einv.pvals,
                einv.perm = einv.perm)
  }
  
  if (progressbar==TRUE) close(pb)
  
  if(test.edges==FALSE) 
  {
    res <- list(
      glstrinv.real = glstrinv.real, 
      glstrinv.sep = glstrinv.sep,
      glstrinv.pval = sum(glstrinv.perm >= glstrinv.real)/it, 
      glstrinv.perm = glstrinv.perm,
      nwinv.real = nwinv.real,
      nwinv.pval = sum(nwinv.perm >= nwinv.real)/it,
      nwinv.perm = nwinv.perm
    )
  }
  
  
  class(res) <- "NCT"
  return(res)
}