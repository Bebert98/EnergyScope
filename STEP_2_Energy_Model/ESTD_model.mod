# -------------------------------------------------------------------------------------------------------------------------													
#	EnergyScope TD is an open-source energy model suitable for country scale analysis. It is a simplified representation of an urban or national energy system accounting for the energy flows												
#	within its boundaries. Based on a hourly resolution, it optimises the design and operation of the energy system while minimizing the cost of the system.												
#													
#	Copyright (C) <2018-2019> <Ecole Polytechnique Fédérale de Lausanne (EPFL), Switzerland and Université catholique de Louvain (UCLouvain), Belgium>
#													
#	Licensed under the Apache License, Version 2.0 (the "License");												
#	you may not use this file except in compliance with the License.												
#	You may obtain a copy of the License at												
#													
#		http://www.apache.org/licenses/LICENSE-2.0												
#													
#	Unless required by applicable law or agreed to in writing, software												
#	distributed under the License is distributed on an "AS IS" BASIS,												
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.												
#	See the License for the specific language governing permissions and												
#	limitations under the License.												
#													
#	Description and complete License: see LICENSE file.												
# -------------------------------------------------------------------------------------------------------------------------		


#########################
###  SETS [Figure 2.7]  ###
#########################

## MAIN SETS: Sets whose elements are input directly in the data file
set PERIODS := 1 .. 8760; # time periods (hours of the year)
set HOURS := 1 .. 24; # hours of the day
set TYPICAL_DAYS:= 1 .. 12; # typical days
set T_H_TD within {PERIODS, HOURS, TYPICAL_DAYS}; # set linking periods, hours, days, typical days
set SECTORS; # sectors of the energy system
set END_USES_INPUT; # Types of demand (end-uses). Input to the model
set END_USES_CATEGORIES; # Categories of demand (end-uses): electricity, heat, mobility
set END_USES_TYPES_OF_CATEGORY {END_USES_CATEGORIES}; # Types of demand (end-uses).
set RESOURCES; # Resources: fuels (renewables and fossils) and electricity imports
set RES_IMPORT_CONSTANT within RESOURCES; # resources imported at constant power (e.g. NG, diesel, ...)
set BIOFUELS within RESOURCES; # imported biofuels.
set EXPORT within RESOURCES; # exported resources
set END_USES_TYPES := setof {i in END_USES_CATEGORIES, j in END_USES_TYPES_OF_CATEGORY [i]} j; # secondary set
set TECHNOLOGIES_OF_END_USES_TYPE {END_USES_TYPES}; # set all energy conversion technologies (excluding storage technologies and infrastructure)
set STORAGE_TECH; #  set of storage technologies 
set STORAGE_OF_END_USES_TYPES {END_USES_TYPES} within STORAGE_TECH; # set all storage technologies related to an end-use types (used for thermal solar (TS))
set INFRASTRUCTURE; # Infrastructure: DHN, grid, and intermediate energy conversion technologies (i.e. not directly supplying end-use demand)

## SECONDARY SETS: a secondary set is defined by operations on MAIN SETS
set LAYERS := (RESOURCES diff BIOFUELS diff EXPORT) union END_USES_TYPES; # Layers are used to balance resources/products in the system
set TECHNOLOGIES := (setof {i in END_USES_TYPES, j in TECHNOLOGIES_OF_END_USES_TYPE [i]} j) union STORAGE_TECH union INFRASTRUCTURE; 
set TECHNOLOGIES_OF_END_USES_CATEGORY {i in END_USES_CATEGORIES} within TECHNOLOGIES := setof {j in END_USES_TYPES_OF_CATEGORY[i], k in TECHNOLOGIES_OF_END_USES_TYPE [j]} k;
set RE_RESOURCES within RESOURCES; # List of RE resources (including wind hydro solar), used to compute the RE share
set V2G within TECHNOLOGIES;   # EVs which can be used for vehicle-to-grid (V2G).
set EVs_BATT   within STORAGE_TECH; # specific battery of EVs
set EVs_BATT_OF_V2G {V2G}; # Makes the link between batteries of EVs and the V2G technology
set STORAGE_DAILY within STORAGE_TECH;# Storages technologies for daily application 
set TS_OF_DEC_TECH {TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}} ; # Makes the link between TS and the technology producing the heat

##Additional SETS added just to simplify equations.
set TYPICAL_DAY_OF_PERIOD {t in PERIODS} := setof {h in HOURS, td in TYPICAL_DAYS: (t,h,td) in T_H_TD} td; #TD_OF_PERIOD(T)
set HOUR_OF_PERIOD {t in PERIODS} := setof {h in HOURS, td in TYPICAL_DAYS: (t,h,td) in T_H_TD} h; #H_OF_PERIOD(T)

## Additional SETS: only needed for printing out results (not represented in Figure 3).
set COGEN within TECHNOLOGIES; # cogeneration tech
set BOILERS within TECHNOLOGIES; # boiler tech

#################################
### PARAMETERS [Tables 2.2]   ###
#################################

## COMMENT GL : in this version, only Energy invested, cost and gwp were implemented for criteria. If other criteria should be added,
##              I would suggest to create a set CRITERIA which is used in 3 parameters : constr (such as c_inv, gwp_constr), op (such as c_op, ....) and also for variables. 
##              This approaches enables to have a lighter code than the one proposed by Gauthier Neve & Bastien Muyldermans.


## Parameters added to include time series in the model:
param electricity_time_series {HOURS, TYPICAL_DAYS} >= 0, <= 1; # %_elec [-]: factor for sharing lighting across typical days (adding up to 1)
param heating_time_series {HOURS, TYPICAL_DAYS} >= 0, <= 1; # %_sh [-]: factor for sharing space heating across typical days (adding up to 1)
param mob_pass_time_series {HOURS, TYPICAL_DAYS} >= 0, <= 1; # %_pass [-]: factor for sharing passenger transportation across Typical days (adding up to 1) based on https://www.fhwa.dot.gov/policy/2013cpr/chap1.cfm
param mob_freight_time_series {HOURS, TYPICAL_DAYS} >= 0, <= 1; # %_fr [-]: factor for sharing freight transportation across Typical days (adding up to 1)
param c_p_t {TECHNOLOGIES, HOURS, TYPICAL_DAYS} default 1; #Hourly capacity factor [-]. If = 1 (default value) <=> no impact.

