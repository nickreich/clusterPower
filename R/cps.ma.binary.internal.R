
#' Power simulations for cluster-randomized trials: Simple Designs, Continuous Outcome.
#'
#' This set of functions utilize iterative simulations to determine 
#' approximate power for cluster-randomized controlled trials. Users 
#' can modify a variety of parameters to suit the simulations to their
#' desired experimental situation.
#' 
#' Runs the power simulation.
#' 
#' Users must specify the desired number of simulations, number of subjects per 
#' cluster, number of clusters per treatment arm, group means, two of the following: ICC, within-cluster variance, or 
#' between-cluster variance; significance level, analytic method, progress updates, 
#' and simulated data set output may also be specified.
#' 
#' 
#' @author Alexandria C. Sakrejda (\email{acbro0@@umass.edu}, Alexander R. Bogdan, and Ken Kleinman (\email{ken.kleinman@@gmail.com})
#'
#' @param nsim Number of datasets to simulate; accepts integer (required).
#' @param str.nsubjects Number of subjects per treatment group; accepts a list with one entry per arm. 
#' Each entry is a vector containing the number of subjects per cluster (required).
#' @param means Expected probability of outcome for each arm; accepts a vector of length \code{narms} (required).
#' @param sigma_b Between-cluster variance; accepts a vector of length \code{narms} (required).
#' @param alpha Significance level; default = 0.05.
#' @param method Analytical method, either Generalized Linear Mixed Effects Model (GLMM) or 
#' Generalized Estimating Equation (GEE). Accepts c('glmm', 'gee') (required); default = 'glmm'.
#' @param quiet When set to FALSE, displays simulation progress and estimated completion time; default is FALSE.
#' @param all.sim.data Option to output list of all simulated datasets; default = FALSE.
#' @param seed Option to set.seed. Default is NULL.
#' @param poor.fit.override Option to override \code{stop()} if more than 25% of fits fail to converge
#' 
#' @return A list with the following components
#' \describe{
#'   \item{model.values}{List of length(nsim) containing gee- or glmm-fitted the model summaries.
#'   Note: the responsibility for correcting for multiple testing lies with the user.}
#'   \item{model.comparisons} Compares fitted model to a model for H0 using ML (anova).
#'   \item{sim.data}{List of data frames, each containing: 
#'                   "y" (Simulated response value), 
#'                   "trt" (Indicator for treatment group), 
#'                   "clust" (Indicator for cluster)}
#'   \item{failed.to.converge}{A vector of length \code{nsim} consisting of 1 and 0. 
#         When a model fails to converge, failed.to.converge==1, otherwise 0.}
#' }
#' 
#' 
#' 
#' @examples 
#' \dontrun{
#' 
#' str.nsubjects.example <- list(c(20,20,20,25), c(15, 20, 20, 21), c(17, 20, 21))
#' probs.example <- c(0.30, 0.21, 0.53)
#' sigma.example <- c(100, 110, 100)
#' sigma_b.example <- c(25, 25, 120)
#' 
#' normal.ma.rct <- cps.ma.normal.internal(nsim = 1000, str.nsubjects = str.nsubjects.example, 
#'                                        probs = probs.example, 
#'                                        sigma_b = sigma_b.example, alpha = 0.05, 
#'                                        quiet = FALSE, method = 'glmm', 
#'                                        all.sim.data = FALSE, seed = 123)
#' }
#' 
#' @export

