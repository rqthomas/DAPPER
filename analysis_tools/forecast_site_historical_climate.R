rm(list = ls())
#---CONTROL INFORMATION----------------------------
working_directory = '/Users/quinn/Dropbox (VTFRS)/Research/DAPPER'
input_directory = '/Users/quinn/Dropbox (VTFRS)/Research/DAPPER_inputdata/'
run_name = 'Duke_without_Ctrans.1.2017-08-09.07.32.07.Rdata'
#restart_chain = 'duke_state_space_without_trans_2.1.2017-07-21.13.19.13.Rdata'
restart_chain =  'BG_SS2_val1.1.2017-08-26.10.11.10.Rdata'
priors_file = 'default_priors.csv'
obs_set = 21 #14 #Select which plots are used in analysis.  See prepare_obs.R for number guide 
focal_plotID = 30017 #14 #Select which plots are used in analysis.  See prepare_obs.R for number guide 
fr_model = 1  # 1 = estimate FR for each plot, 2 = empirical FR model
FR_fert_assumption = 0 #0 = assume fertilization plots have FR = 1, 1 = do not assume fertilization plots have FR = 1
use_fol = TRUE  #TRUE= use allometric estimates of foliage biomass in fitting
use_dk_pars = 1  #0 = do not use 3 specific parameters for the Duke site, 1 = use the 3 specific parameters
nstreams = 19
state_space = 1
plotFR = NA
PARAMETER_UNCERTAINITY = FALSE
windows_machine = FALSE

load(paste(working_directory,'/chains/',restart_chain,sep=''))

all_studies = c(
  '/SETRES/TIER4_SETRES',
  '/PINEMAP/TIER3_PINEMAP',
  '/NC2/TIER4_NC2',
  '/Duke/TIER4_Duke',
  '/FMC_Thinning/TIER1_FMC_Thinning',
  #'/FBRC_AMERIFLU/TIER2_AMERIFLU',
  #'/FBRC_IMPAC/TIER1_IMPAC',
  #'/FBRC_IMPAC2/TIER2_IMPAC2',
  #'/FBRC_PPINES/TIER2_PPINES',
  #'/FBRC_VAR1/TIER2_VAR1',
  #'/FBRC_WPPINES/TIER2_WPPINES',
  #'/FMC_IMP/TIER2_IMP',
  #'/FPC_RS1/TIER1_RS1',
  #'/FPC_RS2/TIER1_RS2',
  #'/FPC_RS3/TIER1_RS3',
  #'/FPC_RS5/TIER1_RS5',
  #'/FPC_RS6/TIER1_RS6',
  #'/FPC_RS7/TIER1_RS7',
  #'/FPC_RS8/TIER1_RS8',
  #'/FPC_RW18/TIER2_RW18',
  #'/FPC_RW19/TIER2_RW19',
  '/FPC_RW20/TIER2_RW20'
  #'/PMRC_CPCD96_TIER1/TIER1_CPCD96',
  #'/PMRC_CPCD96_TIER2/TIER2_CPCD96',
  #'/PMRC_HGLOB87/TIER1_HGLOB87',
  #'/PMRC_SAGCD96_TIER1/TIER1_SAGCD96',
  #'/PMRC_SAGCD96_TIER2/TIER2_SAGCD96',
  #'/PMRC_SAGSP85_TIER1/TIER1_SAGSP85',
  #'/PMRC_SAGSP85_TIER2/TIER2_SAGSP85',
  #'/PMRC_WGCD01_TIER1/TIER1_WGCD01',
  #'/PMRC_WGCD01_TIER2/TIER2_WGCD01',
  #'/TAMU_GSSS/TIER1_GSSS'
)
#----------------------------------------------------

#---SELECT COMPONENTS THAT ARE ALLOWED TO HAVE UNCERTAINITY--
#plot_WSx1000 = FALSE  #include plot specific WSx1000 parameter
#plot_thinpower = FALSE #include plot specific thinpower parameter
#plot_mort_rate = FALSE #include plot specific mortality rate parameter

#----------------------------------------------------

#----------------------------------------------------

#--OTHER INFO (WON'T CHANGE UNLESS MODIFY MODEL)-----
npars_used_by_fortran = 48
noutput_variables = 68
process_model_pars = 51
npars =80

#---- ENTER THE FORTRAN LIBRARY NAMES HERE ----------
if(windows_machine){
  code_library_plot = paste(working_directory,'/source_code/r3pg_interface.dll',sep='')
}else{
  code_library_plot = paste(working_directory,'/source_code/r3pg_interface.so',sep='')
}