## Parameters added to define scenarios and technologies:
param end_uses_demand_year {END_USES_INPUT, SECTORS} >= 0 default 0; # end_uses_year [GWh]: table end-uses demand vs sectors (input to the model). Yearly values. [Mpkm] or [Mtkm] for passenger or freight mobility.
param end_uses_input {i in END_USES_INPUT} := sum {s in SECTORS} (end_uses_demand_year [i,s]); # end_uses_input (Figure 1.4) [GWh]: total demand for each type of end-uses across sectors (yearly energy) as input from the demand-side model. [Mpkm] or [Mtkm] for passenger or freight mobility.
param i_rate > 0; # discount rate [-]: real discount rate
param re_share_primary >= 0; # re_share [-]: minimum share of primary energy coming from RE
param gwp_limit >= 0, default 'Infinity';    # [ktCO2-eq./year] maximum gwp emissions allowed.
param einv_limit >= 0, default 'Infinity'; # [GWh/year] maximum system energy invested allowed
param cost_limit >= 0, default 'Infinity'; # [Meuros/year] maximum system cost allowed
param share_mobility_public_min >= 0, <= 1; # %_public,min [-]: min limit for penetration of public mobility over total mobility 
param share_mobility_public_max >= 0, <= 1; # %_public,max [-]: max limit for penetration of public mobility over total mobility 
param share_freight_train_min >= 0, <= 1; # %_rail,min [-]: min limit for penetration of train in freight transportation
param share_freight_train_max >= 0, <= 1; # %_rail,min [-]: max limit for penetration of train in freight transportation
param share_freight_boat_min  >= 0, <= 1; # %_boat,min [-]: min limit for penetration of boat in freight transportation
param share_freight_boat_max  >= 0, <= 1; # %_boat,min [-]: max limit for penetration of boat in freight transportation
param share_freight_road_min  >= 0, <= 1; # %_road,min [-]: min limit for penetration of truck in freight transportation
param share_freight_road_max  >= 0, <= 1; # %_road,min [-]: max limit for penetration of truck in freight transportation
param share_heat_dhn_min >= 0, <= 1; # %_dhn,min [-]: min limit for penetration of dhn in low-T heating
param share_heat_dhn_max >= 0, <= 1; # %_dhn,max [-]: max limit for penetration of dhn in low-T heating
param share_ned {END_USES_TYPES_OF_CATEGORY["NON_ENERGY"]} >= 0, <= 1; # %_ned [-] share of non-energy demand per type of feedstocks.
param t_op {HOURS, TYPICAL_DAYS} default 1;# [h]: operating time 
param f_max {TECHNOLOGIES} >= 0; # Maximum feasible installed capacity [GW], refers to main output. storage level [GWh] for STORAGE_TECH
param f_min {TECHNOLOGIES} >= 0; # Minimum feasible installed capacity [GW], refers to main output. storage level [GWh] for STORAGE_TECH
param fmax_perc {TECHNOLOGIES} >= 0, <= 1 default 1; # value in [0,1]: this is to fix that a technology can at max produce a certain % of the total output of its sector over the entire year
param fmin_perc {TECHNOLOGIES} >= 0, <= 1 default 0; # value in [0,1]: this is to fix that a technology can at min produce a certain % of the total output of its sector over the entire year
param avail {RESOURCES} >= 0; # Yearly availability of resources [GWh/y]
param c_op {RESOURCES} >= 0; # cost of resources in the different periods [Meuros/GWh]
param vehicule_capacity {TECHNOLOGIES} >=0, default 0; #  veh_capa [capacity/vehicles] Average capacity (pass-km/h or t-km/h) per vehicle. It makes the link between F and the number of vehicles
param peak_sh_factor >= 0;   # %_Peak_sh [-]: ratio between highest yearly demand and highest TDs demand
param layers_in_out {RESOURCES union TECHNOLOGIES diff STORAGE_TECH , LAYERS}; # f: input/output Resources/Technologies to Layers. Reference is one unit ([GW] or [Mpkm/h] or [Mtkm/h]) of (main) output of the resource/technology. input to layer (output of technology) > 0.
param c_inv {TECHNOLOGIES} >= 0; # Specific investment cost [Meuros/GW].[Meuros/GWh] for STORAGE_TECH
param c_maint {TECHNOLOGIES} >= 0; # O&M cost [Meuros/GW/year]: O&M cost does not include resource (fuel) cost. [Meuros/GWh/year] for STORAGE_TECH
param lifetime {TECHNOLOGIES} >= 0; # n: lifetime [years]
param tau {i in TECHNOLOGIES} := i_rate * (1 + i_rate)^lifetime [i] / (((1 + i_rate)^lifetime [i]) - 1); # Annualisation factor ([-]) for each different technology [Eq. 2.2]
param gwp_constr {TECHNOLOGIES} >= 0; # GWP emissions associated to the construction of technologies [ktCO2-eq./GW]. Refers to [GW] of main output
param gwp_op {RESOURCES} >= 0; # GWP emissions associated to the use of resources [ktCO2-eq./GWh]. Includes extraction/production/transportation and combustion
param einv_constr {TECHNOLOGIES} >= 0; # Cumulative Energy Demand associated to the construction of technologies [GWh/GW].
param einv_op {RESOURCES} >= 0; # Einv associated to the use of resources [GWh/GWhfuel]. Includes extraction/production/transportation and combustion
param c_p {TECHNOLOGIES} >= 0, <= 1 default 1; # yearly capacity factor of each technology [-], defined on annual basis. Different than 1 if sum {t in PERIODS} F_t (t) <= c_p * F
param storage_eff_in {STORAGE_TECH , LAYERS} >= 0, <= 1; # eta_sto_in [-]: efficiency of input to storage from layers.  If 0 storage_tech/layer are incompatible
param storage_eff_out {STORAGE_TECH , LAYERS} >= 0, <= 1; # eta_sto_out [-]: efficiency of output from storage to layers. If 0 storage_tech/layer are incompatible
param storage_losses {STORAGE_TECH} >= 0, <= 1; # %_sto_loss [-]: Self losses in storage (required for Li-ion batteries). Value = self discharge in 1 hour.
param storage_charge_time    {STORAGE_TECH} >= 0; # t_sto_in [h]: Time to charge storage (Energy to Power ratio). If value =  5 <=>  5h for a full charge.
param storage_discharge_time {STORAGE_TECH} >= 0; # t_sto_out [h]: Time to discharge storage (Energy to Power ratio). If value =  5 <=>  5h for a full discharge.
param storage_availability {STORAGE_TECH} >=0, default 1;# %_sto_avail [-]: Storage technology availability to charge/discharge. Used for EVs 
param loss_network {END_USES_TYPES} >= 0 default 0; # %_net_loss: Losses coefficient [0; 1] in the networks (grid and DHN)
param batt_per_car {V2G} >= 0; # ev_batt_size [GWh]: Battery size per EVs car technology
param state_of_charge_ev {EVs_BATT,HOURS} >= 0, default 0; # Minimum state of charge of the EV during the day. 
param c_grid_extra >=0; # Cost to reinforce the grid due to IRE penetration [Meuros/GW of (PV + Wind)].
param import_capacity >= 0; # Maximum electricity import capacity [GW]
param solar_area >= 0; # Maximum land available for PV deployment [km2]
param power_density_pv >=0 default 0;# Maximum power irradiance for PV.
param power_density_solar_thermal >=0 default 0;# Maximum power irradiance for solar thermal.


##Additional parameter (hard coded as '8760' in the thesis)
param total_time := sum {t in PERIODS, h in HOUR_OF_PERIOD [t], td in TYPICAL_DAY_OF_PERIOD [t]} (t_op [h, td]); # [h]. added just to simplify equations



#####################################
###   VARIABLES [Tables 2.3-2.4]  ###
#####################################

##Independent variables [Table 2.3] :
var Share_mobility_public >= share_mobility_public_min, <= share_mobility_public_max; # %_Public: Ratio [0; 1] public mobility over total passenger mobility
var Share_freight_train, >= share_freight_train_min, <= share_freight_train_max; # %_Fr,Rail: Ratio [0; 1] rail transport over total freight transport
var Share_freight_road, >= share_freight_road_min, <= share_freight_road_max; # %_Fr,Truck: Ratio [0; 1] Truck transport over total freight transport
var Share_freight_boat, >= share_freight_boat_min, <= share_freight_boat_max; # %_Fr,Boat: Ratio [0; 1] boat transport over total freight transport
var Share_heat_dhn, >= share_heat_dhn_min, <= share_heat_dhn_max; # %_Dhn: Ratio [0; 1] centralized over total low-temperature heat
var F {TECHNOLOGIES} >= 0; # F: Installed capacity ([GW]) with respect to main output (see layers_in_out). [GWh] for STORAGE_TECH.
var F_t {RESOURCES union TECHNOLOGIES, HOURS, TYPICAL_DAYS} >= 0; # F_t: Operation in each period [GW] or, for STORAGE_TECH, storage level [GWh]. multiplication factor with respect to the values in layers_in_out table. Takes into account c_p
var Storage_in {i in STORAGE_TECH, LAYERS, HOURS, TYPICAL_DAYS} >= 0; # Sto_in [GW]: Power input to the storage in a certain period
var Storage_out {i in STORAGE_TECH, LAYERS, HOURS, TYPICAL_DAYS} >= 0; # Sto_out [GW]: Power output from the storage in a certain period
var Power_nuclear  >=0; # [GW] P_Nuc: Constant load of nuclear
var Shares_mobility_passenger {TECHNOLOGIES_OF_END_USES_CATEGORY["MOBILITY_PASSENGER"]} >=0; # %_PassMob [-]: Constant share of passenger mobility
var Shares_mobility_freight {TECHNOLOGIES_OF_END_USES_CATEGORY["MOBILITY_FREIGHT"]} >=0; # %_FreightMob [-]: Constant share of passenger mobility
var Shares_lowT_dec {TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}}>=0 ; # %_HeatDec [-]: Constant share of heat Low T decentralised + its specific thermal solar
var F_solar         {TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}} >=0; # F_sol [GW]: Solar thermal installed capacity per heat decentralised technologies
var F_t_solar       {TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}, h in HOURS, td in TYPICAL_DAYS} >= 0; # F_t_sol [GW]: Solar thermal operating per heat decentralised technologies

##Dependent variables [Table 2.4] :
var End_uses {LAYERS, HOURS, TYPICAL_DAYS} >= 0; #EndUses [GW]: total demand for each type of end-uses (hourly power). Defined for all layers (0 if not demand). [Mpkm] or [Mtkm] for passenger or freight mobility.
var TotalCost >= 0; # C_tot [ktCO2-eq./year]: Total GWP emissions in the system.
var C_inv {TECHNOLOGIES} >= 0; #C_inv [Meuros]: Total investment cost of each technology
var C_maint {TECHNOLOGIES} >= 0; #C_maint [Meuros/year]: Total O&M cost of each technology (excluding resource cost)
var C_op {RESOURCES} >= 0; #C_op [Meuros/year]: Total O&M cost of each resource
var TotalGWP >= 0; # GWP_tot [ktCO2-eq./year]: Total global warming potential (GWP) emissions in the system
var GWP_constr {TECHNOLOGIES} >= 0; # GWP_constr [ktCO2-eq.]: Total emissions of the technologies
var GWP_op {RESOURCES} >= 0; #  GWP_op [ktCO2-eq.]: Total yearly emissions of the resources [ktCO2-eq./y]
var TotalEinv >= 0; # Einv_tot [MJ/year]: Total Cumulative energy demand (Einv) in the system
var Einv_constr {TECHNOLOGIES} >= 0; #Total Einv of the technologies
var Einv_op {RESOURCES} >= 0; # Total yearly Einv of the resources
var Network_losses {END_USES_TYPES, HOURS, TYPICAL_DAYS} >= 0; # Net_loss [GW]: Losses in the networks (normally electricity grid and DHN)
var Storage_level {STORAGE_TECH, PERIODS} >= 0; # Sto_level [GWh]: Energy stored at each period

