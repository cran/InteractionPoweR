% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/power_estimate.R
\name{power_estimate}
\alias{power_estimate}
\title{Power estimate}
\usage{
power_estimate(power_data, x, power_target)
}
\arguments{
\item{power_data}{Output of power_interaction().}

\item{x}{The name of the target variable as a character string.}

\item{power_target}{The desired power level. Must be between 0 and 1 (e.g., 0.8 for 80\% power).}
}
\value{
A data frame containing the value of x that achieves the target power for each combination of settings. Will return NA if target power is outside the simulation data.
}
\description{
Uses regression to estimate the value needed to attain the target power, given a set of simulation results.
}
\examples{
simulation_results = power_interaction_r2(N=seq(100,300,by=10),
r.x1.y=0.2, r.x2.y=.2,r.x1x2.y=0.2,r.x1.x2=.2)
power_estimate(power_data = simulation_results, x = "N", power_target = .8)
}