final_pdf = paste(working_directory,'/figures/',run_name,'.pdf',sep='')

setwd(paste(working_directory,'/scripts/',sep=''))
source('prepare_obs.R')
source('prepare_state_space_obs.R')
source('assign_control_plots.R')
source('prepare_met.R')
#source('initialize_pars.R')
source('init_state_space.R')

setwd(working_directory)
#----------------------------------------------------

priors_in = read.csv(paste(working_directory,'/priors/',priors_file,sep=''))
npars = length(priors_in$parnames)
priormatrix = matrix(NA,npars,6)
priormatrix[,1] = priors_in$initial_value
priormatrix[,2] = priors_in$dist_par1
priormatrix[,3] = priors_in$dist_par2
priormatrix[,4] = priors_in$dist_type
priormatrix[,5] = priors_in$fit_par
priormatrix[,6] = priors_in$par_group

parnames = priors_in$parnames

#---  PREPARE OBSERVATIONS ---------------------------
obs_list = prepare_obs(obs_set,FR_fert_assumption,use_fol)
plotlist = obs_list$plotlist
StudyName = obs_list$StudyName
Treatment = obs_list$Treatment
nplots= obs_list$nplots
observations= obs_list$observations
initdata= obs_list$initdata
met_in = obs_list$met_in
co2_in = obs_list$co2_in
use_fol_state = obs_list$use_fol_state
#-------------------------------------------------

state_space_obs = prepare_state_space_obs()
mo_start_end=state_space_obs$mo_start_end
years = state_space_obs$years
months = state_space_obs$months
nmonths = state_space_obs$nmonths
obs = state_space_obs$obs
thin_event = state_space_obs$thin_event
obs_uncert = state_space_obs$obs_uncert
init_obs = state_space_obs$init_obs
init_uncert = state_space_obs$init_uncert


#----SET CONTROL PLOT INDEX---------------------------------------
# this assigns the control plot to match with the treatment plot

control_list = assign_control_plots(nplots,initdata,plotlist)
control_plot_index =  control_list$control_plot_index
matched_FR_plot_index = control_list$matched_FR_plot_index

#--- CREATE CLIMATE INPUT ARRAYS --------------------------------
met_tmp = prepare_met(met_in,initdata,mo_start_end,co2_in,nplots,nmonths,months,years)
met = array(NA,dim=c(nplots,6,length(met_tmp$tmin[1,])))
met[,1,] = met_tmp$tmin
met[,2,] = met_tmp$tmax
met[,3,] = met_tmp$precip
met[,4,] = met_tmp$ra
met[,5,] = met_tmp$frost
met[,6,] = met_tmp$co2

#-----INDEXING FOR THE PARAMETER VECTOR--------------------------
# this helps speed up the analysis -----------------------------

#index_guide = create_index_guide(npars,nplots)

#-----TURN OFF HARDWOOD SIMULATION (0 = HARDWOODS ARE SIMULATED)-------
exclude_hardwoods = array(1,dim=nplots)
exclude_hardwoods[which(initdata$PlotID >= 40000 & initdata$PlotID < 42000)]=0

init_pars = priormatrix[,1]
latent = obs


dyn.load(code_library_plot)

plotnum = 1

nsamples = 1000

age = array(-99,dim=c(nsamples,nplots,nmonths))
lai  = array(-99,dim=c(nsamples,nplots,nmonths))
stem  = array(-99,dim=c(nsamples,nplots,nmonths))
stem_density = array(-99,dim=c(nsamples,nplots,nmonths))
coarse_root= array(-99,dim=c(nsamples,nplots,nmonths))
fine_root = array(-99,dim=c(nsamples,nplots,nmonths))
fol= array(-99,dim=c(nsamples,nplots,nmonths))
total= array(-99,dim=c(nsamples,nplots,nmonths))
fSW= array(-99,dim=c(nsamples,nplots,nmonths))
ET= array(-99,dim=c(nsamples,nplots,nmonths))
Total_Ctrans= array(-99,dim=c(nsamples,nplots,nmonths))
GPP= array(-99,dim=c(nsamples,nplots,nmonths))
runoff= array(0,dim=c(nsamples,nplots,nmonths))
WUE_ctrans= array(-99,dim=c(nsamples,nplots,nmonths))
WUE_ET= array(-99,dim=c(nsamples,nplots,nmonths))

median_pars = rep(NA,npars)
for(p in 1:npars){
  median_pars[p] = median(accepted_pars_thinned_burned[,p])
}