#############################################
###      CONSTRAINTS Eqs [2.1-2.39]       ###
#############################################

## End-uses demand calculation constraints 
#-----------------------------------------

# [Figure 2.8] From annual energy demand to hourly power demand. End_uses is non-zero only for demand layers.
subject to end_uses_t {l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
	End_uses [l, h, td] = (if l == "ELECTRICITY" 
		then
			(end_uses_input[l] / total_time + end_uses_input["LIGHTING"] * electricity_time_series [h, td] / t_op [h, td] ) + Network_losses [l,h,td]
		else (if l == "HEAT_LOW_T_DHN" then
			(end_uses_input["HEAT_LOW_T_HW"] / total_time + end_uses_input["HEAT_LOW_T_SH"] * heating_time_series [h, td] / t_op [h, td] ) * Share_heat_dhn + Network_losses [l,h,td]
		else (if l == "HEAT_LOW_T_DECEN" then
			(end_uses_input["HEAT_LOW_T_HW"] / total_time + end_uses_input["HEAT_LOW_T_SH"] * heating_time_series [h, td] / t_op [h, td] ) * (1 - Share_heat_dhn)
		else (if l == "MOB_PUBLIC" then
			(end_uses_input["MOBILITY_PASSENGER"] * mob_pass_time_series [h, td] / t_op [h, td]  ) * Share_mobility_public
		else (if l == "MOB_PRIVATE" then
			(end_uses_input["MOBILITY_PASSENGER"] * mob_pass_time_series [h, td] / t_op [h, td]  ) * (1 - Share_mobility_public)
		else (if l == "MOB_FREIGHT_RAIL" then
			(end_uses_input["MOBILITY_FREIGHT"]   * mob_freight_time_series [h, td] / t_op [h, td] ) *  Share_freight_train
		else (if l == "MOB_FREIGHT_ROAD" then
			(end_uses_input["MOBILITY_FREIGHT"]   * mob_freight_time_series [h, td] / t_op [h, td] ) *  Share_freight_road
		else (if l == "MOB_FREIGHT_BOAT" then
			(end_uses_input["MOBILITY_FREIGHT"]   * mob_freight_time_series [h, td] / t_op [h, td] ) *  Share_freight_boat
		else (if l == "HEAT_HIGH_T" then
			end_uses_input[l] / total_time
		else (if l == "HVC" then
			end_uses_input["NON_ENERGY"] * share_ned ["HVC"] / total_time
		else (if l == "AMMONIA" then
			end_uses_input["NON_ENERGY"] * share_ned ["AMMONIA"] / total_time
		else (if l == "METHANOL" then
			end_uses_input["NON_ENERGY"] * share_ned ["METHANOL"] / total_time
		else 
			0 )))))))))))); # For all layers which don't have an end-use demand


## Cost
#------

# [Eq. 2.1]	
subject to totalcost_cal:
	TotalCost = sum {j in TECHNOLOGIES} (tau [j]  * C_inv [j] + C_maint [j]) + sum {i in RESOURCES} C_op [i];
	
# [Eq. 2.3] Investment cost of each technology
subject to investment_cost_calc {j in TECHNOLOGIES}: 
	C_inv [j] = c_inv [j] * F [j];
		
# [Eq. 2.4] O&M cost of each technology
subject to main_cost_calc {j in TECHNOLOGIES}: 
	C_maint [j] = c_maint [j] * F [j];		

# [Eq. 2.5] Total cost of each resource
subject to op_cost_calc {i in RESOURCES}:
	C_op [i] = sum {t in PERIODS, h in HOUR_OF_PERIOD [t], td in TYPICAL_DAY_OF_PERIOD [t]} (c_op [i] * F_t [i, h, td] * t_op [h, td] ) ;

## GHG Emissions
#-----------

# [Eq. 2.6]
subject to totalGWP_calc:
	TotalGWP = sum {j in TECHNOLOGIES} (GWP_constr [j] / lifetime [j]) + sum {i in RESOURCES} GWP_op [i];
	#JUST RESOURCES :          TotalGWP = sum {i in RESOURCES} GWP_op [i];
	#INCLUDING GREY EMISSIONS: TotalGWP = sum {j in TECHNOLOGIES} (GWP_constr [j] / lifetime [j]) + sum {i in RESOURCES} GWP_op [i];
	
# [Eq. 2.7]
subject to gwp_constr_calc {j in TECHNOLOGIES}:
	GWP_constr [j] = gwp_constr [j] * F [j];

# [Eq. 2.8]
subject to gwp_op_calc {i in RESOURCES}:
	GWP_op [i] = gwp_op [i] * sum {t in PERIODS, h in HOUR_OF_PERIOD [t], td in TYPICAL_DAY_OF_PERIOD [t]} ( F_t [i, h, td] * t_op [h, td] );	

##Cumulative energy demand:
#--------------------------

# [Eq. XX]
subject to totalEinv_calc:
	TotalEinv = sum {j in TECHNOLOGIES} (Einv_constr [j] / lifetime [j]) + sum {i in RESOURCES} Einv_op [i];
	#JUST RESOURCES :          TotalEinv = sum {i in RESOURCES} Einv_op [i];
	#JUST GREY EMISSIONS:	   TotalEinv = sum {j in TECHNOLOGIES} (Einv_constr [j] / lifetime [j]);
	#INCLUDING GREY EMISSIONS: TotalEinv = sum {j in TECHNOLOGIES} (Einv_constr [j] / lifetime [j]) + sum {i in RESOURCES} Einv_op [i];
	
# [Eq. XX]
subject to einv_constr_calc {j in TECHNOLOGIES}:
	Einv_constr [j] = einv_constr [j] * F [j];

# [Eq. XX]
subject to einv_op_calc {i in RESOURCES}:
	Einv_op [i] = einv_op [i] * sum {t in PERIODS, h in HOUR_OF_PERIOD [t], td in TYPICAL_DAY_OF_PERIOD [t]} ( F_t [i, h, td] * t_op [h, td] );


	
## Multiplication factor
#-----------------------
	
# [Eq. 2.9] min & max limit to the size of each technology
subject to size_limit {j in TECHNOLOGIES}:
	f_min [j] <= F [j] <= f_max [j];
	
# [Eq. 2.10] relation between power and capacity via period capacity factor. This forces max hourly output (e.g. renewables)
subject to capacity_factor_t {j in TECHNOLOGIES, h in HOURS, td in TYPICAL_DAYS}:
	F_t [j, h, td] <= F [j] * c_p_t [j, h, td];
	
# [Eq. 2.11] relation between mult_t and mult via yearly capacity factor. This one forces total annual output
subject to capacity_factor {j in TECHNOLOGIES}:
	sum {t in PERIODS, h in HOUR_OF_PERIOD [t], td in TYPICAL_DAY_OF_PERIOD [t]} (F_t [j, h, td] * t_op [h, td]) <= F [j] * c_p [j] * total_time;	
		
## Resources
#-----------

# [Eq. 2.12] Resources availability equation
subject to resource_availability {i in RESOURCES}:
	sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [i, h, td] * t_op [h, td]) <= avail [i];

# [Eq. 2.12-bis] Constant flow of import for resources listed in SET RES_IMPORT_CONSTANT
var Import_constant {RES_IMPORT_CONSTANT} >= 0;
subject to resource_constant_import { i in RES_IMPORT_CONSTANT, h in HOURS, td in TYPICAL_DAYS}:
	F_t [i, h, td] * t_op [h, td] = Import_constant [i];

## Layers
#--------

