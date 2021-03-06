#' Combining functions
#' 
#' Fisher combining function is \eqn{-2\sum log(p)}.
#' @param p Vector of p-values
#' @return The combined test statistic
#' 
fisher <- function(p) {
    -2 * log(prod(p))
}

#' @describeIn fisher
#' \eqn{\sum \Phi^{-1}(1-p)}.
liptak <- function(p) {
    sum(qnorm(1 - p))
}

#' @describeIn fisher
#' \eqn{max(1-p)}.
tippett <- function(p) {
    max(1 - p)
}


#' Inverse-n weight combining function
#'
#' Compute the test statistic \eqn{-\sum p_s/\sqrt{N_s}}
#' 
#' @param p Vector of p-values
#' @param n Vector of sample sizes. The \eqn{i}th entry is the
#'        sample size used in the \eqn{i}th test
#' @return The combined test statistic
inverse_n_weight <- function(p, n) {
    if (length(p) != length(n)) {
        stop("Number of p-values and sample sizes must be equal")
    }
    if (!all(n%%1 == 0)) {
        stop("Sample sizes must be integers")
    }
    weights <- n^(-1/2)
    return(sum(-1 * p * weights))
}


#' Non-parametric combination of tests
#'
#' Combines partial p-values from individual hypothesis tests \eqn{H_{0i}} against \eqn{H_{1i}}
#' to test the global null hypothesis
#' \deqn{\cap_{i} H_{0i}}
#' against the alternative
#' \deqn{\cup_{i} H_{1i}}
#' using a combining function.
#'
#' For details on the combining functions, see \code{\link{fisher}}, \code{\link{liptak}}, and \code{\link{tippett}}.
#' 
#' Alternative options are 'greater', 'less', or 'two-sided'. If specified, length of alternatives must
#' either be 1 or match the number of statistics.
#' @param statistics    Vector of observed statistics for each partial test
#' @param distr         Matrix or dataframe, columns are approimate null distribution for each partial test
#' @param combine       Combining function (default is 'fisher'). 
#'        May either be the name of a function ('fisher', 'liptak', 'tippett') or a function itself
#' @param alternatives  Optional, vector of alternatives for each test (default is all 'greater')
#' 
#' 
#' @return A single p-value for the global test
#' 
npc <- function(statistics, distr, combine = "fisher", alternatives = "greater") {
    if (length(statistics) < 2) {
        stop("Nothing to combine!")
    }
    if (length(statistics) != ncol(distr)) {
        stop("Different number of statistics and null distributions")
    }
    if (length(alternatives) != length(statistics)) {
        if (length(alternatives) == 1) {
            alternatives <- rep(alternatives, length(statistics))
        } else {
            stop("Bad alternatives")
        }
    }
    
    pvalues <- sapply(1:ncol(distr), function(j) {
        t2p(statistics[j], distr[, j], alternatives[j])
    })
    null_pvalues <- sapply(1:ncol(distr), function(j) {
        pvalue_distr(distr[, j], alternatives[j])
    })
    
    if (is.function(combine)) {
        combn_func <- combine
    } else {
        funcs <- list(fisher, liptak, tippett)
        names(funcs) <- c("fisher", "liptak", "tippett")
        if (!(combine %in% names(funcs))) {
            stop(paste(combine, " is not a valid combining function."))
        }
        combn_func <- funcs[[combine]]
        
        if (combine == "liptak") {
            too_small <- which(null_pvalues == 0)
            too_large <- which(null_pvalues == 1)
            null_pvalues[too_small] <- null_pvalues[too_small] + 1e-04
            null_pvalues[too_large] <- null_pvalues[too_large] - 1e-04
        }
    }
    
    obs_combined_pvalue <- combn_func(pvalues)
    if (is.infinite(obs_combined_pvalue)) {
        return(0)
    }
    combined_pvalues <- apply(null_pvalues, 1, combn_func)
    return(mean(combined_pvalues >= obs_combined_pvalue))
}