for(s in 1:nsamples){
  
  
  if(!PARAMETER_UNCERTAINITY){
    new_pars = median_pars
  }else{
    curr_sample = sample(seq(1,length(accepted_pars_thinned_burned[,1])),1)   
    new_pars = accepted_pars_thinned_burned[curr_sample,]
  }
  pars = new_pars[1:npars_used_by_fortran]
  

  tmp_initdata = initdata[plotnum,]
  
  PlotID = initdata[plotnum,1]
  SiteID = initdata[plotnum,2]
  LAT_WGS84=initdata[plotnum,3]
  Planting_year = initdata[plotnum,4]
  PlantMonth = initdata[plotnum,5]
  PlantDensityHa = initdata[plotnum,6]
  Initial_ASW = initdata[plotnum,7]
  ASW_min = initdata[plotnum,8]
  ASW_max=initdata[plotnum,9]
  SoilClass = initdata[plotnum,10]
  SI = initdata[plotnum,11]
  FR = initdata[plotnum,12]
  Initial_WF = initdata[plotnum,13]
  Initial_WS = initdata[plotnum,14]
  Initial_WR = initdata[plotnum,15]
  DroughtLevel = initdata[plotnum,16]
  DroughtStart = initdata[plotnum,17]
  FertFlag=initdata[plotnum,18]
  CO2flag = initdata[plotnum,19]
  CO2elev = initdata[plotnum,20]
  ControlPlotID = initdata[plotnum,21]
  Initial_WF_H = initdata[plotnum,22]
  Initial_WS_H =initdata[plotnum,23]
  Initial_WR_H =initdata[plotnum,24]
  InitialYear = initdata[plotnum,29]
  InitialMonth = initdata[plotnum,30]
  StartAge = initdata[plotnum,31] 
  IrrFlag = initdata[plotnum,33] 
  Mean_temp = initdata[plotnum,26]
  
  if(!is.na(plotFR)){
    FR = new_FR
  }else{
    FR = 1/(1+exp((new_pars[49] + new_pars[50]*Mean_temp-new_pars[51]*SI)))
  }
  
  
  PlantedYear = 0
  PlantedMonth = 0
  
  InitialYear = years[mo_start_end[plotnum]]
  InitialMonth = months[mo_start_end[plotnum]]
  
  WFi=initdata[plotnum,13]
  WSi=initdata[plotnum,14]
  WRi=initdata[plotnum,15]
  WCRi=initdata[plotnum,32]
  
  WFi_H = initdata[plotnum,22]
  WSi_H = initdata[plotnum,23]
  WRi_H = initdata[plotnum,24]
  
  StemNum = PlantDensityHa
  nomonths_plot = mo_start_end[plotnum,2] - mo_start_end[plotnum,1]+1
  
  #READ IN SITE DATA FROM FILE BASED ON PLOTNUM
  Lat = LAT_WGS84
  ASWi = ASW_max
  MaxASW = ASW_max
  MinASW = ASW_min
  SoilClass=SoilClass

  if(!is.na(plotFR)){
    FR = new_FR
  }else{
    FR = 1/(1+exp((new_pars[49] + new_pars[50]*Mean_temp-new_pars[51]*SI)))
  }
  
  if(initdata[plotnum,12] == 1) { FR = 1}
  
  IrrigRate = 0.0
  if(IrrFlag == 1){
    IrrigRate = (658/9)
  }
  
  tmp_site_index = 0
  if(PlotID > 40000 & PlotID < 41000 & use_dk_pars == 1){
    tmp_site_index = 1
  }
  
  SLA = 3.5754 + (5.4287 - 3.5754) * exp(-log(2) * (StartAge / 5.9705)^2)
  SLA_h = 16.2
  
  site_in = c(PlantedYear, #PlantedYear
              PlantedMonth, #"PlantedMonth"
              InitialYear, #"InitialYear"
              InitialMonth, #"InitialMonth"
              StartAge, #"EndAge"
              WFi, #"WFi"
              WRi, #"WRi"
              WSi, #"WSi"
              StemNum, #"StemNoi"
              ASWi, #"ASWi"
              Lat, #"Lat"
              FR, #"FR"
              SoilClass, #"SoilClass"
              MaxASW, #"MaxASW"
              MinASW, #"MinASW"
              TotalMonths = 1,
              WFi_H = Initial_WF_H,
              WSi_H = Initial_WS_H,
              WRi_H = Initial_WR_H,
              WCRi,
              IrrigRate = IrrigRate,
              Throughfall = DroughtLevel,
              tmp_site_index,  
              WCRi_H = WSi_H*0.30,
              Wbud_H = 0.0,
              LAI = tmp_initdata$Initial_LAI,
              LAI_h = WFi_H * SLA_h *0.1
  )
  
  site = array(site_in)
  
  #THIS DEALS WITH THINNING BASED ON PROPORTION OF STEMS REMOVED
  thin_event = array(0,dim=c(nplots,nmonths))
  
  
  output_dim = noutput_variables  # NUMBER OF OUTPUT VARIABLES
  nosite = length(site_in)  # LENGTH OF SITE ARRAY
  nomet = 6  # NUMBER OF VARIABLES IN METEROLOGY (met)
  nopars = length(pars)
  
  #Wsx1000 (plot level variability in parameter)
  # pars[19] = new_pars[index_guide[5]+plotnum - 1]
  #thinpower (plot level variability in parameter)
  #  pars[20] = new_pars[index_guide[7]+plotnum - 1]
  #  pars[40] = new_pars[index_guide[9]+plotnum - 1]    
  #Read in Fortran code
  if(PlotID > 40000 & PlotID < 41000){
    pars[19] = new_pars[48]
  }
  
  
  mo_index = 0
  for(mo in mo_start_end[plotnum,1]:mo_start_end[plotnum,2]){
    mo_index = mo_index + 1
    
    
    tmp=.Fortran( "r3pg_interface",
                  output_dim=as.integer(output_dim),
                  met=as.double(met[plotnum,,mo]),
                  pars=as.double(pars),
                  site = as.double(site),
                  thin_event = as.double(thin_event[plotnum,mo]),
                  out_var=as.double(array(0,dim=c(1,output_dim))),
                  nopars=as.integer(nopars),
                  nomet=as.integer(dim(met)[2]),
                  nosite = as.integer(nosite),
                  nooutputs=as.integer(output_dim),
                  nomonths_plot=as.integer(1),
                  nothin = 1,
                  exclude_hardwoods = as.integer(exclude_hardwoods[plotnum]),
                  mo_start_end = as.integer(c(1,1)),
                  nmonths = 1
    )
    
    output=array(tmp$out_var, dim=c(nomonths_plot,output_dim))
    
    if(output[2] == 12){
      site[3] = output[1]+1 #InitialYear
      site[4] = 1  #InitialMonth
    }else{
      site[3] = output[1] #InitialYear
      site[4] = output[2]+1  #InitialMonth	
    }
    site[5] = output[3] + (1.0/12.) #StartAge
    site[26] = rnorm(1,output[4],new_pars[52]) #LAI
    if(site[26] < 0.0) {site[26]=0.1}
    site[8] = rnorm(1,output[5],(0.5+ new_pars[53] +output[5]*new_pars[64]))  #WS
    site[20] = rnorm(1,output[6],new_pars[54])   #WCR
    site[7] = rnorm(1,output[7],new_pars[55])  #WRi
    site[9] = rnorm(1,output[8],new_pars[56]) #StemNo
    
    site[27] = max(rnorm(1,output[9],new_pars[52]),0.0)  #Hardwood LAI
    site[25] = output[26] #Hardwood Bud
    site[18] = rnorm(1,output[10],new_pars[57]) #WS_H 
    site[24] = output[11]  #WCR_h
    site[19] = rnorm(1,output[12],new_pars[55]) #WR_H
    
    site[10] = output[14] # ASW
    
    site[6] = output[22] #WFi
    site[17] = output[23] #WF_H	
    
    age[s,plotnum,mo] = output[3]
    lai[s,plotnum,mo]  = site[26]
    stem[s,plotnum,mo]  = site[8]
    stem_density[s,plotnum,mo] = site[9]
    coarse_root[s,plotnum,mo] = site[20]
    fine_root[s,plotnum,mo] = site[7]
    fol[s,plotnum,mo] = output[22]
    total[s,plotnum,mo] = fol[s,plotnum,mo] +  stem[s,plotnum,mo] +  fine_root[s,plotnum,mo] + coarse_root[s,plotnum,mo]
    fSW[s,plotnum,mo] = output[49]
    ET[s,plotnum,mo]= output[17]
    Total_Ctrans[s,plotnum,mo]= output[18] + output[19]
    GPP[s,plotnum,mo]= output[22]*0.5
    #runoff[s,plotnum,mo]= output[40] 
    if(mo > mo_start_end[plotnum,1]){
    runoff[s,plotnum,mo]= runoff[s,plotnum,mo-1] + output[40] 
    }else{
      runoff[s,plotnum,mo]= output[40]    
    }
    WUE_ctrans[s,plotnum,mo]= GPP[s,plotnum,mo]/ET[s,plotnum,mo]
    WUE_ET[s,plotnum,mo]= GPP[s,plotnum,mo]/Total_Ctrans[s,plotnum,mo]
  }
}