# [Eq. 2.13] Layer balance equation with storage. Layers: input > 0, output < 0. Demand > 0. Storage: in > 0, out > 0;
# output from technologies/resources/storage - input to technologies/storage = demand. Demand has default value of 0 for layers which are not end_uses
subject to layer_balance {l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
		sum {i in RESOURCES union TECHNOLOGIES diff STORAGE_TECH } 
		(layers_in_out[i, l] * F_t [i, h, td]) 
		+ sum {j in STORAGE_TECH} ( Storage_out [j, l, h, td] - Storage_in [j, l, h, td] )
		- End_uses [l, h, td]
		= 0;
		
## Storage	
#---------
	
# [Eq. 2.14] The level of the storage represents the amount of energy stored at a certain time.
subject to storage_level {j in STORAGE_TECH, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}:
	Storage_level [j, t] = (if t == 1 then
	 			Storage_level [j, card(PERIODS)] * (1.0 -  storage_losses[j])
				+ t_op [h, td] * (   (sum {l in LAYERS: storage_eff_in [j,l] > 0}  (Storage_in [j, l, h, td]  * storage_eff_in  [j, l])) 
				                   - (sum {l in LAYERS: storage_eff_out [j,l] > 0} (Storage_out [j, l, h, td] / storage_eff_out [j, l])))
	else
	 			Storage_level [j, t-1] * (1.0 -  storage_losses[j])
				+ t_op [h, td] * (   (sum {l in LAYERS: storage_eff_in [j,l] > 0}  (Storage_in [j, l, h, td]  * storage_eff_in  [j, l])) 
				                   - (sum {l in LAYERS: storage_eff_out [j,l] > 0} (Storage_out [j, l, h, td] / storage_eff_out [j, l])))
				);

# [Eq. 2.15] Bounding daily storage
subject to impose_daily_storage {j in STORAGE_DAILY, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}:
	Storage_level [j, t] = F_t [j, h, td];
	
# [Eq. 2.16] Bounding seasonal storage
subject to limit_energy_stored_to_maximum {j in STORAGE_TECH diff STORAGE_DAILY , t in PERIODS}:
	Storage_level [j, t] <= F [j];# Never exceed the size of the storage unit
	
# [Eqs. 2.17-2.18] Each storage technology can have input/output only to certain layers. If incompatible then the variable is set to 0
subject to storage_layer_in {j in STORAGE_TECH, l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
	Storage_in [j, l, h, td] * (ceil (storage_eff_in [j, l]) - 1) = 0;
subject to storage_layer_out {j in STORAGE_TECH, l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
	Storage_out [j, l, h, td] * (ceil (storage_eff_out [j, l]) - 1) = 0;
		
# [Eq. 2.19] limit the Energy to power ratio for storage technologies except EV batteries
subject to limit_energy_to_power_ratio {j in STORAGE_TECH diff {"BEV_BATT","PHEV_BATT"}, l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
	Storage_in [j, l, h, td] * storage_charge_time[j] + Storage_out [j, l, h, td] * storage_discharge_time[j] <=  F [j] * storage_availability[j];
	
# [Eq. 2.19-bis] limit the Energy to power ratio for EV batteries
subject to limit_energy_to_power_ratio_bis {i in V2G, j in EVs_BATT_OF_V2G[i], l in LAYERS, h in HOURS, td in TYPICAL_DAYS}:
	Storage_in [j, l, h, td] * storage_charge_time[j] + (Storage_out [j, l, h, td] + layers_in_out[i,"ELECTRICITY"]* F_t [i, h, td]) * storage_discharge_time[j]  <= ( F [j] - F_t [i,h,td] / vehicule_capacity [i] * batt_per_car[i] ) * storage_availability[j];

## Networks
#----------------

# [Eq. 2.20] Calculation of losses for each end-use demand type (normally for electricity and DHN)
subject to network_losses {eut in END_USES_TYPES, h in HOURS, td in TYPICAL_DAYS}:
	Network_losses [eut,h,td] = (sum {j in RESOURCES union TECHNOLOGIES diff STORAGE_TECH: layers_in_out [j, eut] > 0} ((layers_in_out[j, eut]) * F_t [j, h, td])) * loss_network [eut];

# [Eq. 2.21]  Extra grid cost for integrating 1 GW of RE is estimated to 367.8Meuros per GW of intermittent renewable (27beuros to integrate the overall potential) 
subject to extra_grid:
	F ["GRID"] = 1 +  (c_grid_extra / c_inv["GRID"]) *(    (F ["WIND_ONSHORE"]     + F ["WIND_OFFSHORE"]     + F ["PV"]      )
					                                     - (f_min ["WIND_ONSHORE"] + f_min ["WIND_OFFSHORE"] + f_min ["PV"]) );

# [Eq. 2.22] DHN: assigning a cost to the network equal to the power capacity connected to the grid
subject to extra_dhn:
	F ["DHN"] = sum {j in TECHNOLOGIES diff STORAGE_TECH: layers_in_out [j,"HEAT_LOW_T_DHN"] > 0} (layers_in_out [j,"HEAT_LOW_T_DHN"] * F [j]);
	
## Additional constraints
#------------------------
	
# [Eq. 2.23] Fix nuclear production constant : 
subject to constantNuc {h in HOURS, td in TYPICAL_DAYS}:
	F_t ["NUCLEAR", h, td] = Power_nuclear;

# [Eq. 2.24] Operating strategy in mobility passenger (to make model more realistic)
# Each passenger mobility technology (j) has to supply a constant share  (Shares_mobility_passenger[j]) of the passenger mobility demand
subject to operating_strategy_mob_passenger{j in TECHNOLOGIES_OF_END_USES_CATEGORY["MOBILITY_PASSENGER"], h in HOURS, td in TYPICAL_DAYS}:
	F_t [j, h, td]   = Shares_mobility_passenger [j] * (end_uses_input["MOBILITY_PASSENGER"] * mob_pass_time_series [h, td] / t_op [h, td] );

# [Eq. 2.25] Operating strategy in mobility freight (to make model more realistic)
# Each freight mobility technology (j) has to supply a constant share  (Shares_mobility_freight[j]) of the passenger mobility demand
subject to operating_strategy_mobility_freight{j in TECHNOLOGIES_OF_END_USES_CATEGORY["MOBILITY_FREIGHT"], h in HOURS, td in TYPICAL_DAYS}:
	F_t [j, h, td]   = Shares_mobility_freight [j] * (end_uses_input["MOBILITY_FREIGHT"] * mob_freight_time_series [h, td] / t_op [h, td] );

# [Eq. 2.26] To impose a constant share in the mobility
subject to Freight_shares :
	Share_freight_train + Share_freight_road + Share_freight_boat = 1; # Should not be required (redundant)... But kept for security

	
## Thermal solar & thermal storage:

# [Eq. 2.27] relation between decentralised thermal solar power and capacity via period capacity factor.
subject to thermal_solar_capacity_factor {j in TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}, h in HOURS, td in TYPICAL_DAYS}:
	F_t_solar [j, h, td] <= F_solar[j] * c_p_t["DEC_SOLAR", h, td];
	
# [Eq. 2.28] Overall thermal solar is the sum of specific thermal solar 	
subject to thermal_solar_total_capacity :
	F ["DEC_SOLAR"] = sum {j in TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}} F_solar[j];

# [Eq. 2.29]: Decentralised thermal technology must supply a constant share of heat demand.
subject to decentralised_heating_balance  {j in TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}, i in TS_OF_DEC_TECH[j], h in HOURS, td in TYPICAL_DAYS}:
	F_t [j, h, td] + F_t_solar [j, h, td] + sum {l in LAYERS } ( Storage_out [i, l, h, td] - Storage_in [i, l, h, td])  
		= Shares_lowT_dec[j] * (end_uses_input["HEAT_LOW_T_HW"] / total_time + end_uses_input["HEAT_LOW_T_SH"] * heating_time_series [h, td] / t_op [h, td]);


## EV storage :

# [Eq. 2.30] Compute the equivalent size of V2G batteries based on the installed capacity, the capacity per vehicles and the battery capacity per EVs technology
subject to EV_storage_size {j in V2G, i in EVs_BATT_OF_V2G[j]}:
	F [i] = F[j] / vehicule_capacity [j] * batt_per_car[j];# Battery size proportional to the number of cars
	
# [Eq. 2.31]  Impose EVs to be supplied by their battery.
subject to EV_storage_for_V2G_demand {j in V2G, i in EVs_BATT_OF_V2G[j], h in HOURS, td in TYPICAL_DAYS}:
	Storage_out [i,"ELECTRICITY",h,td] >=  - layers_in_out[j,"ELECTRICITY"]* F_t [j, h, td];
		
# [Eq. 2.31-bis]  Impose a minimum state of charge at some hours of the day:
subject to ev_minimum_state_of_charge {j in V2G, i in EVs_BATT_OF_V2G[j],  t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}:
	Storage_level [i, t] >=  F [i] * state_of_charge_ev [i, h];
		
## Peak demand :

# [Eq. 2.32] Peak in decentralized heating
subject to peak_lowT_dec {j in TECHNOLOGIES_OF_END_USES_TYPE["HEAT_LOW_T_DECEN"] diff {"DEC_SOLAR"}, h in HOURS, td in TYPICAL_DAYS}:
	F [j] >= peak_sh_factor * F_t [j, h, td] ; 

# [Eq. 2.33] Calculation of max heat demand in DHN (1st constraint required to linearised the max function)
var Max_Heat_Demand >= 0;
subject to max_dhn_heat_demand {h in HOURS, td in TYPICAL_DAYS}:
	Max_Heat_Demand >= End_uses ["HEAT_LOW_T_DHN", h, td];
# Peak in DHN
subject to peak_lowT_dhn:
	sum {j in TECHNOLOGIES_OF_END_USES_TYPE ["HEAT_LOW_T_DHN"], i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"]} (F [j] + F[i]/storage_discharge_time[i]) >= peak_sh_factor * Max_Heat_Demand;


## Adaptation for the case study: Constraints needed for the application to Switzerland (not needed in standard LP formulation)
#-----------------------------------------------------------------------------------------------------------------------

# [Eq. XX]  constraint to reduce the cost subject to maximum cost reachable :
subject to Minimum_cost_reduction :
	TotalCost <= cost_limit;
	
# [Eq. 2.34]  constraint to reduce the GWP subject to Minimum_gwp_reduction :
subject to Minimum_GWP_reduction :
	TotalGWP <= gwp_limit;
	
# [Eq. XX]  constraint to reduce the GWP subject to Minimum_gwp_reduction :
subject to Minimum_einv_reduction :
	TotalEinv <= einv_limit;
	
	

# [Eq. 2.35] Minimum share of RE in primary energy supply
subject to Minimum_RE_share :
	sum {j in RE_RESOURCES, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} F_t [j, h, td] * t_op [h, td] 
	>=	re_share_primary *
	sum {j in RESOURCES, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} F_t [j, h, td] * t_op [h, td]	;
		
# [Eq. 2.36] Definition of min/max output of each technology as % of total output in a given layer. 
subject to f_max_perc {eut in END_USES_TYPES, j in TECHNOLOGIES_OF_END_USES_TYPE[eut]}:
	sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [j,h,td] * t_op[h,td]) <= fmax_perc [j] * sum {j2 in TECHNOLOGIES_OF_END_USES_TYPE[eut], t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [j2, h, td] * t_op[h,td]);
subject to f_min_perc {eut in END_USES_TYPES, j in TECHNOLOGIES_OF_END_USES_TYPE[eut]}:
	sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [j,h,td] * t_op[h,td]) >= fmin_perc [j] * sum {j2 in TECHNOLOGIES_OF_END_USES_TYPE[eut], t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [j2, h, td] * t_op[h,td]);

