SAT <- function(dta, mtd, constraints, psm_eq, ids, drop_opts, visual, TrtBinColName)
{
  #Initialization
  pltObjs <- list()
  init_dta <- dta
  
  drop_unmatched = drop_opts["drop_unmatched"]
  drop_method = drop_opts["drop_method"]
  drop_thresh = as.numeric(drop_opts["drop_thresh"])
  
  if(!is.null(constraints))
  {
    for(cst in 1:length(names(constraints)))
    {
    if(names(constraints)[cst] == "groups")
      {
      exec_stmnt = paste("dta$ConstraintGroupSet_Opt <- dta$",constraints["groups"],sep="")
      eval(parse(text=exec_stmnt))
      } else
      {
        dta$ConstraintGroupSet_Opt <- 1
      }
    if(names(constraints)[cst] == "distance")
      {
      dist_PSM = as.numeric(constraints["distance"][[1]])
      } else
      {
      dist_PSM=NULL
      }
    }
  } else {
    dta$ConstraintGroupSet_Opt <- 1
    #max the distance threshold by taking the diagonal of the bounding box.
    dist_PSM = NULL
  }
  
  #Caclulate the number of groups to constrain by, if any.
  group_constraints <- unique(dta$ConstraintGroupSet_Opt)
  
  #Make sure there are both treatment and control groups of an adequate size (>= 1 of each)
  t_dta <- list()
  u_dta <-list()
  grp_list <- list()
  cnt = 0
  for (grp in 1:length(group_constraints))
  {
    cur_grp <- as.matrix(group_constraints)[grp]
    grp_index = length(grp_list)+1
    t_index = length(t_dta)+1
    grp_list[[grp_index]] <- as.matrix(group_constraints)[grp]
    t_dta[[t_index]] <- dta[dta$TrtBin == 1,]
    u_dta[[t_index]] <- dta[dta$TrtBin == 0,]
    treatment_count <- cur_grp %in% t_dta[[t_index]]$ConstraintGroupSet_Opt
    untreated_count <- cur_grp %in% u_dta[[t_index]]$ConstraintGroupSet_Opt
    if((untreated_count == FALSE) || (treatment_count == FALSE))
    {
      dta <- dta[!dta$ConstraintGroupSet_Opt == cur_grp,]
      t_dta[[t_index]] <- NULL
      u_dta[[t_index]] <- NULL
      grp_list[[t_index]] <- NULL
      war_statement = paste("Dropped group due to a lack of both treatment and control observation: '",cur_grp,"'",sep="")
      warning(war_statement)
    } else {
      
      t_dta[[t_index]] <- t_dta[[t_index]][t_dta[[t_index]]$ConstraintGroupSet_Opt == cur_grp,]
      u_dta[[t_index]] <- u_dta[[t_index]][u_dta[[t_index]]$ConstraintGroupSet_Opt == cur_grp,]
        
      cnt = cnt + 1
    }
  }
  temp_dta <- list()
for(i in 1:cnt)
  {
  cur_grp <- grp_list[[i]]
  it_dta <- maptools::spRbind(t_dta[[i]],u_dta[[i]])

  
  if (mtd == "fastNN")
    {
      temp_dta[[i]] <- fastNN_binary_func(it_dta,TrtBinColName,ids,cur_grp,dist_PSM) 
    }
  
  if (mtd == "NN_WithReplacement")
    {
      print("NN with replacement is currently not available, please choose fastNN")
     # temp_dta[[i]] <- NN_WithReplacement_binary_func(it_dta,TrtBinColName,ids,cur_grp,dist_PSM) 
    }
  }

#Build the final datasets from subsets
if(cnt > 1)
{
  dta <- temp_dta[[1]]
  for(k in 2:cnt)
  {
  dta  <- maptools::spRbind(dta, temp_dta[[k]])
  } 
} else {
  dta <- temp_dta[[1]]
}


  if (drop_unmatched == TRUE)
  {
    dta <- dta[dta@data$PSM_match_ID != -999,]    
  }
  
  anc_v_int <- strsplit(psm_eq, "~")[[1]][2]
  anc_vars <- strsplit(gsub(" ","",anc_v_int), "+", fixed=TRUE)
  anc_vars <- c(anc_vars[[1]], "PSM_trtProb")
  
  #Drop observations according to the selected method
  if(drop_method == "SD")
  {
    #Method to drop pairs that are greater than a set threshold apart in terms of PSM Standard Deviations.
    psm_sd_thresh = sd(dta$PSM_trtProb) * drop_thresh
    if(visual == "TRUE")
    {
      print(psm_sd_thresh)
    }
    dta <- dta[dta@data$PSM_distance < psm_sd_thresh,]
  }
  
  #Plot the pre and post-dropping balance for PSM model...
  #Balance metrics are based on "Misunderstandings between experimentalists and
  #observationalists about causal inference", Imal, King, and Stuart.
  #Simplest suggestion of comparing means and checking if .25 SD apart used.
  cnt = 0
  for (i in 1:length(anc_vars))
  {
    #gsub to remove any factors()
    ed_v = sub("factor\\(","",anc_vars[i])
    ed_v = sub(")","",ed_v)
    treat_mean_pre = paste("round(describeBy(init_dta@data$",ed_v,", group=init_dta@data$",TrtBinColName,")[[2]][[3]],5)")
    treat_SD_pre = paste("round(describeBy(init_dta@data$",ed_v,", group=init_dta@data$",TrtBinColName,")[[2]][[4]],5)")
    
    control_mean_pre = paste("round(describeBy(init_dta@data$",ed_v,", group=init_dta@data$",TrtBinColName,")[[1]][[3]],5)")
    control_SD_pre = paste("round(describeBy(init_dta@data$",ed_v,", group=init_dta@data$",TrtBinColName,")[[1]][[4]],5)")
    
    treat_mean_post = paste("round(describeBy(dta@data$",ed_v,", group=dta@data$",TrtBinColName,")[[2]][[3]],5)")
    treat_SD_post = paste("round(describeBy(dta@data$",ed_v,", group=dta@data$",TrtBinColName,")[[2]][[4]],5)")
    
    control_mean_post = paste("round(describeBy(dta@data$",ed_v,", group=dta@data$",TrtBinColName,")[[1]][[3]],5)")
    control_SD_post = paste("round(describeBy(dta@data$",ed_v,", group=dta@data$",TrtBinColName,")[[1]][[4]],5)")
   
    c_type = eval(parse(text=paste("class(init_dta@data$",ed_v,")")))
    
    if(c_type == "matrix")
    {
      exec_str = paste("dta@data$",ed_v,"<- as.numeric(dta@data$",ed_v,")",sep="")
      eval(parse(text=exec_str))
      
      exec_str = paste("init_dta@data$",ed_v,"<- as.numeric(init_dta@data$",ed_v,")",sep="")
      eval(parse(text=exec_str))
      c_type = "numeric"
    }
    if((c_type == "numeric") & (visual == "TRUE"))
    {
      cnt = cnt + 1
      pltObjs[[length(pltObjs) + 1]] <- GroupCompHist(init_dta, anc_vars[i],"Pre-Balancing: ",simple_out = FALSE)
      pltObjs[[length(pltObjs) + 1]] <- GroupCompHist(dta, anc_vars[i],"Post-Balancing: ",simple_out = FALSE)  

      treat_mean_pre <- eval(parse(text=treat_mean_pre))
      treat_SD_pre <- eval(parse(text=treat_SD_pre))
      control_mean_pre <- eval(parse(text=control_mean_pre))
      control_SD_pre <- eval(parse(text=control_SD_pre))
      
      treat_mean_post <- eval(parse(text=treat_mean_post))
      treat_SD_post <- eval(parse(text=treat_SD_post))
      control_mean_post <- eval(parse(text=control_mean_post))
      control_SD_post <- eval(parse(text=control_SD_post))
      
      it_diff_Mean_pre <- round(abs( treat_mean_pre-control_mean_pre ),5)
      it_diff_Mean_post <- round(abs(treat_mean_post-control_mean_post),5)
      
      if(!exists("bRes"))
      {
        bRes <- data.frame(treat_mean_pre,treat_SD_pre,control_mean_pre,control_SD_pre,
                           treat_mean_post,treat_SD_post,control_mean_post,control_SD_post,
                           it_diff_Mean_pre,it_diff_Mean_post)
        colnames(bRes)[1] <- "Pre-Balance Treated Mean"
        colnames(bRes)[2] <- "Pre-Balance Treated SD"
        colnames(bRes)[3] <- "Pre-Balance Control Mean"
        colnames(bRes)[4] <- "Pre-Balance Control SD"
        
        colnames(bRes)[5] <- "Post-Balance Treated Mean"
        colnames(bRes)[6] <- "Post-Balance Treated SD"
        colnames(bRes)[7] <- "Post-Balance Control Mean"
        colnames(bRes)[8] <- "Post-Balance Control SD"
        
        colnames(bRes)[9] <- "Mean Difference Pre-Balance"
        colnames(bRes)[10] <- "Mean Difference Post-Balance"
      }else{
        bRes <- rbind(bRes, c(treat_mean_pre,treat_SD_pre,control_mean_pre,control_SD_pre,
                              treat_mean_post,treat_SD_post,control_mean_post,control_SD_post,
                              it_diff_Mean_pre,it_diff_Mean_post))
      }
      
  
      rownames(bRes)[i-(i-cnt)] <- gsub("[^a-zA-Z0-9]","",ed_v)
    }
  }
  
  if(visual=="TRUE")
  {
    #Output graphics
    #Remove the factor rows
    nrow_c <- length(pltObjs)
    counter <- 1
    while(counter <= nrow_c)
    {
      d = counter + 3
      if(d > nrow_c)
      {
        d = nrow_c
      }
      do.call(grid.arrange,c(pltObjs[counter:d],nrow=2,ncol=2))
      counter = counter + 4
    }
    #bTab <- stargazer(bRes,summary=FALSE,type="html")
    #print.htmlTable(bTab)
  }
  

  return (dta)
}