age = age[,,mo_start_end[plotnum,1]:mo_start_end[plotnum,2]]
lai = lai[,,mo_start_end[plotnum,1]:mo_start_end[2]]
stem = stem[,,mo_start_end[plotnum,1]:mo_start_end[2]]
stem_density = stem_density[,,mo_start_end[plotnum,1]:mo_start_end[2]]
coarse_root = coarse_root[,,mo_start_end[plotnum,1]:mo_start_end[2]]
fine_root = fine_root[,,mo_start_end[plotnum,1]:mo_start_end[2]]
fol = fol[,,mo_start_end[plotnum,1]:mo_start_end[2]]
total = total[,,mo_start_end[plotnum,1]:mo_start_end[2]]
fSW = fSW[,,mo_start_end[plotnum,1]:mo_start_end[2]]
ET = ET[,,mo_start_end[plotnum,1]:mo_start_end[2]]
Total_Ctrans = Total_Ctrans[,,mo_start_end[plotnum,1]:mo_start_end[2]]
GPP = GPP[,,mo_start_end[plotnum,1]:mo_start_end[2]]
runoff = runoff[,,mo_start_end[plotnum,1]:mo_start_end[2]]
WUE_ctrans = WUE_ctrans[,,mo_start_end[plotnum,1]:mo_start_end[2]]
WUE_ET = WUE_ET[,,mo_start_end[plotnum,1]:mo_start_end[2]]