# [Eq. 2.37] Energy efficiency is a fixed cost
subject to extra_efficiency:
	F ["EFFICIENCY"] = 1 / (1 + i_rate);	

# [Eq. 2.38] Limit electricity import capacity
subject to max_elec_import {h in HOURS, td in TYPICAL_DAYS}:
	F_t ["ELECTRICITY", h, td] * t_op [h, td] <= import_capacity; 
	
# [Eq. 2.39] Limit surface area for solar
subject to solar_area_limited :
	F["PV"] / power_density_pv + ( F ["DEC_SOLAR"] + F ["DHN_SOLAR"] ) / power_density_solar_thermal <= solar_area;


##########################
### OBJECTIVE FUNCTION ###
##########################

<<<<<<< HEAD
# Can choose between TotalGWP and TotalCost
minimize obj: TotalCost;




##############################################
###            GLPK version                ###
##############################################

solve;

##############################################
###              OUTPUTS                   ###
##############################################
## Saving sets and parameters to output file


## Print cost breakdown to txt file.
printf "%s\t%s\t%s\t%s\n", "Name", "C_inv", "C_maint", "C_op" > "output/cost_breakdown.txt"; 
for {i in TECHNOLOGIES union RESOURCES}{
	printf "%s\t%.6f\t%.6f\t%.6f\n", i, if i in TECHNOLOGIES then (tau[i] * C_inv[i]) else 0, if i in TECHNOLOGIES then C_maint [i] else 0, if i in RESOURCES then C_op [i] else 0 >> "output/cost_breakdown.txt";
}


## Print GWP breakdown
printf "%s\t%s\t%s\n", "Name", "GWP_constr", "GWP_op" > "output/gwp_breakdown.txt"; 
for {i in TECHNOLOGIES union RESOURCES}{
	printf "%s\t%.6f\t%.6f\n", i, if i in TECHNOLOGIES then GWP_constr [i] / lifetime [i] else 0, if i in RESOURCES then GWP_op [i] else 0 >> "output/gwp_breakdown.txt";
}

## Print losses to txt file
printf "%s\t%s\n", "End use", "Losses" > "output/losses.txt";
for {i in END_USES_TYPES}{
		printf "%s\t%.3f\n",i,  sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t] }(Network_losses [i,h,td] * t_op [h,td])  >> "output/losses.txt";
}

## Print ASSETS to txt file
printf "TECHNOLOGIES\t c_inv\t c_maint\t lifetime\t  f_min\t f\t f_max\t fmin_perc\t" > "output/assets.txt"; 
printf "f_perc\t fmax_perc\t c_p\t tau\t gwp_constr" >> "output/assets.txt"; # Must be split in 2 parts, otherwise too long for GLPK
printf "\n UNITS\t[MCHCapitalf/GW]\t [MCHCapitalf/GW]\t [y]\t [GW or GWh]\t" >> "output/assets.txt"; 
printf " [GW or GWh]\t [GW or GWh]\t [0-1]\t [0-1]\t [0-1]\t [0-1]\t [-]\t [ktCO2-eq./GW or GWh] " >> "output/assets.txt"; 
for {i in END_USES_TYPES, tech in TECHNOLOGIES_OF_END_USES_TYPE[i]}{
	printf "\n%s\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t",tech,
C_inv[tech],C_maint[tech],lifetime[tech],f_min[tech],F[tech],f_max[tech],
fmin_perc[tech],
sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (F_t [tech,h,td] ) / sum {j2 in 
TECHNOLOGIES_OF_END_USES_TYPE[i], t2 in PERIODS, h2 in HOUR_OF_PERIOD[t2], td2 in TYPICAL_DAY_OF_PERIOD[t2]} (F_t [j2, h2, 
td2] ),
fmax_perc[tech],c_p[tech],tau[tech],GWP_constr[tech] >> "output/assets.txt";
}
for {tech in STORAGE_TECH union INFRASTRUCTURE}{
	printf "\n%s\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t",tech,
C_inv[tech],C_maint[tech],lifetime[tech],f_min[tech],F[tech],f_max[tech],
fmin_perc[tech],
-1,
fmax_perc[tech],c_p[tech],tau[tech],GWP_constr[tech] >> "output/assets.txt"; 
}

## STORAGE distribution CURVES
printf "Time\t" > "output/hourly_data/energy_stored.txt";
for {i in STORAGE_TECH }{
	printf "%s\t", i >> "output/hourly_data/energy_stored.txt";
}
for {i in STORAGE_TECH }{
	printf "%s_in\t" , i >> "output/hourly_data/energy_stored.txt";
	printf "%s_out\t", i >> "output/hourly_data/energy_stored.txt";
}
for {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}{
	printf "\n %d\t",t  >> "output/hourly_data/energy_stored.txt";
	for {i in STORAGE_TECH}{
		printf "%f\t", Storage_level[i, t] >> "output/hourly_data/energy_stored.txt";
	}
	for {i in STORAGE_TECH}{
		printf "%f\t", (sum {l in LAYERS: storage_eff_in [i,l] > 0}
-(Storage_in [i, l, h, td] * storage_eff_in [i, l]))
	>> "output/hourly_data/energy_stored.txt";
		printf "%f\t", (sum {l in LAYERS: storage_eff_in [i,l] > 0}
(Storage_out [i, l, h, td] / storage_eff_out [i, l]))
	>> "output/hourly_data/energy_stored.txt";
	}
}

## LAYERS FLUXES
for {l in LAYERS}{
	printf "Td \t Time\t" > ("output/hourly_data/layer_" & l &".txt"); 
	for {i in RESOURCES union TECHNOLOGIES diff STORAGE_TECH }{
		printf "%s\t",i >> ("output/hourly_data/layer_" & l &".txt"); 
	}
	for {j in STORAGE_TECH }{
		printf "%s_Pin\t",j >> ("output/hourly_data/layer_" & l &".txt"); 
		printf "%s_Pout\t",j >> ("output/hourly_data/layer_" & l &".txt"); 
	}
	printf "END_USE\t" >> ("output/hourly_data/layer_" & l &".txt"); 

	for {td in TYPICAL_DAYS, h in HOURS}{
		printf "\n %d \t %d\t",td,h   >> ("output/hourly_data/layer_" & l &".txt"); 
		for {i in RESOURCES union TECHNOLOGIES diff STORAGE_TECH}{
			printf "%f\t",(layers_in_out[i, l] * F_t [i, h, td]) >> ("output/hourly_data/layer_" & l &".txt"); 
		}
		for {j in STORAGE_TECH}{
			printf "%f\t",(-Storage_in [j, l, h, td]) >> ("output/hourly_data/layer_" & l &".txt"); 
			printf "%f\t", (Storage_out [j, l, h, td])>> ("output/hourly_data/layer_" & l &".txt"); 
		}
		printf "%f\t", -End_Uses [l, h, td]  >> ("output/hourly_data/layer_" & l &".txt"); 
	}
}