cps.ma.binary.internal <-  function(nsim = 1000, str.nsubjects = NULL,
                                    probs = NULL, sigma_b = NULL,
                                    alpha = 0.05,
                                    quiet = FALSE, method = 'glmm', 
                                    all.sim.data = FALSE, 
                                    seed=NULL,
                                    poor.fit.override = FALSE){
  
  # Create vectors to collect iteration-specific values
  simulated.datasets = list()
  
  
  # Create NCLUSTERS, NARMS, from str.nsubjects
  narms = length(str.nsubjects)
  nclusters = sapply(str.nsubjects, length)
  
  # validation goes here
  
  # Set start.time for progress iterator & initialize progress bar
  start.time = Sys.time()
  prog.bar =  progress::progress_bar$new(format = "(:spin) [:bar] :percent eta :eta", 
                                         total = nsim, clear = FALSE, width = 100)
  prog.bar$tick(0)
  
  # This container keeps track of how many models failed to converge
  fail <- rep(NA, nsim)
  
  # Create a container for the simulated.dataset and model output
  sim.dat = vector(mode = "list", length = nsim)
  model.values <- list()
  model.compare <- list()
  
  # option for reproducibility
  set.seed(seed=seed)
  
  # Create indicators for treatment group & cluster for the sim.data output
  trt1 = list()
  for (arm in 1:length(str.nsubjects)){
    trt1[[arm]] = list()
    for (cluster in 1:length(str.nsubjects[[arm]])){
      trt1[[arm]][[cluster]] = rep(arm, str.nsubjects[[arm]][[cluster]])
    }
  }
  clust1 = list()
  for(i in 1:sum(nclusters)){
    clust1[[i]] <- lapply(seq(1, sum(nclusters))[i], 
                         function (x) {rep.int(x, unlist(str.nsubjects)[i])})
  }
  
  # Calculate log odds for each group
  logit.p <- list()
  for (i in 1:length(probs)){
    logit.p[[i]] = log(probs[i] / (1 - probs[i]))
  }
  logit.p <- unlist(logit.p)
  
  # Create simulation loop
  for(i in 1:nsim){
    sim.dat[[i]] = data.frame(y = NA, trt = as.factor(unlist(trt1)), 
                              clust = as.factor(unlist(clust1)))
    # Generate between-cluster effects for non-treatment and treatment 
    randint = mapply(function(nc, s, mu) stats::rnorm(nc, mean = mu, sd = sqrt(s)), 
                     nc = nclusters, s = sigma_b, 
                     mu = 0)
    
    for (j in 1:length(logit.p)){
      randint[[j]] <- clusterPower::expit(logit.p[i]+ randint[[i]])
    }
    
    # Create y-value
    y.intercept <-  vector(mode = "numeric", length = length(unlist(str.nsubjects)))
    y.intercept <-  sapply(1:sum(nclusters), 
                        function(x) rep(unlist(randint)[x], length.out = unlist(str.nsubjects)[x]))
  
    # Put y into the simulated dataset
    sim.dat[[i]][["y"]] <-  as.factor(sapply(unlist(y.intercept), function(x) stats::rbinom(1, 1, x)))
    
    print(sim.dat)
    
    # Fit GLMM (lmer)
    if(method == 'glmm'){
      my.mod <-  lme4::glmer(y ~ trt + (1|clust), data = sim.dat[[i]], family = stats::binomial(link = 'logit'))
      model.values[[i]] <-  summary(my.mod)
      # option to stop the function early if fits are singular
      fail[i] <- ifelse(any( grepl("singular", my.mod@optinfo$conv$lme4$messages) )==TRUE, 1, 0) 
      if (poor.fit.override==FALSE){
        if(sum(fail, na.rm = TRUE)>(nsim*.25)){stop("more than 25% of simulations are singular fit: check model specifications")}
      }
    }
    
    # Fit GEE (geeglm)
    if(method == 'gee'){
      data.holder = dplyr::arrange(sim.dat[[i]], clust)
      my.mod = geepack::geeglm(y ~ trt, data = sim.dat,
                               family = stats::binomial(link = 'logit'), 
                               id = clust, corstr = "exchangeable")
      model.values[[i]] = summary(my.mod)
    }
    
    # get the overall p-values (>Chisq)
    null.mod <- update.formula(my.mod, y ~ (1|clust))
    model.compare[[i]] <- anova(my.mod, null.mod)
    
    # stop the loop if power is <0.5
    if (poor.fit.override==FALSE){
      if (i > 50 & (i %% 10==0)){
        temp.power.checker <- matrix(unlist(model.compare[1:i]), ncol=6, nrow=i, 
                                     byrow=TRUE)
        sig.val.temp <-  ifelse(temp.power.checker[,6][1:i] < alpha, 1, 0)
        pval.power.temp <- sum(sig.val.temp)/i
        if (pval.power.temp < 0.5){
          stop(paste("Calculated power is < ", pval.power.temp, ", auto stop at simulation ", 
                     i, ". Set poor.fit.override==TRUE to ignore this error.", sep = ""))
        }
      }
    }
    
    # Update simulation progress information
    if(quiet == FALSE){
      if(i == 1){
        avg.iter.time = as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
        time.est = avg.iter.time * (nsim - 1) / 60
        hr.est = time.est %/% 60
        min.est = round(time.est %% 60, 0)
        message(paste0('Begin simulations :: Start Time: ', Sys.time(), 
                       ' :: Estimated completion time: ', hr.est, 'Hr:', min.est, 'Min'))
      }
      
      # Iterate progress bar
      prog.bar$update(i / nsim)
      Sys.sleep(1/100)
      
      if(i == nsim){
        total.est = as.numeric(difftime(Sys.time(), start.time, units = 'secs'))
        hr.est = total.est %/% 3600
        min.est = total.est %/% 60
        sec.est = round(total.est %% 60, 0)
        message(paste0("Simulations Complete! Time Completed: ", Sys.time(), 
                       "\nTotal Runtime: ", hr.est, 'Hr:', min.est, 'Min:', sec.est, 'Sec'))
      }
    }
  } 
  
  ## Output objects
  if(all.sim.data == TRUE){
    complete.output.internal <-  list("estimates" = model.values,
                                      "model.comparisons" = model.compare,
                                      "sim.data" = sim.dat,
                                      "failed.to.converge"= fail)
  } else {
    complete.output.internal <-  list("estimates" = model.values,
                                      "model.comparisons" = model.compare,
                                      "failed.to.converge" =  paste((sum(fail)/nsim)*100, "% did not converge", sep=""))
  }
  return(complete.output.internal)
}