LAI_quant = array(NA,dim=c(length(age[1,]),3))
stem_quant = array(NA,dim=c(length(age[1,]),3))
stem_density_quant = array(NA,dim=c(length(age[1,]),3))
coarse_root_quant = array(NA,dim=c(length(age[1,]),3))
fine_root_quant = array(NA,dim=c(length(age[1,]),3))
fol_quant = array(NA,dim=c(length(age[1,]),3))
total_quant = array(NA,dim=c(length(age[1,]),3))
fSW_quant = array(NA,dim=c(length(age[1,]),3))
ET_quant = array(NA,dim=c(length(age[1,]),3))
Total_Ctrans_quant = array(NA,dim=c(length(age[1,]),3))
GPP_quant = array(NA,dim=c(length(age[1,]),3))
runoff_quant = array(NA,dim=c(length(age[1,]),3))
WUE_ctrans_quant = array(NA,dim=c(length(age[1,]),3))
WUE_ET_quant = array(NA,dim=c(length(age[1,]),3))

modeled_age = age[1,]
for(i in 1:length(modeled_age)){
  LAI_quant[i,] = quantile(lai[,i],c(0.025,0.5,0.975))
  stem_quant[i,] = quantile(stem[,i],c(0.025,0.5,0.975))
  stem_density_quant[i,] = quantile(stem_density[,i],c(0.025,0.5,0.975))
  coarse_root_quant[i,] = quantile(coarse_root[,i],c(0.025,0.5,0.975))
  fine_root_quant[i,] = quantile(fine_root[,i],c(0.025,0.5,0.975))
  fol_quant[i,] = quantile(fol[,i],c(0.025,0.5,0.975))
  total_quant[i,] = quantile(total[,i],c(0.025,0.5,0.975))
  fSW_quant[i,] = quantile(fSW[,i],c(0.025,0.5,0.975))
  ET_quant[i,] = quantile(ET[,i],c(0.025,0.5,0.975)) 
  Total_Ctrans_quant[i,] = quantile(Total_Ctrans[,i],c(0.025,0.5,0.975))
  GPP_quant[i,] = quantile(GPP[,i],c(0.025,0.5,0.975))
  runoff_quant[i,] = quantile(runoff[,i],c(0.025,0.5,0.975))
  WUE_ctrans_quant[i,] = quantile(WUE_ctrans[,i],c(0.025,0.5,0.975))
  WUE_ET_quant[i,] = quantile(WUE_ET[,i],c(0.025,0.5,0.975))
}

