#' Simulation-based power estimation for poisson outcome multi-arm 
#' cluster-randomized trials.
#' 
#' This function uses iterative simulations to determine 
#' approximate power for multi-arm cluster-randomized controlled trials with 
#' count or poisson-distributed outcomes of interest. Users can modify a 
#' variety of parameters to suit the simulations to their desired 
#' experimental situation. This function validates the user's input and 
#' passes the necessary arguments to an internal function, which performs 
#' the simulations. This function returns the summary power values for 
#' each treatment arm.
#' 
#' Users must specify the desired number of simulations, number of subjects per 
#' cluster, number of clusters per treatment arm, group probabilities, and the 
#' between-cluster variance. Significance level, analytic method, progress 
#' updates, poor/singular fit override, and whether or not to return the 
#' simulated data may also be specified. The internal function can be called 
#' directly by the user to return the fitted models rather than the power 
#' summaries (see \code{?cps.ma.count.internal} for details).
#' 
#' Users can spread the simulated data 
#' generation and model fitting tasks across multiple cores using the 
#' \code{cores} argument. Users should expect that parallel computing may make 
#' model fitting faster than using a single core for more complicated models. 
#' For simpler models, users may prefer to use single thread computing 
#' (\code{cores}=1), as the processes involved in allocating memory and 
#' copying data across cores also may take some time. For time-savings, 
#' this function stops execution early if estimated power < 0.5 or more 
#' than 25\% of models produce a singular fit or non-convergence warning 
#' message, unless \code{poor.fit.override = TRUE}.
#' 
#' @param nsim Number of datasets to simulate; accepts integer (required).
#' @param nsubjects Number of subjects per cluster (required); accepts an 
#' integer if all are equal and \code{narms} and \code{nclusters} are provided. 
#' Alternately, the user can supply a list with one entry per arm if the 
#' cluster sizes are the same within the arm, or, if they are not the same 
#' within the arms, the user can supply a list of vectors where each vector 
#' represents an arm and each entry in the vector is the number of subjects 
#' per cluster.
#' @param narms Integer value representing the number of trial arms. 
#' @param family A string, either 'poisson' or 'neg.bin', indicating the 
#' distribution that should be used to simulate the data.
#' @param nclusters An integer or vector of integers representing the number 
#' of clusters in each arm.
#' @param counts Expected absolute treatment effect probabilities for each arm; 
#' accepts a scalar or a vector of length \code{narms} (required).
#' @param sigma_b_sq Between-cluster variance; accepts a vector of length 
#' \code{narms} (required).
#' @param alpha Significance level; default = 0.05.
#' @param all.sim.data Option to output list of all simulated datasets; 
#' default = FALSE.
#' @param method Analytical method, either Generalized Linear Mixed Effects 
#' Model (GLMM) or Generalized Estimating Equation (GEE). Accepts c('glmm', 
#' 'gee') (required); default = 'glmm'.
#' @param multi.p.method A string indicating the method to use for adjusting
#' p-values for multiple comparisons. Choose one of "holm", "hochberg", 
#' "hommel", "bonferroni", "BH", "BY", "fdr", "none". The default is 
#' "bonferroni". See \code{?p.adjust} for additional details.
#' @param quiet When set to FALSE, displays simulation progress and estimated completion time; default is FALSE.
#' @param seed Option to set.seed. Default is NULL.
#' @param poor.fit.override Option to override \code{stop()} if more than 25\% of fits fail to converge or 
#' power<0.5 after 50 iterations; default = FALSE.
#' @param cores String ("all"), NA, or scalar value indicating the number of cores 
#' to be used for parallel computing. Default = NA (no parallel computing).
#' @param tdist Logical value indicating whether simulated data should be 
#' drawn from a t-distribution rather than the normal distribution. 
#' Default = FALSE.
#' @return A list with the following components:
#' \describe{
#'   \item{power}{Data frame with columns "power" (Estimated statistical power), 
#'                "lower.95.ci" (Lower 95\% confidence interval bound), 
#'                "upper.95.ci" (Upper 95\% confidence interval bound).}
#'   \item{model.estimates}{Data frame with columns corresponding 
#'   to each arm with descriptive suffixes as follows: 
#'                   ".Estimate" (Estimate of treatment effect for a given 
#'                   simulation), 
#'                   "Std.Err" (Standard error for treatment effect estimate), 
#'                   ".zval" (for GLMM) | ".wald" (for GEE), and 
#'                   ".pval" (the p-value estimate).}
#'   \item{overall.power}{Table of F-test (when method="glmm") or chi^{2} 
#'   (when method="gee") significance test results.}
#'   \item{overall.power.summary}{Summary overall power of treatment model
#'   compared to the null model.}
#'   \item{sim.data}{Produced when all.sim.data==TRUE. List of \code{nsim} 
#'   data frames, each containing: 
#'                   "y" (simulated response value), 
#'                   "trt" (indicator for treatment group or arm), and
#'                   "clust" (indicator for cluster).}
#'   \item{model.fit.warning.percent}{Character string containing the percent 
#'   of \code{nsim} in which the glmm fit was singular or failed to converge, 
#'   produced only when method = "glmm" & all.sim.data = FALSE.
#'   }
#'   \item{model.fit.warning.incidence}{Vector of length \code{nsim} denoting 
#'   whether or not a simulation glmm fit triggered a "singular fit" or 
#'   "non-convergence" error, produced only when method = "glmm" & 
#'   all.sim.data=TRUE.
#'   }
#'   }
#' 
#' @examples 
#' \dontrun{
#' nsubjects.example <- list(c(20,20,20,25), c(15, 20, 20, 21), c(17, 20, 21))
#' counts.example <- c(30, 55, 98)
#' sigma_b_sq.example <- c(1, 1, 2)
#' 
#' count.ma.rct.unbal <- cps.ma.count(nsim = 100, 
#'                             nsubjects = nsubjects.example, 
#'                             counts = counts.example,
#'                             sigma_b_sq = sigma_b_sq.example, 
#'                             alpha = 0.05, all.sim.data = FALSE, 
#'                             seed = 123, cores="all") 
#'                             
#' count.ma.rct.bal <- cps.ma.count(nsim = 50, nsubjects = 20, narms=3,
#'                             nclusters=10,
#'                             counts = c(30, 35, 70),
#'                             sigma_b_sq = 1, alpha = 0.05,
#'                             quiet = FALSE, method = 'glmm', 
#'                             all.sim.data = FALSE, 
#'                             multi.p.method="none",
#'                             poor.fit.override = TRUE,
#'                             seed = 123, cores="all")                             
#'}
#' @author Alexandria C. Sakrejda (\email{acbro0@@umass.edu}), Alexander R. Bogdan, and Ken Kleinman (\email{ken.kleinman@@gmail.com})
#' @export
cps.ma.count <- function(nsim = 1000, nsubjects = NULL, 
                          narms = NULL, nclusters = NULL,
                          counts = NULL, 
                         family = "poisson",
                         sigma_b_sq = NULL, 
                          alpha = 0.05,
                          quiet = FALSE, method = 'glmm', 
                          multi.p.method = "bonferroni",
                          all.sim.data = FALSE, seed = NA, 
                          cores=NA,
                          tdist=FALSE,
                          poor.fit.override = FALSE){
  
  # use this later to determine total elapsed time
  start.time <- Sys.time()
  # Create wholenumber function
  is.wholenumber = function(x, tol = .Machine$double.eps^0.5)  abs(x - round(x)) < tol
  
  # create proportion of F-test rejections fxn
  prop_H0_rejection <- function (alpha=alpha, nsim=nsim, LRT.holder.abbrev=LRT.holder.abbrev, test="F"){
    print(paste("Proportion of ", test, " significance-test rejections = ", 
                round(LRT.holder.abbrev, 3), ", CI:",
                round(LRT.holder.abbrev - abs(stats::qnorm(alpha / 2)) * 
                        sqrt((LRT.holder.abbrev * (1 - LRT.holder.abbrev)) / nsim), 3), ", ", 
                round(LRT.holder.abbrev + abs(stats::qnorm(alpha / 2)) * 
                        sqrt((LRT.holder.abbrev * (1 - LRT.holder.abbrev)) / nsim), 3), ".", sep=""))
  }
  
  # input validation steps
  if(!is.wholenumber(nsim) || nsim < 1 || length(nsim)>1){
    stop("nsim must be a positive integer of length 1.")
  }
  if (exists("nsubjects", mode = "any")==FALSE){
    stop("nsubjects must be specified. See ?cps.ma.count for help.")
  }
  if (length(nsubjects)==1 & exists("nclusters", mode = "numeric")==FALSE){
    stop("When nsubjects is scalar, user must supply nclusters (clusters per arm)")
  }
  if (length(nsubjects)==1 & length(nclusters)==1 & 
      exists("narms", mode = "numeric")==FALSE){
    stop("User must provide narms when nsubjects and nclusters are both scalar.")
  }
  
  # create narms and nclusters if not provided directly by user
  if (exists("nsubjects", mode = "list")==TRUE){
    # create narms and nclusters if not supplied by the user
    if (exists("narms", mode = "numeric")==FALSE){
      narms <- length(nsubjects)
    }
    if (exists("nclusters", mode = "numeric")==FALSE){
      nclusters <- vapply(nsubjects, length, 0)
    }
  }
  
  if(length(nclusters)==1 & (exists("nsubjects", mode = "list")==FALSE)){
    nclusters <- rep(nclusters, narms)
  }
  if(length(nclusters)>1 & length(nsubjects)==1){
    narms <- length(nclusters)
  }
  
  # nclusters must be whole numbers
  if (sum(is.wholenumber(nclusters)==FALSE)!=0 || nclusters < 1){
    stop("nclusters must be postive integer values.")
  }
  
  # nsubjects must be whole numbers
  if (sum(is.wholenumber(unlist(nsubjects))==FALSE)!=0 || unlist(nsubjects) < 1){
    stop("nsubjects must be positive integer values.")
  }
  
  # Create nsubjects structure from narms and nclusters when nsubjects is scalar
  if (length(nsubjects)==1){
    str.nsubjects <- lapply(nclusters, function(x) rep(nsubjects, x))
  } else {
    str.nsubjects <- nsubjects
  }
  
  # allows for counts, sigma_b_sq to be entered as scalar
  if (length(sigma_b_sq)==1){
    sigma_b_sq <- rep(sigma_b_sq, narms)
  }
  if (length(counts)==1){
    counts <- rep(counts, narms)
  }
  
  if (length(counts)!=narms){
    stop("Length of counts must equal narms, or be provided as a scalar if counts for all arms are equal.")
  }
  
  if (length(sigma_b_sq)!=narms){
    stop("Length of variance parameters sigma_b_sq must equal narms, or be provided as a scalar 
         if sigma_b_sq for all arms are equal.")
  }
  
  if (narms<3){
    message("Warning: LRT significance not calculable when narms<3. Use cps.count() instead.")
  }
  
  #validateVariance(dist="bin", alpha=alpha, ICC=NA, sigma=NA, 
  #                 sigma_b=sigma_b_sq, ICC2=NA, sigma2=NA, 
  #                 sigma_b2=NA, method=method, quiet=quiet, 
  #                 all.sim.data=all.sim.data, 
  #                 poor.fit.override=poor.fit.override, 
  #                 cores=cores,
  #                 counts=counts)
  
  # run the simulations 
  count.ma.rct <- cps.ma.count.internal(nsim = nsim, 
                                          str.nsubjects = str.nsubjects, 
                                          counts = counts,
                                          sigma_b_sq = sigma_b_sq, 
                                          alpha = alpha, 
                                          quiet = quiet, method = method, 
                                          all.sim.data = all.sim.data,
                                          seed = seed,
                                          poor.fit.override = poor.fit.override,
                                          tdist = tdist,
                                          cores = cores,
                                          family = family)
  
  models <- count.ma.rct[[1]]
  
  #Organize output for GLMM
  if(method=="glmm"){
    Estimates = matrix(NA, nrow = nsim, ncol = narms)
    std.error = matrix(NA, nrow = nsim, ncol = narms)
    z.val = matrix(NA, nrow = nsim, ncol = narms)
    p.val = matrix(NA, nrow = nsim, ncol = narms)
    
    for (i in 1:nsim){
      Estimates[i,] <- models[[i]][[10]][,1]
      std.error[i,] <- models[[i]][[10]][,2]
      z.val[i,] <- models[[i]][[10]][,3]
      p.val[i,] <- p.adjust(models[[i]][[10]][,4], method = multi.p.method)
    }
    
    # Organize the row/col names for the model estimates output
    keep.names <- rownames(models[[1]][[10]])
    
    names.Est <- rep(NA, narms)
    names.st.err <- rep(NA, narms)
    names.zval <- rep(NA, narms)
    names.pval <- rep(NA, narms)
    names.power <- rep(NA, narms)
    
    for (i in 1:length(keep.names)){
      names.Est[i] <- paste(keep.names[i], ".Estimate", sep="")
      names.st.err[i] <- paste(keep.names[i], ".Std.Err", sep="")
      names.zval[i] <- paste(keep.names[i], ".zval", sep="")
      names.pval[i] <- paste(keep.names[i], ".pval", sep="")
      names.power[i] <- paste(keep.names[i], ".power", sep="")
    }
    colnames(Estimates) <- names.Est
    colnames(std.error) <- names.st.err
    colnames(z.val) <- names.zval
    colnames(p.val) <- names.pval
    
    if (narms>2){
      # Organize the LRT output
      LRT.holder <- matrix(unlist(count.ma.rct[[2]]), ncol=3, nrow=nsim, 
                           byrow=TRUE, 
                           dimnames = list(seq(1:nsim), 
                                           colnames(count.ma.rct[[2]][[1]])))
      
      # Proportion of times P(>F)
      sig.LRT <-  ifelse(LRT.holder[,3] < alpha, 1, 0)
      LRT.holder.abbrev <- sum(sig.LRT)/nsim
    }
    
    # Calculate and store power estimate & confidence intervals
    sig.val <-  ifelse(p.val < alpha, 1, 0)
    pval.power <- apply (sig.val, 2, FUN=function(x) {sum(x, na.rm=TRUE)/nsim})
    power.parms <-  data.frame(Power = round(pval.power, 3),
                               Lower.95.CI = round(pval.power - abs(stats::qnorm(alpha / 2)) * 
                                                     sqrt((pval.power * (1 - pval.power)) / nsim), 3),
                               Upper.95.CI = round(pval.power + abs(stats::qnorm(alpha / 2)) * 
                                                     sqrt((pval.power * (1 - pval.power)) / nsim), 3))
    rownames(power.parms) <- names.power
    
    # Store simulation output in data frame
    ma.model.est <-  data.frame(Estimates, std.error, z.val, p.val)
    ma.model.est <- ma.model.est[, -grep('.*ntercept.*', names(ma.model.est))] 
    
    # performance messages
    total.est <-  as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
    hr.est <-  total.est %/% 3600
    min.est <-  total.est %/% 60
    sec.est <-  round(total.est %% 60, 0)
    message(paste0("Simulations Complete! Time Completed: ", Sys.time(), 
                   "\nTotal Runtime: ", hr.est, 'Hr:', min.est, 'Min:', 
                   sec.est, 'Sec'))
    
    ## Output objects for GLMM
    
    # Create list containing all output (class 'crtpwr') and return
    if(all.sim.data == TRUE){
      complete.output <-  list("power" <-  power.parms[-1,],
                               "model.estimates" <-  ma.model.est, 
                               "overall.power" <- LRT.holder,
                               "overall.power2" <- try(prop_H0_rejection(alpha=alpha, nsim=nsim, 
                                                                         LRT.holder.abbrev=LRT.holder.abbrev, test="Wald")),
                               "sim.data" <-  count.ma.rct[[3]], 
                               "failed.to.converge" <-  count.ma.rct[[4]])
    } else {
      complete.output <-  list("power" <-  power.parms[-1,],
                               "overall.power" <- try(prop_H0_rejection(alpha=alpha, nsim=nsim, 
                                                                        LRT.holder.abbrev=LRT.holder.abbrev, test="Wald")),
                               "proportion.failed.to.converge" <- count.ma.rct[[3]])
    }
    return(complete.output)
  } # end of GLMM options
  
  #Organize output for GEE method
  if (method=="gee"){
    # Organize the output
    Estimates = matrix(NA, nrow = nsim, ncol = narms)
    std.error = matrix(NA, nrow = nsim, ncol = narms)
    Wald = matrix(NA, nrow = nsim, ncol = narms)
    Pr = matrix(NA, nrow = nsim, ncol = narms)
    
    for (i in 1:nsim){
      Estimates[i,] <- models[[i]]$coefficients[,1]
      std.error[i,] <- models[[i]]$coefficients[,2]
      Wald[i,] <- models[[i]]$coefficients[,3]
      Pr[i,] <- models[[i]]$coefficients[,4]
    }
    
    # Organize the row/col names for the output
    keep.names <- rownames(models[[1]]$coefficients)
    
    names.Est <- rep(NA, length(narms))
    names.st.err <- rep(NA, length(narms))
    names.wald <- rep(NA, length(narms))
    names.pval <- rep(NA, length(narms))
    names.power <- rep(NA, length(narms))
    
    for (i in 1:length(keep.names)){
      names.Est[i] <- paste(keep.names[i], ".Estimate", sep="")
      names.st.err[i] <- paste(keep.names[i], ".Std.Err", sep="")
      names.wald[i] <- paste(keep.names[i], ".wald", sep="")
      names.pval[i] <- paste(keep.names[i], ".pval", sep="")
      names.power[i] <- paste(keep.names[i], ".power", sep="")
    }
    colnames(Estimates) <- names.Est
    colnames(std.error) <- names.st.err
    colnames(Wald) <- names.wald
    colnames(Pr) <- names.pval
    
    # Organize the LRT output
    LRT.holder <- matrix(unlist(count.ma.rct[[2]]), ncol=3, nrow=nsim, 
                         byrow=TRUE, 
                         dimnames = list(seq(1:nsim), 
                                         c("Df", "X2", "P(>|Chi|)")))
    
    # Proportion of times P(>F)
    sig.LRT <-  ifelse(LRT.holder[,3] < alpha, 1, 0)
    LRT.holder.abbrev <- sum(sig.LRT)/nsim
    
    # Calculate and store power estimate & confidence intervals
    sig.val <-  ifelse(Pr < alpha, 1, 0)
    pval.power <- apply (sig.val, 2, FUN=function(x) {sum(x, na.rm=TRUE)/nsim})
    power.parms <-  data.frame(Power = round(pval.power, 3),
                               Lower.95.CI = round(pval.power - abs(stats::qnorm(alpha / 2)) * 
                                                     sqrt((pval.power * (1 - pval.power)) / nsim), 3),
                               Upper.95.CI = round(pval.power + abs(stats::qnorm(alpha / 2)) * 
                                                     sqrt((pval.power * (1 - pval.power)) / nsim), 3))
    rownames(power.parms) <- names.power
    
    # Store GEE simulation output in data frame
    ma.model.est <-  data.frame(Estimates, std.error, Wald, Pr)
    ma.model.est <- ma.model.est[, -grep('.*ntercept.*', names(ma.model.est))] 
    
    # performance messages
    total.est <-  as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
    hr.est <-  total.est %/% 3600
    min.est <-  total.est %/% 60
    sec.est <-  round(total.est %% 60, 0)
    message(paste0("Simulations Complete! Time Completed: ", Sys.time(), 
                   "\nTotal Runtime: ", hr.est, 'Hr:', min.est, 'Min:', 
                   sec.est, 'Sec'))
    
    ## Output objects for GEE
    # Create list containing all output (class 'crtpwr') and return
    if(all.sim.data == TRUE){
      complete.output <-  list("power" <-  power.parms[-1,],
                               "model.estimates" <-  ma.model.est, 
                               "overall.power" <- LRT.holder,
                               "overall.power2" <- try(prop_H0_rejection(alpha=alpha, nsim=nsim, 
                                                                         LRT.holder.abbrev=LRT.holder.abbrev),
                                                       "sim.data" <-  count.ma.rct[[3]]))
    } else {
      complete.output <-  list("power" <-  power.parms[-1,],
                               "model.estimates" <-  ma.model.est, 
                               "overall.power" <- LRT.holder,
                               "overall.power2" <- try(prop_H0_rejection(alpha=alpha, nsim=nsim, 
                                                                         LRT.holder.abbrev=LRT.holder.abbrev)))
    }# end of return options
    # assign special class
    class(complete.output) <- c("multiarm", "list")
    return(complete.output)
  }# end of GEE options
  }# end of fxn