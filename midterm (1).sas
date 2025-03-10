/*Import dataset into sas */
PROC IMPORT DATAFILE="/home/u64133399/Pol/TSAClaims2002_2017 (2).csv"out=claims_cleaned dbms=csv
            replace;
    getnames=yes;
RUN;
/* Preview 20 rows of the data */
proc print data=claims_cleaned (obs=20);
run;

/* View attributes of the dataset */
proc contents data = claims_cleaned;
run;

/* Explore columns */
proc freq data = claims_cleaned;
table Claim_Site Disposition Claim_Type Date_Received Incident_Date/nocum nopercent;
format Date_Received Incident_Date year4.;
run;
/* PREPARE DATA*/

/*Remove duplicate records */
PROC SORT DATA=claims_cleaned nodupkey out=claims_cleaned_no_duplicates;
    BY _all_;
RUN;

/* Change missing or '-' values in Claim_Type, Claim_Site, and Disposition to 'Unknown' */
DATA claims_cleaned;
    SET claims_cleaned_no_duplicates;
    
    ARRAY clean_columns {3} Claim_Type Claim_Site Disposition;
    
/*Loop through each columns and replace missing or '-' with 'Unknown' */
    DO i = 1 to 3;
        if clean_columns{i} = '' or clean_columns{i} = '-' then clean_columns{i} = 'Unknown';
    END;
    
    DROP i;
RUN;

/* Proper Case and State to Uppercase */
DATA claims_cleaned;
    SET claims_cleaned;

    
    StateName = propcase(StateName);

    /*State should be in uppercase */
    State = upcase(State);
RUN;



/*Create Date_Issues column for rows with date issues */
DATA claims_cleaned;
    SET claims_cleaned;
    Date_Issues = 'No Issue';
    
/* Check for missing values or date range issues */
    if missing(Incident_Date) or missing(Date_Received) then Date_Issues = 'Needs Review';
    else if (year(Incident_Date) < 2002 or year(Incident_Date) > 2017) then Date_Issues = 'Needs Review';
    else if Incident_Date > Date_Received then Date_Issues = 'Needs Review';
RUN;


/*drop County and City columns */
DATA claims_cleaned;
    set claims_cleaned;
    drop County City;
RUN;

/*Format Currency column */
DATA claims_cleaned;
    set claims_cleaned;
    
    format Claim_Amount dollar8.2;
run;

/*Format all dates in style 01JAN2000 */
data claims_cleaned;
    set claims_cleaned;
    
    format Incident_Date Date_Received date9.;
run;

/*Replace underscores with spaces for column labels */
PROC DATASETS LIB=work nolist;
    modify claims_cleaned;
    LABEL 
        Claim_Type = 'Claim Type'
        Claim_Site = 'Claim Site'
        Disposition = 'Disposition'
        StateName = 'State Name'
        Incident_Date = 'Incident Date'
        Date_Received = 'Date Received'
        Claim_Amount = 'Claim Amount';
RUN;




/*Sort the data by Incident_Date in ascending order */
PROC SORT DATA=claims_cleaned;
    by Incident_Date;
RUN;

/* Check columns to see if they are transformed properly */
proc freq data = claims_cleaned;
table Claim_Site Disposition Claim_Type Date_Issues/nocum nopercent;
run;
/* ANALYZE DATA & EXPORT INTO PDF REPORT */

ODS pdf file = '/home/u64133399/Pol/claims.pdf' style = meadow pdftoc = 1;  *PDF table of content is in 1 level;
ODS noproctitle;

/* 1. How many date issues are in the overall data? */
ODS proclabel 'Overall Date Issues';
title 'Overall Date Issues in the Data';
proc freq data = claims_cleaned;
table Date_Issues/missing nocum nopercent;
run;


/* 2. How many claims per year of Incident_Date are in the overall data? Be sure to include a plot. */
ODS proclabel 'Overall Claims by Year';
title 'Overall Claims by Year';
proc freq data = claims_cleaned;
table Incident_Date/nocum nopercent plots = freqplot;
format Incident_Date year4.;
where Date_Issues = '';
run;

/* 
3. user should be able to dynamically input a specific state value and answer the following:
a. What are the frequency values for Claim_Type for the selected state?
b. What are the frequency values for Claim_Site for the selected state?
c. What are the frequency values for Disposition for the selected state?
d. What is the mean, minimum, maximum, and sum of Close_Amount for the selected state? (The statistics should be rounded to the nearest integer.)
*/
%let SelectedState = Hawaii;

ODS proclabel "&SelectedState Claims Overview";
title "&SelectedState: Claim Types, Claim Sites and Disposition";
proc freq data = claims_cleaned;
table Claim_Type Claim_Site Disposition/nocum nopercent;
where Date_Issues = '' AND StateName = "&SelectedState";
run;

ODS proclabel "Close Amount Statistics for &SelectedState";
title "&SelectedState: Close_Amount Statistics";
proc means data = claims_cleaned MAXDEC = 0 mean min max sum;
var Close_Amount;
where Date_Issues = '' AND StateName = "&SelectedState";
run;

ODS pdf close;
