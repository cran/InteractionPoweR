
#' Power estimate
#'
#' Uses regression to estimate the value needed to attain the target power, given a set of simulation results.
#'
#' @param power_data Output of power_interaction().
#' @param x The name of the target variable as a character string.
#' @param power_target The desired power level. Must be between 0 and 1 (e.g., 0.8 for 80% power).
#'
#' @return A data frame containing the value of x that achieves the target power for each combination of settings. Will return NA if target power is outside the simulation data.
#' @export
#'
#' @examples
#' simulation_results = power_interaction_r2(N=seq(100,300,by=10),
#' r.x1.y=0.2, r.x2.y=.2,r.x1x2.y=0.2,r.x1.x2=.2)
#' power_estimate(power_data = simulation_results, x = "N", power_target = .8)
power_estimate<-function(power_data,x,power_target){

  power_data2a = power_data[, which(colnames(power_data) == "pwr" | colnames(power_data) == x)]
  power_data2b = power_data[, -which(colnames(power_data) == "pwr" | colnames(power_data) == x)] %>% as.data.frame()

  colnames(power_data2b) = colnames(power_data)[-which(colnames(power_data) == "pwr" | colnames(power_data) == x)]

  data_dim2b = dim(power_data2b)[2]
  data_dim = data_dim2b
  if(data_dim2b > 0){

    if(!identical( which(colnames(power_data) == "alpha") ,integer(0))){
      power_data2b = power_data2b[, c(1 : which(colnames(power_data2b) == "alpha")  )]
    }
    cols.to.use = apply(power_data2b,2,function(X){dim(table(X)) >  1 },simplify = TRUE)
    power_data2c = power_data2b[,cols.to.use] %>% as.data.frame()
    colnames(power_data2c)=    colnames(power_data2b)[cols.to.use]
    data_dim<-dim(power_data2c)[2]
    other_cols<-colnames(power_data2c)

    }


  x_col<-which(colnames(power_data2a) == x)
  pwr_col<-which(colnames(power_data2a) == "pwr")
  #power_data$x<-power_data[,x_col]

  if(data_dim==0){power_data2a$temp = 1}else{power_data2a = cbind(power_data2a,power_data2c) }

  power_levels<-  unique(expand.grid(    power_data2a[,-c(which(colnames(power_data2a) == "pwr"),x_col)]
                                     ))

  rownames(power_levels)<-NULL

  if(data_dim==0){colnames(power_levels)<-"temp"
  }  else{
    colnames(power_levels) <- other_cols
  }
  power_out_final<-as.data.frame(power_levels)

  power_out<-power_out_final

  power_out_final$estimate<-0

  for(p in 1: dim(power_out)[1]){
    #print(p)
    #filters=paste(  colnames(power_out),"==",power_out[p,])
    filters=paste( "dplyr::near(",colnames(power_levels),",",power_levels[p,],",tol=10^-10)")
    power_test<-dplyr::filter(power_data2a, !!!rlang::parse_exprs(paste(filters, collapse = ";")))
    power_test<-as.data.frame(power_test)

    if(dim(power_test)[1] > 0){
      power_test$x<-power_test[,x_col]
      power_test$x2<-power_test$x ^2
      power_test$x3<-power_test$x ^3
      power_test$lnx<-log(power_test$x)

      power_test[power_test=="-Inf"]<-NA
      power_test<-stats::na.omit(power_test)

      fit1=chngpt::chngptm (formula.1=pwr~1, formula.2=~x+x2, data = power_test, type="M20", ncpus = 1,
                    family="gaussian",ci.bootstrap.size = 0)
      # can we compare model fits?
      fit1c=chngpt::chngptm (formula.1=pwr~1, formula.2=~x+x2+x3, data = power_test, type="M20", ncpus = 1,
                     family="gaussian",ci.bootstrap.size = 0)

      fit1b=chngpt::chngptm (formula.1=pwr~1, formula.2=~lnx, data = power_test, type="M10", ncpus = 1,
                     family="gaussian",ci.bootstrap.size = 0)

      changepoint<-max(c(fit1$chngpt,fit1c$chngpt,exp(fit1b$chngpt)))


      power_test2<-dplyr::filter(power_test, x<= changepoint)

      fit2<-stats::lm(pwr~x + x2,data = power_test2)
      fit3<-stats::lm(pwr~x + x2 + x3,data = power_test2)
      fit4<-stats::lm(pwr~lnx,data = power_test2)

      compare<-stats::anova(fit4,fit2,fit3)
      #compare<-stats::anova(fit4,fit2,fit3)

      if(!is.na(compare$`Pr(>F)`[2]) && compare$`Pr(>F)`[2]<0.05){
        j<-polynom::polynomial(stats::coefficients(fit2))
        pwr_line<-(solve(j,b = power_target))

        if(compare$`Pr(>F)`[3]<0.05){
          j<-polynom::polynomial(stats::coefficients(fit3))
          pwr_line<-(solve(j,b = power_target))

          if(is.complex(pwr_line)){
            j<-polynom::polynomial(stats::coefficients(fit2))
            pwr_line<-(solve(j,b = power_target))
            }

        }



        if(is.complex(pwr_line)){
          j<-polynom::polynomial(stats::coefficients(fit4))
          pwr_line<-exp(solve(j,b = power_target))}

      } else {
        j<-polynom::polynomial(stats::coefficients(fit4))
        pwr_line<-exp(solve(j,b = power_target))
      }




      if(!is.complex(pwr_line)){
        pwr_line<-pwr_line[which(pwr_line < max(power_test2$x) & pwr_line> min(power_test2$x))]
        if(length(pwr_line)>1){ pwr_line<-pwr_line[1]}
        if(length(pwr_line) == 0){
          warning("Parameter value is out of data range")
          pwr_line<-NA}
      } else{pwr_line<-NA}

      power_out_final$estimate[p]<-pwr_line


    }
  }

  if(dim(power_out_final)[1] == 1){power_out_final<-unname(power_out_final$estimate)}
  return(power_out_final)

}
