
PROC IMPORT OUT=WORK.car_data 
	DATAFILE= "C:\SMU\Courses\MSDS 6372 - Applied Statistics\github\MSDS6372-Project1\data\car_project_2.csv" 
	DBMS=CSV REPLACE;
	GETNAMES=YES;
RUN;

*
* Exploratory Analysis
*;
proc print data=car_data;
run;

proc sql;
	select count(*) as records_count from car_data;
run;

data car_data_2;
	set car_data;
	if top_speed_mph = '' then delete;
run;

proc sql;
	select count(*) as records_count from car_data_2;
run;

proc contents data=car_data_2;
run;

proc print data=car_data_2;
run;


proc sgscatter data=car_data_2;
	matrix top_speed_mph horsepower weight_lbs acceleration_0_60 torque_lbft cylinders displacement / diagonal=(histogram);
run; 

* Based on the visual inspection, the predictors are either positively or negatively correlated and there is no need for transformation
;

*
* Run a model and examine the plots
*;
proc reg data=car_data_2 plots(label)=(rstudentleverage cooksd);
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement acceleration_0_60;
run; 

* Observation 19 needs to be looked at:
* Other than that, no other specific outlier that we need to address. 
*;

*
* Looking at correlation matrix: 
*   Rank and logTakers are highly correlated (-0.9592 leave one out in the next model) - Verify with VIF option
*;
proc reg data=car_data_2 corr plots(label)=(rstudentleverage cooksd);
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement acceleration_0_60 / VIF;
run; 

*
* Looking at Parameter Estimates, Variance Inflation:
*   Rank and logTakers have high values (21.64368 & 24.13169 - one of them need to go)
*   Include logTakers and exclude Rank
*;

*
* Variable / Feature Selection
* LARS
*;
proc glmselect data=car_data_2;
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement / selection=LARS;
run; 

*
* logTakers, Years and Expend are the ones that get included in the model (Parameter Estimates Table).
* R-Sq=89.4%, Adj R-Sq=88.69% - Pretty good fit
* AIC, AICC, SBC need to be as small as possible (366.45267, 367.84802, 323.01995)
*   "Stop Details" Table - Candidate SBC=325.4376, Compare SBC=323.0200 - Income did not make it into the model
*   LARS Selection Summary Table gives the local minimum for each of the predictors
*;

*
* LASSO
*;
proc glmselect data=car_data_2;
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement acceleration_0_60 / selection=LASSO;
run; 

* 
* LARS and LASSO give exactly the same results
*;

*
* Try stepwise
*;
proc glmselect data=car_data_2;
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement acceleration_0_60 / selection=stepwise;
run; 

*
* Only logTakers and Expend are the only ones that make it into the model. This is a simpler model with the similar R-Sq and Adj R-Sq values.
*;

*
* Take the model and run it through proc reg. Get some partial residual plots using partial option.
*;
proc reg data=car_data_2;
	model top_speed_mph = horsepower weight_lbs torque_lbft cylinders displacement acceleration_0_60 / partial;
run; 

*
* Cook's D looks good (0.2, not a high value). 
* QQ plot of the residuals show a normal distribution
* No evidence of non constant variance in residual plots
* One leverage point (may be Louisiana, we plan to leave it alone)
* Residuals by regressors look fine (?)
* Partial residuals
* - logTakers seems fine
* - Expend seems a little more spread out
* - Years shows evidence of variability, Years may not be as necessary as the other two variables, could be taken out
* Parameters Estimates Table
* - Years has a p-value of 0.1377 and is not significant (remove from model)
* - logTakers and Expend have a p-value of <0.0001 which show significance (include in model)
*;

*
* Take years out of the model and run it through proc reg. Get some partial residual plots using partial option.
*;
proc reg data=car_data_2;
	model top_speed_mph = horsepower torque_lbft displacement acceleration_0_60 / partial;
run; 
quit;

*
* Most of the plots look normal or as same as before
* Parameters Estimates Table
* - logTakers and Expend still have a p-value of <0.0001 which show significance
*;


*
* CROSS VALIDATION
*;

*
* Leave one out CV
*;
proc glmselect data=SATData3;
	model SAT = Income Years Public Expend Rank / selection=forward(STOP=Press);
run; 

*
* 10-fold CV. 9/10 of data to build the model and 1/10 of the data to do cross validation. 
*;
proc glmselect data=SATData3;
	model SAT = Income Years Public Expend Rank / selection=forward(Choose=CV) CVMethod=Random(10);
run; 

proc glmselect data=SATData3;
	model SAT = Income Years Public Expend Rank / selection=forward(STOP=CV);
run; 