## Energy yearly balance
printf "Tech\t" > "output/year_balance.txt";
for {l in LAYERS}{
	printf "%s\t",l >> "output/year_balance.txt";
}
for {i in RESOURCES union TECHNOLOGIES diff STORAGE_TECH}{
	printf "\n %s \t", i >> "output/year_balance.txt";
	for {l in LAYERS}{
		printf " %f\t", sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
layers_in_out[i, l] * F_t [i, h, td] >> "output/year_balance.txt";
	}
}
for {j in STORAGE_TECH}{
	printf "\n %s \t", j >> "output/year_balance.txt";
	for {l in LAYERS}{
		printf " %f\t", sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
(Storage_out [j, l, h, td] - Storage_in [j, l, h, td]) >> "output/year_balance.txt";
	}
}
printf "\n END_USES_DEMAND \t" >> "output/year_balance.txt";
for {l in LAYERS}{
	printf " %f\t", sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
		End_Uses [l, h, td] >> "output/year_balance.txt";
}

##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##
##SANKEY : THIS IS A ALPHA VERSION AND MIGHT CONTAIN MISTAKES. TO BE USED CAREFULLY##
##!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!##

# The code to plot the Sankey diagrams is originally taken from: http://bl.ocks.org/d3noob/c9b90689c1438f57d649
# Adapted by the IPESE team

## Generate CSV file to be used as input to Sankey diagram
# Notes:
# - workaround to write if-then-else statements in GLPK: https://en.wikibooks.org/wiki/GLPK/GMPL_Workarounds#If–then–else_conditional
# - to visualize the Sankey, open the html file in any browser. If it does not work, try this: https://threejs.org/docs/#manual/en/introduction/How-to-run-things-locally
# - Power2Gas not included in the diagram
printf "%s,%s,%s,%s,%s,%s\n", "source" , "target", "realValue", "layerID", "layerColor", "layerUnit" > "output/sankey/input2sankey.csv";

#------------------------------------------
# SANKEY - RESOURCES
#------------------------------------------
## Gasoline
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["GASOLINE", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Gasoline" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["GASOLINE","GASOLINE"] * F_t ["GASOLINE", h, td]  ) / 1000 , "Gasoline","#808080", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CAR_PHEV", h, td] + F_t ["CAR_HEV", h, td] ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Gasoline" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CAR_HEV","GASOLINE"] * F_t ["CAR_HEV", h, td] - layers_in_out["CAR_PHEV","GASOLINE"] * F_t ["CAR_PHEV", h, td]) / 1000 , "Gasoline","#808080", "TWh" >> "output/sankey/input2sankey.csv";
}

## Diesel
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CAR_DIESEL", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Diesel" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CAR_DIESEL","DIESEL"] * F_t ["CAR_DIESEL", h, td]  ) / 1000 , "Diesel", "#D3D3D3", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} ((F_t ["BUS_COACH_DIESEL", h, td] + F_t["BUS_COACH_HYDIESEL", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Diesel" , "Mob public", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["BUS_COACH_DIESEL","DIESEL"] * F_t ["BUS_COACH_DIESEL", h, td]   - layers_in_out["BUS_COACH_HYDIESEL","DIESEL"] * F_t ["BUS_COACH_HYDIESEL", h, td]   ) / 1000 , "Diesel", "#D3D3D3", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} ((F_t ["TRUCK", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Diesel" , "Freight", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["TRUCK","DIESEL"] * F_t ["TRUCK", h, td]  ) / 1000 , "Diesel", "#D3D3D3", "TWh" >> "output/sankey/input2sankey.csv";
}

## Natural Gas
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CAR_NG", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CAR_NG","NG"] * F_t ["CAR_NG", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["BUS_COACH_CNG_STOICH", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "Mob public", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["BUS_COACH_CNG_STOICH","NG"] * F_t ["BUS_COACH_CNG_STOICH", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["H2_NG", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "H2 prod", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["H2_NG","NG"] * F_t ["H2_NG", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CCGT", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CCGT","NG"] * F_t ["CCGT", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CCGT_CCS", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG CCS" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CCGT_CCS","NG_CCS"] * F_t ["CCGT_CCS", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_COGEN_GAS", h, td] + F_t ["DHN_COGEN_GAS", h, td] + F_t ["DEC_COGEN_GAS", h, td] + F_t ["DEC_ADVCOGEN_GAS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "CHP", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_COGEN_GAS","NG"] * F_t ["IND_COGEN_GAS", h, td]   - layers_in_out["DHN_COGEN_GAS","NG"] * F_t ["DHN_COGEN_GAS", h, td]   - layers_in_out["DEC_COGEN_GAS","NG"] * F_t ["DEC_COGEN_GAS", h, td]   - layers_in_out["DEC_ADVCOGEN_GAS","NG"] * F_t ["DEC_ADVCOGEN_GAS", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_THHP_GAS", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "HPs", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["DEC_THHP_GAS","NG"] * F_t ["DEC_THHP_GAS", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_BOILER_GAS", h, td] + F_t ["DHN_BOILER_GAS", h, td] + F_t ["DEC_BOILER_GAS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "NG" , "Boilers", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_BOILER_GAS","NG"] * F_t ["IND_BOILER_GAS", h, td]   - layers_in_out["DHN_BOILER_GAS","NG"] * F_t ["DHN_BOILER_GAS", h, td]   - layers_in_out["DEC_BOILER_GAS","NG"] * F_t ["DEC_BOILER_GAS", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}

## Electricity production
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["ELECTRICITY", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Electricity" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["ELECTRICITY","ELECTRICITY"] * F_t ["ELECTRICITY", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["NUCLEAR", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Nuclear" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["NUCLEAR","ELECTRICITY"] * F_t ["NUCLEAR", h, td]  ) / 1000 , "Nuclear", "#FFC0CB", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["WIND", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Wind" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["WIND","ELECTRICITY"] * F_t ["WIND", h, td]  ) / 1000 , "Wind", "#27AE34", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["HYDRO_DAM", h, td] + F_t ["NEW_HYDRO_DAM", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Hydro Dams" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["HYDRO_DAM","ELECTRICITY"] * F_t ["HYDRO_DAM", h, td]   + layers_in_out["NEW_HYDRO_DAM","ELECTRICITY"] * F_t ["NEW_HYDRO_DAM", h, td]  ) / 1000 , "Hydro Dam", "#00CED1", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["HYDRO_RIVER", h, td] + F_t ["NEW_HYDRO_RIVER", h, 
td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Hydro River" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["HYDRO_RIVER","ELECTRICITY"] * F_t ["HYDRO_RIVER", h, td]   + layers_in_out["NEW_HYDRO_RIVER","ELECTRICITY"] * F_t ["NEW_HYDRO_RIVER", h, td]  ) / 1000 , "Hydro River", "#0000FF", "TWh" >> "output/sankey/input2sankey.csv";
}

# Coal
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["COAL_US", h, td] + F_t ["COAL_IGCC", h, td]) ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Coal" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["COAL_US","COAL"] * F_t ["COAL_US", h, td]   - layers_in_out["COAL_IGCC","COAL"] * F_t ["COAL_IGCC", h, td]  ) / 1000 , "Coal", "#A0522D", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["COAL_US_CCS", h, td] + F_t ["COAL_IGCC_CCS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Coal CCS" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["COAL_US_CCS","COAL_CCS"] * F_t ["COAL_US_CCS", h, td]   - layers_in_out["COAL_IGCC_CCS","COAL"] * F_t ["COAL_IGCC_CCS", h, td]  ) / 1000 , "Coal", "#A0522D", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["IND_BOILER_COAL", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Coal" , "Boilers", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_BOILER_COAL","COAL"] * F_t ["IND_BOILER_COAL", h, td]  ) / 1000 , "Coal", "#A0522D", "TWh" >> "output/sankey/input2sankey.csv";
}

# Solar
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["PV", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Solar" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["PV","ELECTRICITY"] * F_t ["PV", h, td]  ) / 1000 , "Solar", "#FFFF00", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_SOLAR", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Solar" , "Heat LT Dec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
		(layers_in_out["DEC_SOLAR","HEAT_LOW_T_DECEN"] * (F_t ["DEC_SOLAR", h, td])# SUPPRESSED # - Solar_excess [ h, td] ) 
		-((max(Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_HP_ELEC"      ,h,td]  /max(0.0001,Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_THHP_GAS"     ,h,td]  /max(0.0001,Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_GAS"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_WOOD"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_OIL"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_COGEN_GAS"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_ADVCOGEN_GAS" ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_COGEN_OIL"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_ADVCOGEN_H2"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] )))
		)/ 1000
		, "Solar", "#FFFF00", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_SOLAR", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Solar" , "Dec. Sto", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
		((max(Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_HP_ELEC"      ,h,td]  /max(0.0001,Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_THHP_GAS"     ,h,td]  /max(0.0001,Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_GAS"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_WOOD"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_BOILER_OIL"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_COGEN_GAS"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_ADVCOGEN_GAS" ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_COGEN_OIL"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td],0))*(  F_t_Solar["DEC_ADVCOGEN_H2"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] ))
		)/ 1000
		, "Solar", "#FFFF00", "TWh" >> "output/sankey/input2sankey.csv";
}


# Geothermal
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["GEOTHERMAL", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Geothermal" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["GEOTHERMAL","ELECTRICITY"] * F_t ["GEOTHERMAL", h, td]  ) / 1000 , "Geothermal", "#FF0000", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DHN_DEEP_GEO", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Geothermal" , "DHN", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["DHN_DEEP_GEO","HEAT_LOW_T_DHN"] * F_t ["DHN_DEEP_GEO", h, td]  ) / 1000 , "Geothermal", "#FF0000", "TWh" >> "output/sankey/input2sankey.csv";
}

# Waste
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_COGEN_WASTE", h, td] + F_t ["DHN_COGEN_WASTE", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Waste" , "CHP", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_COGEN_WASTE","WASTE"] * F_t ["IND_COGEN_WASTE", h, td]  -layers_in_out["DHN_COGEN_WASTE","WASTE"] * F_t ["DHN_COGEN_WASTE", h, td]  ) / 1000 , "Waste", "#808000", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["IND_BOILER_WASTE", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Waste" , "Boilers", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_BOILER_WASTE","WASTE"] * F_t ["IND_BOILER_WASTE", h, td]  ) / 1000 , "Waste", "#808000", "TWh" >> "output/sankey/input2sankey.csv";
}

# Oil
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DEC_COGEN_OIL", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Oil" , "CHP", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["DEC_COGEN_OIL","LFO"] * F_t ["DEC_COGEN_OIL", h, td]  ) / 1000 , "Oil", "#8B008B", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_BOILER_OIL", h, td] + F_t ["DHN_BOILER_OIL", h, td] + F_t ["DEC_BOILER_OIL", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Oil" , "Boilers", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_BOILER_OIL","LFO"] * F_t ["IND_BOILER_OIL", h, td] - layers_in_out["DHN_BOILER_OIL","LFO"] * F_t ["DHN_BOILER_OIL", h, td]   - layers_in_out["DEC_BOILER_OIL","LFO"] * F_t ["DEC_BOILER_OIL", h, td]  ) / 1000 , "Oil", "#8B008B", "TWh" >> "output/sankey/input2sankey.csv";
}

