proc import
dbms = XLSX replace
datafile = "~/datafiles/energy.xlsx"
out = energy_data;
sheet='Electricity Use';  /* option for sheet goes last */
run;

proc optmodel;

set hours;

num cost_per_kWh {hours};
num required_energy {hours};
num storage_units = 1;

read data energy_data into hours = [hour] cost_per_kWh = cost_per_kWh required_energy = kWh; 

var energy_purchased_for_use{hours} >=0;
var energy_purchased_for_storage{hours} >=0;
var used_from_storage{hours}>=0;
var in_storage{hours} >= 0;
var peak_charge >= 0;

impvar total_energy_purchased{i in hours} = energy_purchased_for_use[i] + energy_purchased_for_storage[i];

con energy_inv{i in hours}: in_storage[i] = (if i = 1 then in_storage[24]
															+ (0.9*energy_purchased_for_storage[24]) 
															- used_from_storage[24] 
													  else in_storage[i-1]
															+ (0.9*energy_purchased_for_storage[i-1]) 
															- used_from_storage[i-1]);
con hourly_storage_limit{i in hours}: energy_purchased_for_storage[i] <= 12 * storage_units;
con total_storage_limit{i in hours}: in_storage[i] <= 80 * storage_units;
con storage_overdraw {i in hours}: used_from_storage[i] <= in_storage[i];
con max_SE_used{i in hours}: used_from_storage[i] <= 20 * storage_units;
con SE_used_demand_percentage{i in hours}: used_from_storage[i] <= 0.17*required_energy[i];
con peak_charge_cost{i in hours}: total_energy_purchased[i] <= peak_charge;

con meet_demand{i in hours} : energy_purchased_for_use[i] + used_from_storage[i] >= required_energy[i];

min total_cost = sum{i in hours} cost_per_kWh[i]*total_energy_purchased[i] + 0.3*peak_charge;

solve with lp;

print total_cost;
print energy_purchased_for_use energy_purchased_for_storage used_from_storage in_storage;

print peak_charge;

create data energy_storage_soln from
		    [hours] cost_per_kWh required_energy energy_purchased_for_use energy_purchased_for_storage used_from_storage in_storage;

proc export data=energy_storage_soln
	outfile="/home/u59238888/datafiles/energy_soln.xls"
	dbms=xls;
run;