pdf(paste(working_directory,'/figures/',run_name,'.pdf',sep=''),width = 11,height = 11)
par(mfrow=c(3,4),mar = c(4,4,2,2),oma = c(3,3,2,2))
plot(modeled_age,LAI_quant[,2],type='l',ylim=range(LAI_quant),xlab = 'Stand Age',ylab = 'Leaf Area Index')
polygon(c(modeled_age,rev(modeled_age)),c(LAI_quant[,1],rev(LAI_quant[,3])),col="lightblue",border=NA)
points(modeled_age,LAI_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,stem_quant[,2],type='l',ylim=range(stem_quant), xlab = 'Stand Age',ylab = 'Stem Biomass (Mg/ha)')
polygon(c(modeled_age,rev(modeled_age)),c(stem_quant[,1],rev(stem_quant[,3])),col="lightblue",border=NA)
points(modeled_age,stem_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,total_quant[,2],type='l',ylim=range(total_quant), xlab = 'Stand Age',ylab = 'Total Biomass (Mg/ha)')
polygon(c(modeled_age,rev(modeled_age)),c(total_quant[,1],rev(total_quant[,3])),col="lightblue",border=NA)
points(modeled_age,total_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,stem_density_quant[,2],type='l',ylim=range(stem_density_quant), xlab = 'Stand Age',ylab = 'Stem Density (ind/ha)')
polygon(c(modeled_age,rev(modeled_age)),c(stem_density_quant[,1],rev(stem_density_quant[,3])),col="lightblue",border=NA)
points(modeled_age,stem_density_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,fSW_quant[,2],type='l',ylim=c(0,1), xlab = 'Stand Age',ylab = 'fSW')
polygon(c(modeled_age,rev(modeled_age)),c(fSW_quant[,1],rev(fSW_quant[,3])),col="lightblue",border=NA)
points(modeled_age,fSW_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,ET_quant[,2],type='l',ylim=range(c(ET_quant)), xlab = 'Stand Age',ylab = 'ET')
polygon(c(modeled_age,rev(modeled_age)),c(ET_quant[,1],rev(ET_quant[,3])),col="lightblue",border=NA)
points(modeled_age,ET_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,Total_Ctrans_quant[,2],type='l',ylim=range(c(Total_Ctrans_quant)), xlab = 'Stand Age',ylab = 'Transpiration')
polygon(c(modeled_age,rev(modeled_age)),c(Total_Ctrans_quant[,1],rev(Total_Ctrans_quant[,3])),col="lightblue",border=NA)
points(modeled_age,Total_Ctrans_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,GPP_quant[,2],type='l',ylim=range(c(GPP_quant)), xlab = 'Stand Age',ylab = 'GPP')
polygon(c(modeled_age,rev(modeled_age)),c(GPP_quant[,1],rev(GPP_quant[,3])),col="lightblue",border=NA)
points(modeled_age,GPP_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,runoff_quant[,2],type='l',ylim=range(runoff_quant), xlab = 'Stand Age',ylab = 'Runoff')
polygon(c(modeled_age,rev(modeled_age)),c(runoff_quant[,1],rev(runoff_quant[,3])),col="lightblue",border=NA)
points(modeled_age,runoff_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,WUE_ctrans_quant[,2],type='l',ylim=range(c(WUE_ctrans_quant)), xlab = 'Stand Age',ylab = 'WUE (ET)')
polygon(c(modeled_age,rev(modeled_age)),c(WUE_ctrans_quant[,1],rev(WUE_ctrans_quant[,3])),col="lightblue",border=NA)
points(modeled_age,WUE_ctrans_quant[,2],type='l',col="blue",lwd=1)

plot(modeled_age,WUE_ET_quant[,2],type='l',ylim=range(c(WUE_ET_quant)), xlab = 'Stand Age',ylab = 'WUE (Transpiration')
polygon(c(modeled_age,rev(modeled_age)),c(WUE_ET_quant[,1],rev(WUE_ET_quant[,3])),col="lightblue",border=NA)
points(modeled_age,WUE_ET_quant[,2],type='l',col="blue",lwd=1)

#par(mfrow=c(1,1),mar = c(4,4,2,2),oma = c(3,3,2,2))
#plot(density(stem[,1,length(modeled_age)]),xlim=c(0,300),ylim=c(0,1),col='red')
#points(density(fol[,1,length(modeled_age)]),type='l',col='green')
#points(density(fine_root[,1,length(modeled_age)]),type='l',col='blue')
#points(density(coarse_root[,1,length(modeled_age)]),type='l',col='orange')
#points(density(total[,1,length(modeled_age)]),type='l',col='black')
dev.off()