# Wood
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["H2_BIOMASS", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Wood" , "H2 prod", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["H2_BIOMASS","WOOD"] * F_t ["H2_BIOMASS", h, td]  ) / 1000 , "Wood", "#CD853F", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["GASIFICATION_SNG", h, td] + F_t ["PYROLYSIS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Wood" , "Biofuels", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["GASIFICATION_SNG","WOOD"] * F_t ["GASIFICATION_SNG", h, td]   - layers_in_out["PYROLYSIS","WOOD"] * F_t ["PYROLYSIS", h, td]  ) / 1000 , "Wood", "#CD853F", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_COGEN_WOOD", h, td] + F_t ["DHN_COGEN_WOOD", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Wood" , "CHP", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_COGEN_WOOD","WOOD"] * F_t ["IND_COGEN_WOOD", h, td]   - layers_in_out["DHN_COGEN_WOOD","WOOD"] * F_t ["DHN_COGEN_WOOD", h, td]  ) / 1000 , "Wood", "#CD853F", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_BOILER_WOOD", h, td] + F_t ["DHN_BOILER_WOOD", h, td] + F_t ["DEC_BOILER_WOOD", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Wood" , "Boilers", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["IND_BOILER_WOOD","WOOD"] * F_t ["IND_BOILER_WOOD", h, td]   - layers_in_out["DHN_BOILER_WOOD","WOOD"] * F_t ["DHN_BOILER_WOOD", h, td]   - layers_in_out["DEC_BOILER_WOOD","WOOD"] * F_t ["DEC_BOILER_WOOD", h, td]  ) / 1000 , "Wood", "#CD853F", "TWh" >> "output/sankey/input2sankey.csv";
}

#------------------------------------------
# SANKEY - Electricity use
#------------------------------------------
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["CAR_PHEV", h, td] + F_t ["CAR_BEV", h, td]) ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CAR_PHEV","ELECTRICITY"] * F_t ["CAR_PHEV", h, td]   - layers_in_out["CAR_BEV","ELECTRICITY"] * F_t ["CAR_BEV", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["TRAIN_PUB", h, td] + F_t ["TRAMWAY_TROLLEY", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Mob public", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["TRAIN_PUB","ELECTRICITY"] * F_t ["TRAIN_PUB", h, td]   - layers_in_out["TRAMWAY_TROLLEY","ELECTRICITY"] * F_t ["TRAMWAY_TROLLEY", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["TRAIN_FREIGHT", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Freight", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["TRAIN_FREIGHT","ELECTRICITY"] * F_t ["TRAIN_FREIGHT", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Network_losses ["ELECTRICITY", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Exp & Loss", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Network_losses ["ELECTRICITY", h, td]   - layers_in_out["ELEC_EXPORT","ELECTRICITY"] * F_t ["ELEC_EXPORT", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(End_Uses ["ELECTRICITY", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Elec demand", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((End_Uses ["ELECTRICITY", h, td]  - Network_losses ["ELECTRICITY", h, td] - sum {i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"]} (Storage_out [i, "ELECTRICITY", h, td]))  )/ 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
# New boxes for Electricity storage
for{{0}: sum{i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"], t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Storage_in [i, "ELECTRICITY", h, td]) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Storage", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (sum {i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"] }(Storage_in [i, "ELECTRICITY", h, td]))/ 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"], t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Storage_in [i, "ELECTRICITY", h, td]) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Storage" , "Elec demand", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(sum {i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"] } (Storage_out [i, "ELECTRICITY", h, td] )  )/ 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"], t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Storage_in [i, "ELECTRICITY", h, td]) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Storage" , "Exp & Loss", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (sum {i in STORAGE_OF_END_USES_TYPES["ELECTRICITY"] }((Storage_in [i, "ELECTRICITY", h, td])- (Storage_out [i, "ELECTRICITY", h, td] ))  )/ 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}

for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DHN_HP_ELEC", h, td] + F_t ["DEC_HP_ELEC", h, td]) ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "HPs", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["DHN_HP_ELEC","ELECTRICITY"] * F_t ["DHN_HP_ELEC", h, td]   - layers_in_out["DEC_HP_ELEC","ELECTRICITY"] * F_t ["DEC_HP_ELEC", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["H2_ELECTROLYSIS", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "H2 prod", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["H2_ELECTROLYSIS","ELECTRICITY"] * F_t ["H2_ELECTROLYSIS", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_DIRECT_ELEC", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Heat LT Dec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["DEC_DIRECT_ELEC","HEAT_LOW_T_DECEN"] * F_t ["DEC_DIRECT_ELEC", h, td]  - ((max(Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] )))) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_DIRECT_ELEC", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Heat LT Dec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["DEC_DIRECT_ELEC","HEAT_LOW_T_DECEN"] * F_t ["DEC_DIRECT_ELEC", h, td]  		- ((max(Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] )))) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]: Storage_in["TS_DEC_DIRECT_ELEC", "HEAT_LOW_T_DECEN", h, td] > Storage_out["TS_DEC_DIRECT_ELEC", "HEAT_LOW_T_DECEN", h, td] }    	((Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td])*(1-F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] ))) >10 }{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Dec. Sto", sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 	((max(Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_DIRECT_ELEC"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_DIRECT_ELEC" , "HEAT_LOW_T_DECEN", h, td] ))) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";	
}	
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["IND_DIRECT_ELEC", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Elec" , "Heat HT", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["IND_DIRECT_ELEC","HEAT_HIGH_T"] * F_t ["IND_DIRECT_ELEC", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}

# H2 use
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_ADVCOGEN_H2", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "H2 prod" , "CHP", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["DEC_ADVCOGEN_H2","H2"] * F_t ["DEC_ADVCOGEN_H2", h, td]  ) / 1000 , "H2", "#FF00FF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["CAR_FUEL_CELL", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "H2 prod" , "Mob priv", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["CAR_FUEL_CELL","H2"] * F_t ["CAR_FUEL_CELL", h, td]  ) / 1000 , "H2", "#FF00FF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["BUS_COACH_FC_HYBRIDH2", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "H2 prod" , "Mob public", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(-layers_in_out["BUS_COACH_FC_HYBRIDH2","H2"] * F_t ["BUS_COACH_FC_HYBRIDH2", h, td]  ) / 1000 , "H2", "#FF00FF", "TWh" >> "output/sankey/input2sankey.csv";
}

#------------------------------------------
# SANKEY - HEATING
#------------------------------------------
# CHP
for{{0}: sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t [ i, h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "CHP" , "Elec", sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out[i,"ELECTRICITY"] * F_t [i, h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DEC_COGEN_GAS", h, td] + F_t ["DEC_COGEN_OIL", h, td] + F_t ["DEC_ADVCOGEN_GAS", h, td] + F_t ["DEC_ADVCOGEN_H2", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "CHP" , "Heat LT Dec", sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
		(layers_in_out[i,"HEAT_LOW_T_DECEN"] * F_t [i, h, td]  
		 -((max(Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_GAS"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_GAS" ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_OIL"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] ))+
		  (max(Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_H2"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] )))
	    ) / 1000 
	, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

for{{0}: sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 
		    ((max(Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_GAS"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_GAS" ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_OIL"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_H2"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] )))> 10}{
		printf "%s,%s,%.2f,%s,%s,%s\n", "CHP" , "Dec. Sto", 
			sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
				((max(Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_GAS"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_GAS"   , "HEAT_LOW_T_DECEN", h, td] ))+
				(max(Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_GAS" ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_GAS", "HEAT_LOW_T_DECEN", h, td] ))+
				(max(Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_COGEN_OIL"    ,h,td]  /max(0.0001,Storage_in["TS_DEC_COGEN_OIL"   , "HEAT_LOW_T_DECEN", h, td] ))+
				(max(Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_ADVCOGEN_H2"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_ADVCOGEN_H2" , "HEAT_LOW_T_DECEN", h, td] ))
		    ) / 1000 
		, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DHN_COGEN_GAS", h, td] + F_t ["DHN_COGEN_WOOD", h, td] + F_t ["DHN_COGEN_WASTE", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "CHP" , "DHN", sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out[i,"HEAT_LOW_T_DHN"] * F_t [i, h, td]  ) / 1000 , "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_COGEN_GAS", h, td] + F_t ["IND_COGEN_WOOD", h, td] + F_t ["IND_COGEN_WASTE", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "CHP" , "Heat HT", sum{i in COGEN, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out[i,"HEAT_HIGH_T"] * F_t [i, h, td]  ) / 1000 , "Heat HT", "#DC143C", "TWh" >> "output/sankey/input2sankey.csv";
}

# HPs
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DEC_HP_ELEC", h, td] + F_t ["DEC_THHP_GAS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "HPs" , "Heat LT Dec", 
		sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((layers_in_out["DEC_HP_ELEC","HEAT_LOW_T_DECEN"] * F_t ["DEC_HP_ELEC", h, td]   +	layers_in_out["DEC_THHP_GAS","HEAT_LOW_T_DECEN"] * F_t ["DEC_THHP_GAS", h, td]  
		-((max(Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_HP_ELEC"      ,h,td]  /max(0.0001,Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] ))
     	 +(max(Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_THHP_GAS"     ,h,td]  /max(0.0001,Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] )))
		) / 1000 ) , "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DHN_HP_ELEC", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "HPs" , "DHN", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((layers_in_out["DHN_HP_ELEC","HEAT_LOW_T_DHN"] * F_t ["DHN_HP_ELEC", h, td]  ) / 1000  ), "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

#storage
for{{0}: sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 
    		((max(Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_HP_ELEC"      ,h,td]  /max(0.0001,Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] ))+
     	    (max(Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_THHP_GAS"     ,h,td]  /max(0.0001,Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] ))) >10 }{
		printf "%s,%s,%.2f,%s,%s,%s\n", "HPs" , "Dec. Sto", 		 
			sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 
			((max(Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_HP_ELEC"      ,h,td]  /max(0.0001,Storage_in["TS_DEC_HP_ELEC"     , "HEAT_LOW_T_DECEN", h, td] ))+
			(max(Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_THHP_GAS"     ,h,td]  /max(0.0001,Storage_in["TS_DEC_THHP_GAS"    , "HEAT_LOW_T_DECEN", h, td] )))/1000
			,"Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";	
}

# Biofuels
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["GASIFICATION_SNG", h, td] + F_t ["PYROLYSIS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Biofuels" , "Elec", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["GASIFICATION_SNG","ELECTRICITY"] * F_t ["GASIFICATION_SNG", h, td]   + layers_in_out["PYROLYSIS","ELECTRICITY"] * F_t ["PYROLYSIS", h, td]  ) / 1000 , "Electricity", "#00BFFF", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["GASIFICATION_SNG", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Biofuels" , "NG", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["GASIFICATION_SNG","NG"] * F_t ["GASIFICATION_SNG", h, td]  ) / 1000 , "NG", "#FFD700", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["PYROLYSIS", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Biofuels" , "Oil", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["PYROLYSIS","LFO"] * F_t ["PYROLYSIS", h, td]  ) / 1000 , "Oil", "#8B008B", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["GASIFICATION_SNG", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Biofuels" , "DHN", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out["GASIFICATION_SNG","HEAT_LOW_T_DHN"] * F_t ["GASIFICATION_SNG", h, td]  ) / 1000, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

# Boilers
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(F_t ["DEC_BOILER_GAS", h, td] + F_t ["DEC_BOILER_WOOD", h, td] + F_t ["DEC_BOILER_OIL", h, td] ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Boilers" , "Heat LT Dec", 
	sum{i in BOILERS, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (layers_in_out[i,"HEAT_LOW_T_DECEN"] * F_t [i, h, td] )/1000
	-sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}
		((max(Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_GAS"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_WOOD"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_OIL"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] ))) / 1000 ,"Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 
		    ((max(Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_GAS"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_WOOD"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_OIL"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] ))) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Boilers" , "Dec. Sto", 
		sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} 
		    ((max(Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_GAS"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_GAS"  , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_WOOD"  ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_WOOD" , "HEAT_LOW_T_DECEN", h, td] ))+
		     (max(Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] - Storage_out["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td],0))*(1-F_t_Solar["DEC_BOILER_OIL"   ,h,td]  /max(0.0001,Storage_in["TS_DEC_BOILER_OIL"  , "HEAT_LOW_T_DECEN", h, td] ))		 ) / 1000 ,"Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["DHN_BOILER_GAS", h, td] + F_t ["DHN_BOILER_WOOD", h, td] + F_t ["DHN_BOILER_OIL", h, td])  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Boilers" , "DHN", sum{i in BOILERS, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out[i,"HEAT_LOW_T_DHN"] * F_t [i, h, td]  ) / 1000 , "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}((F_t ["IND_BOILER_GAS", h, td] + F_t ["IND_BOILER_WOOD", h, td] + F_t ["IND_BOILER_OIL", h, td] + F_t ["IND_BOILER_COAL", h, td] + F_t ["IND_BOILER_WASTE", h, td])  ) > 10 }{
	printf "%s,%s,%.2f,%s,%s,%s\n", "Boilers" , "Heat HT", sum{i in BOILERS, t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(layers_in_out[i,"HEAT_HIGH_T"] * F_t [i, h, td]  ) / 1000 , "Heat HT", "#DC143C", "TWh" >> "output/sankey/input2sankey.csv";


}
for{{0}: sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t], i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DECEN"]: Storage_in[i, "HEAT_LOW_T_DECEN", h, td] < Storage_out[i, "HEAT_LOW_T_DECEN", h, td] } (Storage_out[i , "HEAT_LOW_T_DECEN", h, td] - Storage_in[i , "HEAT_LOW_T_DECEN", h, td]) > 10}{
   printf "%s,%s,%.2f,%s,%s,%s\n", "Dec. Sto" , "Heat LT Dec", sum {t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t], i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DECEN"]: Storage_in[i, "HEAT_LOW_T_DECEN", h, td] < Storage_out[i, "HEAT_LOW_T_DECEN", h, td] } (Storage_out[i , "HEAT_LOW_T_DECEN", h, td] - Storage_in[i , "HEAT_LOW_T_DECEN", h, td])/1000 , "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";

# DHN 
}
for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(End_Uses ["HEAT_LOW_T_DHN", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "DHN" , "Heat LT DHN", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (sum {i in TECHNOLOGIES diff STORAGE_TECH } (layers_in_out[i, "HEAT_LOW_T_DHN"] * F_t [i, h, td]  ) 	- Network_losses ["HEAT_LOW_T_DHN", h, td]   	- sum {i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"]} (Storage_in  [i, "HEAT_LOW_T_DHN", h, td])) / 1000	, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}

for{{0}: sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Network_losses ["HEAT_LOW_T_DHN", h, td]  ) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "DHN" , "Loss DHN", sum{t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Network_losses ["HEAT_LOW_T_DHN", h, td]  ) / 1000 , "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
# DHN storage :
for{{0}: sum {i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"],t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Storage_in  [i, "HEAT_LOW_T_DHN", h, td]) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "DHN" , "DHN Sto", sum {i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"],t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (Storage_in  [i, "HEAT_LOW_T_DHN", h, td])/1000	, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
for{{0}: sum {i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"],t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]}(Storage_out  [i, "HEAT_LOW_T_DHN", h, td]) > 10}{
	printf "%s,%s,%.2f,%s,%s,%s\n", "DHN Sto" , "Heat LT DHN", sum {i in STORAGE_OF_END_USES_TYPES["HEAT_LOW_T_DHN"],t in PERIODS, h in HOUR_OF_PERIOD[t], td in TYPICAL_DAY_OF_PERIOD[t]} (Storage_out  [i, "HEAT_LOW_T_DHN", h, td])/1000	, "Heat LT", "#FA8072", "TWh" >> "output/sankey/input2sankey.csv";
}
=======
# Can choose between TotalGWP, TotalCost and TotalEinv
minimize obj: TotalEinv;
>>>>>>> ES_Multi_criteria

