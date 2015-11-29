/* CONTRIBUTION TO THE REPORT FOR THE HIGH LEVEL PANEL ON ILLICIT FINANCIAL FLOWS
Alice Lépissier
Version: Stata 13
Date: 14/10/13 */

**** Required commands
/* ssc install kountry
ssc install wbopendata
ssc install catplot
ssc install mmerge */

clear all
set more off

/* //////////////////////////////////////
CHANGE YOUR WORKING DIRECTORY HERE
////////////////////////////////////// */
cd "C:\Users\alicelepissier\Documents\4. Illicit Financial Flows\Mbeki panel final report\Mbeki paper Package"
global data "Raw data"
global results "Results"
local date = c(current_date)
capture log close
log using "HLP_Report_`date'.log", replace



/**** INDEX
//////////////////////////////////////
DATA IMPORT AND PREPARATION
//////////////////////////////////////
1. Master list for country codes
2. Import Coordinated Portfolio Investment Survey (IMF)
3. Import Coordinated Direct Investment Survey (IMF)
4. Merge CPIS and CDIS data
5. Import COMTRADE and consolidate
6. Merge CPIS/CDIS data and COMTRADE, create panel
7. Import Consolidated Banking Statistics (BIS)
**** Not used //8. Merge CPIS/CDIS/COMTRADE and BIS data, create panel
9. Import World Development Indicators (World Bank)
10. Merge Full Panel with WDI indicators
11. Import FSI data
12. Merge Full Panel with FSI indicators
13. Merge Full Panel with regional groups
14. Merge Full Panel with income groups
//////////////////////////////////////
VULNERABILITIES AND EXPOSURE ANALYSIS
//////////////////////////////////////
1. Vulnerability scores for country of interest	
2. Jurisdiction-level Exposure scores for country of interest
3. Jurisdiction-level Importance of flows/stocks to country of interest's GDP
4. Jurisdiction-level mean Vulnerability, Importance and Exposure scores
5. Dummy Groups for Exposure and Secrecy Scores
6. Weighted (region-specific and income group-specific) Exposure scores
7. Labels and extra stuff
//////////////////////////////////////
GRAPHS AND OUTPUTS
//////////////////////////////////////
1. Jurisdiction-level Vulnerability scores
2. Jurisdiction-level Exposure scores
3. Stacked Exposure Scores (unweighted, i.e. unweighted mean jurisdiction-level scores) - From Reporter perspective
4. Ranking countries' individual exposure scores to identify outliers - From reporter perspective
5. Specialisation of GDP with secretive partners
6. Weighted exposures
**** Footnotes
**** Housekeeping
*/




/* /////////////////////////////////////////////////////////////////////////////
DATA IMPORT AND PREPARATION
///////////////////////////////////////////////////////////////////////////// */

**** 1. Master list for country codes
import excel using "$data\codes_masterlist.xlsx", sheet("Codes_Master") firstrow
destring UN_rcode, replace
destring UN_srcode, replace
destring UN_tag1c, replace
destring UN_tag2c, replace
sort country
save "$data\codes_masterlist.dta", replace


**** 2. Import Coordinated Portfolio Investment Survey (IMF)
clear
insheet using "$data\CPIS_2concepts_bilat.csv", names
drop if missing(value) //1716. This is so that when the values are wide as 4 indicators, there is no pattern where each of the indicators is missing.
rename conceptlabel indicator
drop conceptcode datasourcelabel datasourcecode statuslabel statuscode unitcode timelabel frequencylabel frequencycode countrycode partnercountrycode
rename timecode year
destring year, replace

// Prepare indicator variable for a wide reshape.
replace indicator = "PI_Assets" if indicator == "Portfolio Investment, Total, Assets (BPM5)"
replace indicator = "PI_Liabilities"  if indicator == "Portfolio Investment, Total, Liabilities (BPM5)"
replace indicator = "PI_DerivedAssets" if indicator == "PI_Assets" & unitlabel == "US Dollars, Derived"
replace indicator = "PI_DerivedLiabilities" if indicator == "PI_Liabilities" & unitlabel == "US Dollars, Derived"
drop unitlabel
misstable summarize // Check the missing value patterns.
gen id = countrylabel + "_" + partnercountrylabel + "_" + string(year) + "_" + indicator + "_" + string(value) 
bysort id: gen n = _n if _n == _N
tab n // Check there are no duplicates within the raw data. OK.


	**** 2.1. Consolidate reporter country names and codes
rename countrylabel country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename country reporter
rename ISO3166 reporter_ISO
tab reporter if _merge == 1
replace reporter_ISO = "IOSEFER" if reporter == "International Organisation + SEFER (CPIS)"
replace reporter_ISO = "IO" if reporter == "International Organizations"
replace reporter_ISO = "Conf" if reporter == "Other Countries Confidential"
replace reporter_ISO = "???" if reporter == "Other Countries, not specified"
replace reporter_ISO = "Total" if reporter == "Total Reporting Countries"
replace reporter_ISO = "USOceania" if reporter == "US Possession in Oceania"
replace reporter_ISO = "CURSM" if reporter == "Curacao & St. Maarten"
replace reporter = "Timor-Leste, Dem. Rep. of" if reporter == "Timor" 
replace reporter_ISO = "TLS" if reporter == "Timor-Leste, Dem. Rep. of" // Footnote #1.
drop _merge
drop id n
gen id = reporter_ISO + "_" + partnercountrylabel + "_" + string(year) + "_" + indicator + "_" + string(value) 
bysort id: gen n = _n if _n == _N
tab n
drop if n == 2 // Footnote #2.


	**** 2.2. Consolidate partner country names and codes
rename partnercountrylabel country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename country partner
rename ISO3166 partner_ISO
tab partner if _merge == 1
replace partner_ISO = "IOSEFER" if partner == "International Organisation + SEFER (CPIS)"
replace partner_ISO = "IO" if partner == "International Organizations"
replace partner_ISO = "Conf" if partner == "Other Countries Confidential"
replace partner_ISO = "???" if partner == "Other Countries, not specified"
replace partner_ISO = "Total" if partner == "Total Reporting Countries"
replace partner_ISO = "USOceania" if partner == "US Possession in Oceania"
replace partner_ISO = "CURSM" if partner == "Curacao & St. Maarten"
replace partner_ISO = "TLS" if partner == "Timor" // Timor has an empty ISO in the raw-data.
replace partner = "Timor-Leste, Dem. Rep. of" if partner == "Timor"
drop _merge
drop id n
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + indicator + "_" + string(value) 
bysort id: gen n = _n if _n == _N
tab n
drop if n == 2 // See Footnote #2.


	**** 2.3. Create unique identifiers and reshape to wide
drop id n
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + indicator + "_" + string(value) 
bysort id: gen n = _n if _n == _N
tab n // No dupes on unique values.

drop id n
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + indicator
bysort id: gen n = _n if _n == _N
tab n
drop if value == 0 & n !=1 // Footnote #3.

drop id n
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n // The data-set is now ready for a wide re-shape, where ID varies only on the basis of indicator.

drop n
reshape wide value, i(id reporter reporter_ISO partner partner_ISO year) j(indicator) string
drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n // Check the wide worked, good.
drop n

// Check the missing value patterns are stable. Good.
misstable patterns, frequency
misstable nested
misstable summarize, all

renpfix value

// Set to panel
//egen id = group(reporter_ISO partner_ISO), label
//tsset id year

egen tag = tag(reporter)
export excel reporter reporter_ISO using "$data\codes_masterlist.xlsx" if reporter_ISO == "IOSEFER" & tag == 1 | reporter_ISO == "IO" & tag == 1 | reporter_ISO == "Conf" & tag == 1 | reporter_ISO == "???" & tag == 1 | reporter_ISO == "Total" & tag == 1 | reporter_ISO == "USOceania" & tag == 1 | reporter_ISO ==  "CURSM" & tag == 1, firstrow(variables) sheet("CPIS", replace)
drop tag

order id reporter reporter_ISO partner partner_ISO year PI_Assets PI_Liabilities PI_DerivedAssets PI_DerivedLiabilities
sort id
save "$results\CPIS.dta", replace 




**** 3. Import Coordinated Direct Investment Survey (IMF)
clear
insheet using "$data\CDIS_2concepts_bilat.csv", names
drop if missing(value) // 27,980
rename conceptlabel indicator
drop conceptcode datasourcelabel datasourcecode statuslabel statuscode unitcode timelabel frequencylabel frequencycode countrycode partnercountrycode
rename timecode year
destring year, replace

// Prepare indicator variable for a wide reshape.
replace indicator = "DI_Inward" if indicator == "Inward Direct Investment Positions" | indicator == "Inward Direct Investment Positions "
replace indicator = "DI_Outward"  if indicator == "Outward Direct Investment Positions"
replace indicator = "DI_DerivedInward" if indicator == "DI_Inward" & unitlabel == "US Dollars, Derived"
replace indicator = "DI_DerivedOutward" if indicator == "DI_Outward" & unitlabel == "US Dollars, Derived"
drop unitlabel
misstable summarize // Check the missing value patterns.
gen id = countrylabel + "_" + partnercountrylabel + "_" + string(year) + "_" + indicator + "_" + string(value) 
bysort id: gen n = _n if _n == _N
tab n // Check there are no duplicates within the raw data. OK.
drop id n
// 131,618 obs


	**** 3.1. Consolidate reporter country names and codes
rename countrylabel country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename country reporter
rename ISO3166 reporter_ISO
tab reporter if _merge == 1 // none
drop _merge


	**** 3.2. Consolidate partner country names and codes
rename partnercountrylabel country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename country partner
rename ISO3166 partner_ISO
tab partner if _merge == 1 // none
drop _merge


	**** 3.3. Create unique identifiers and reshape to wide
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n // The data-set is now ready for a wide re-shape, where ID varies only on the basis of indicator.
drop n

misstable summarize
reshape wide value, i(id reporter reporter_ISO partner partner_ISO year) j(indicator) string
drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n // Check the wide worked, good.
drop n

// Check the missing value patterns are stable. Good.
misstable patterns, frequency
misstable nested
misstable summarize, all

renpfix value

// Set to panel
//egen id = group(reporter_ISO partner_ISO), label
//tsset id year

order id reporter reporter_ISO partner partner_ISO year DI_Inward DI_Outward DI_DerivedInward DI_DerivedOutward
sort id
save "$results\CDIS.dta", replace 




**** 4. Merge CPIS and CDIS data
use "$results\CDIS.dta", clear 
mmerge id year using "$results\CPIS.dta"
bysort id: gen n = _n if _n == _N
tab n // no dupes!
drop _merge n

sort id
save "$results\CPIS_CDIS.dta", replace




**** 5. Import COMTRADE and consolidate
clear
insheet using "$data\COMTRADE_HS2007_AllTrade.CSV", names
drop if missing(tradevaluein1000usd) //0 missing
drop nomenclature productcode quantity quantitytoken qtyunit productdescription netweightinkgm tradeflowname //no need because we are dealing with aggregates
label define tradefl 1 "Gross Import" 2 "Gross Export" 3 "Re-Export" 4 "Re-Import" 5 "Import" 6 "Export"
label values tradeflowcode tradefl
//346,753


	****	5.1. Consolidate reporter country names and codes
rename reportername country
rename reporteriso3 ISO3166
mmerge country ISO3166 using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
count //346,753
tab country ISO3166 if _merge == 1
replace ISO3166 = "MNE" if ISO3166 == "MNT" //Montenegro
replace ISO3166 = "ROU" if ISO3166 == "ROM" //Romania
replace ISO3166 = "SDN" if ISO3166 == "SUD" //Sudan
replace ISO3166 = "SRB" if ISO3166 == "SER" //They have "Yugoslavia" with ISO of "SER". They already have "MKD" (Former Yugoslav Republic of Macedonia). 
// According to http://comtrade.un.org/db/mr/rfReportersList.aspx, the coverage of YUG (Former Yugos) stops in 1991 - so making executive decision to
// code this as Serbia.
rename country reporter
replace reporter = "Sudan" if reporter == "Fm Sudan"
rename ISO3166 reporter_ISO
drop _merge


	****	5.2. Consolidate partner country names and codes
rename partnername country
rename partneriso3 ISO3166
mmerge country ISO3166 using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
tab country ISO3166 if _merge == 1
replace ISO3166 = "COD" if ISO3166 == "ZAR" //Congo Dem. Rep.
replace ISO3166 = "TLS" if ISO3166 == "TMP" //East Timor
replace ISO3166 = "MNE" if ISO3166 == "MNT" //Montenegro
replace ISO3166 = "ROU" if ISO3166 == "ROM" //Romania
replace ISO3166 = "SDN" if ISO3166 == "SUD" //Sudan
replace ISO3166 = "SRB" if ISO3166 == "SER" //Yugoslavia
rename country partner 
replace partner = "Sudan" if partner == "Fm Sudan"
rename ISO3166 partner_ISO
drop _merge


	**** 5.3. Create unique identifiers and reshape to wide
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n //Need to reshape to wide for trade flows
drop n id

gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + string(tradeflowcode) + "_" + string(tradevalue)
bysort id: gen n = _n 
tab n //No dupes on individual values (despite email sent, woops)

replace tradevaluein1000usd = tradevaluein1000usd * 1000
rename tradevaluein1000usd value

drop n id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n 
tab n //No dupes only need to reshape wide
drop n

reshape wide value, i(id reporter reporter_ISO partner partner_ISO year) j(tradeflowcode)
//95,671 obs
rename value1 GrossImport
rename value2 GrossExport
rename value3 ReExport
rename value4 ReImport
rename value5 Import
rename value6 Export

//Check the wide worked!
drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n 
tab n //No dupes
drop n

egen tag = tag(reporter)
export excel reporter reporter_ISO using "$data\codes_masterlist.xlsx" if reporter_ISO == "EUN" & tag == 1 | reporter_ISO == "OAS" & tag == 1, firstrow(variables) sheet("Comtrade", replace)
drop tag

egen tag = tag(partner)
export excel partner partner_ISO using "$data\codes_masterlist.xlsx" if partner_ISO == "WLD" & tag == 1 | partner_ISO == "BUN" & tag == 1 | partner_ISO == "FRE" & tag == 1 | partner_ISO == "NZE" & tag == 1 | partner_ISO == "OAS" & tag == 1 | partner_ISO == "SPE" & tag == 1 | partner_ISO == "UNS" & tag == 1, firstrow(variables) sheet("Comtrade", modify) cell("A3")
drop tag

//egen id = group(reporter_ISO partner_ISO), label
//tsset id year

drop if missing(GrossImport) & missing(GrossExport) & missing(ReExport) & missing(ReImport) & missing(Import) & missing(Export) //none deleted

order id reporter reporter_ISO partner partner_ISO year Import Export GrossImport GrossExport ReImport ReExport
sort id

save "$results\Comtrade.dta", replace 




**** 6. Merge CPIS/CDIS data and COMTRADE, create panel
use "$results\CPIS_CDIS.dta", clear
mmerge id year using "$results\Comtrade.dta"

bysort id: gen n = _n if _n == _N
tab n // no dupes!
drop _merge n

list id if missing(GrossImport) & missing(GrossExport) & missing(ReExport) & missing(ReImport) & missing(Import) & missing(Export) & missing(DI_Inward) & missing(DI_Outward) & missing(DI_DerivedInward) & missing(DI_DerivedOutward) & missing(PI_Assets) & missing(PI_Liabilities) & missing(PI_DerivedAssets) & missing(PI_DerivedLiabilities)
//None missing

order id
sort id
//137,759
save "$results\FullPanel.dta", replace 




**** 7. Import Consolidated Banking Statistics (BIS)
global c "at au be br ca ch cl de dk es eu fi fr gb gr ie it jp kr mx nl pa pt se tr tw us"

foreach c in $c {
clear all
insheet using "$data\cbs-hanx9b-`c'.csv"

drop in 1/6

forval j = 1/1 {
foreach v of varlist v3-v121 {
	local new = substr(`v',1,3) + substr(`v',5,6)
	rename `v' `new'
	}
}

drop in 1
rename v1 partner
rename v2 detail_`c'

drop Dec83-Dec08

foreach v of varlist Mar09-Jun13 {
replace `v' = "." if `v' == "..."
}
destring Mar09-Jun13, replace

gen y2009 = Mar09 + Jun09 + Sep09 + Dec09
gen y2010 = Mar10 + Jun10 + Sep10 + Dec10
gen y2011 = Mar11 + Jun11 + Sep11 + Dec11
gen y2012 = Mar12 + Jun12 + Sep12 + Dec12
gen y2013 = Mar13 + Jun13

drop Mar09-Jun13

reshape long y, i(detail) j(year)
rename y BankClaims
gen reporter = "`c'"

order reporter partner year BankClaims detail
save "$data\CBS_`c'.dta", replace

}


	**** 7.1. Append all reporting countries together 
use "$data\CBS_at.dta", clear
save "$results\CBS.dta", replace
global c "au be br ca ch cl de dk es eu fi fr gb gr ie it jp kr mx nl pa pt se tr tw us"

foreach c in $c {
clear all
use "$results\CBS.dta"
append using "$data\CBS_`c'.dta"
save "$results\CBS.dta", replace
}

global c "at au be br ca ch cl de dk es eu fi fr gb gr ie it jp kr mx nl pa pt se tr tw us"
gen detail = ""
foreach v in varlist reporter-detail {
foreach c in $c {
replace detail = detail_`c' if reporter == "`c'"
}
}

keep reporter partner year BankClaims detail

save "$results\CBS.dta", replace


	**** 7.2. Consolidate country names
use "$results\CBS.dta", clear
drop if missing(BankClaims)

rename reporter who_ccode
replace who_ccode = upper(who_ccode)
mmerge who_ccode using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename ISO3166 reporter_ISO
replace reporter_ISO = "EUR" if who_ccode == "EU" //EU as defined by BIS
drop who_ccode

rename partner country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
rename ISO3166 partner_ISO //blah some custom BIS groups

replace partner_ISO = "AME" if country == "Africa & Middle East"
replace partner_ISO = "ALL" if country == "All countries"
replace partner_ISO = "APC" if country == "Asia & Pacific"
replace partner_ISO = "BOT" if country == "British Overseas Territories"
replace partner_ISO = "DVPED" if country == "Developed countries"
replace partner_ISO = "DVPING" if country == "Developing countries"
replace partner_ISO = "EUR" if country == "Europe"
replace partner_ISO = "INT" if country == "Int. organisations"
replace partner_ISO = "LAMC" if country == "Latin America/Caribbean"
replace partner_ISO = "OFC" if country == "Offshore centres"
replace partner_ISO = "OTHER" if country == "Other"
replace partner_ISO = "ODVPED" if country == "Other developed countries"
replace partner_ISO = "ResSM" if country == "Res. Serbia & Montenegro"
replace partner_ISO = "RES" if country == "Residual"
replace partner_ISO = "ResEUR" if country == "Residual Europe"
replace partner_ISO = "ResOFC" if country == "Residual Offshore centres"
replace partner_ISO = "ResDVPED" if country == "Residual developed countries"
replace partner_ISO = "ResFNA" if country == "Residual former Netherlands Antilles"
replace partner_ISO = "Una" if country == "Unallocated"
replace partner_ISO = "WIUK" if country == "West Indies UK"

bysort partner_ISO: gen id = _n 
export excel country partner_ISO using "$data\codes_masterlist.xlsx" if _merge == 1 & id == 1, firstrow(variables) sheet("BIS", replace) 
drop id _merge
rename country partner

order reporter_ISO partner partner_ISO year BankClaims detail
save "$results\CBS.dta", replace




/***** 8. Merge CPIS/CDIS/COMTRADE and BIS data, create panel
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + detail + string(BankClaims)
bysort id: gen n = _n 
drop if n != 1

drop n id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year) + "_" + detail 
bysort id: gen n = _n if _n == _N //Good, no dupes (only differs on the detail)

drop n id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
*/




**** 9. Import World Development Indicators (World Bank)

	**** 9.1. Loop WDI imports
clear
gen reporter_ISO = ""
gen reporter = ""
gen year = .
save "$results\WDI.dta", replace
global indic "NY.GNP.PCAP.CD SH.DYN.MORT SE.ADT.LITR.ZS FI.RES.TOTL.CD NY.GDP.MKTP.CD"

foreach i in $indic {
local WB = lower(`"`i'"')
local varname = subinstr(`"`WB'"', "." , "_" , .)
	
			clear all
			wbopendata, language(en - English) country() topics() indicator(`i') long
			rename countryname reporter
			rename countrycode reporter_ISO
			drop iso2code region regioncode
			drop if year < 2009

			drop if missing(`varname')
			mmerge reporter reporter_ISO year using "$results\WDI.dta"
			drop _merge
			save "$results\WDI.dta", replace
		}
	

	**** 9.2. Merge for reporters
use "$results\WDI.dta", clear
rename reporter country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
bysort reporter_ISO: gen n = _n
export excel country reporter_ISO using "$data\codes_masterlist.xlsx" if _merge == 1 & n == 1, firstrow(variables) sheet("WDI", replace)
replace ISO3166 = reporter_ISO if _merge == 1
drop reporter_ISO
rename ISO3166 reporter_ISO
rename country reporter
drop _merge n

gen id = reporter_ISO + string(year)
bysort id: gen n = _n if _n == _N //  HongKong dupes in raw data, manually check is OK to drop
drop if n != 1
drop id n

global indic "NY.GNP.PCAP.CD SH.DYN.MORT SE.ADT.LITR.ZS FI.RES.TOTL.CD NY.GDP.MKTP.CD"
foreach i in $indic {
local WB = lower(`"`i'"')
local varname = subinstr(`"`WB'"', "." , "_" , .)
renvars `varname', prefix(Reporter_)
}


save "$results\WDI_reporter.dta", replace


	**** 9.3. Mirror for partners
use "$results\WDI.dta", clear
rename reporter country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
bysort reporter_ISO: gen n = _n
export excel country reporter_ISO using "$data\codes_masterlist.xlsx" if _merge == 1 & n == 1, firstrow(variables) sheet("WDI", replace)
replace ISO3166 = reporter_ISO if _merge == 1
drop reporter_ISO
rename ISO3166 partner_ISO
rename country partner
drop _merge n

gen id = partner_ISO + string(year)
bysort id: gen n = _n if _n == _N //  HongKong dupes in raw data, manually check is OK to drop
drop if n != 1
drop id n

global indic "NY.GNP.PCAP.CD SH.DYN.MORT SE.ADT.LITR.ZS FI.RES.TOTL.CD NY.GDP.MKTP.CD"
foreach i in $indic {
local WB = lower(`"`i'"')
local varname = subinstr(`"`WB'"', "." , "_" , .)
renvars `varname', prefix(Partner_)
}


save "$results\WDI_partner.dta", replace


**** 10. Merge Full Panel with WDI indicators
use "$results\FullPanel.dta", clear
mmerge reporter_ISO year using "$results\WDI_reporter.dta"
drop if _merge == 2 // Drop if exists only in Using (e.g. we have no Panel)
drop _merge
// good, 137,759

mmerge partner_ISO year using "$results\WDI_partner.dta"
drop if _merge == 2 // Drop if exists only in Using (e.g. we have no Panel)

drop _merge id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n
tab n
drop n

//egen id = group(reporter_ISO partner_ISO), label /// CAUTION - This takes ages to run
//tsset id year

save "$results\FullPanel.dta", replace




**** 11. Import FSI data
clear
import excel "$data\FSI-Archive2009-2013.xlsx", sheet("FSI2011") firstrow
drop RANK FSIValue GlobalScaleWeight
destring(SecrecyScore), replace
rename Jurisdiction country
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)
drop in 1 //OK to drop because not a data point and didn't want to change import range in command as FSI data may change
drop _merge
rename country partner
rename ISO3166 partner_ISO
rename SecrecyScore PartnerSecrecyScore
gen year = 2011
save "$results/FSI_partner.dta", replace

rename partner reporter
rename partner_ISO reporter_ISO
rename PartnerSecrecyScore ReporterSecrecyScore
save "$results/FSI_reporter.dta", replace




**** 12. Merge Full Panel with FSI indicators
use "$results/FullPanel.dta", clear
mmerge partner_ISO year using "$results/FSI_partner.dta"
drop _merge

mmerge reporter_ISO year using "$results/FSI_reporter.dta"
drop _merge

drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n
tab n
drop n
// good, 137,759

save "$results/FullPanel.dta", replace




**** 13. Merge Full Panel with regional groups
use "$results/FullPanel.dta", clear
drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n
tab n // good, 137,759
drop n
save "$results/FullPanel.dta", replace


rename reporter_ISO ISO3166
rename reporter country
mmerge ISO3166 country using "$data\codes_masterlist.dta", unmatched(master) ukeep(UN_region UN_subregion)
rename ISO3166 reporter_ISO
rename country reporter
rename UN_region reporter_region
rename UN_subregion reporter_subregion

rename partner_ISO ISO3166
rename partner country
mmerge ISO3166 country using "$data\codes_masterlist.dta", unmatched(master) ukeep(UN_region UN_subregion)
rename ISO3166 partner_ISO
rename country partner
rename UN_region partner_region
rename UN_subregion partner_subregion
drop _merge

replace reporter_subregion = "Northern America" if reporter_region == "Northern America"
replace partner_subregion = "Northern America" if partner_region == "Northern America"

bysort reporter_ISO: gen tag = _n
export excel reporter reporter_ISO reporter_region using "$data\codes_masterlist.xlsx" if tag == 1 & reporter_region == "" | tag == 1 & reporter_subregion == "", firstrow(variables) sheet("Missing Regions", modify) cell("A1")
drop tag
bysort partner_ISO: gen tag = _n
export excel partner partner_ISO partner_region using "$data\codes_masterlist.xlsx" if tag == 1 & partner_region == "" | tag == 1 & partner_subregion == "", firstrow(variables) sheet("Missing Regions", modify) cell("D1")
drop tag

// Example of suspicious partner, e.g. Antartica
gen ATA = 1 if partner_ISO == "ATA"
gen pair = reporter_ISO + "_" + partner_ISO
bysort pair : gen r = _n
export excel reporter partner year Import Export GrossImport GrossExport ReImport ReExport using "$data\codes_masterlist.xlsx" if r == 1 & partner_ISO == "ATA", firstrow(variables) sheet("ReportTradeWATA", replace)
drop pair r ATA

save "$results/FullPanel.dta", replace




**** 14. Merge Full Panel with income groups
use "$results/FullPanel.dta", clear
gen ReporterIncomeGroup = 1 if !missing(Reporter_ny_gnp_pcap_cd) & Reporter_ny_gnp_pcap_cd <= 1035
replace ReporterIncomeGroup = 2 if !missing(Reporter_ny_gnp_pcap_cd) & Reporter_ny_gnp_pcap_cd >= 1036 & Reporter_ny_gnp_pcap_cd <= 4085
replace ReporterIncomeGroup = 3 if !missing(Reporter_ny_gnp_pcap_cd) & Reporter_ny_gnp_pcap_cd >= 4086 & Reporter_ny_gnp_pcap_cd <= 12615
replace ReporterIncomeGroup = 4 if !missing(Reporter_ny_gnp_pcap_cd) & Reporter_ny_gnp_pcap_cd >= 12616
label define IGr 1 "LIC" 2 "LMIC" 3 "UMIC" 4 "HIC"
label values ReporterIncomeGroup IGr

gen PartnerIncomeGroup = 1 if !missing(Partner_ny_gnp_pcap_cd) & Partner_ny_gnp_pcap_cd <= 1035
replace PartnerIncomeGroup = 2 if !missing(Partner_ny_gnp_pcap_cd) & Partner_ny_gnp_pcap_cd >= 1036 & Partner_ny_gnp_pcap_cd <= 4085
replace PartnerIncomeGroup = 3 if !missing(Partner_ny_gnp_pcap_cd) & Partner_ny_gnp_pcap_cd >= 4086 & Partner_ny_gnp_pcap_cd <= 12615
replace PartnerIncomeGroup = 4 if !missing(Partner_ny_gnp_pcap_cd) & Partner_ny_gnp_pcap_cd >= 12616
label define IGp 1 "LIC" 2 "LMIC" 3 "UMIC" 4 "HIC"
label values PartnerIncomeGroup IGp

bysort reporter_ISO: gen tag = _n
export excel reporter reporter_ISO using "$data\codes_masterlist.xlsx" if tag == 1 & missing(ReporterIncomeGroup), firstrow(variables) sheet("Missing GNI", replace)
export excel reporter reporter_ISO using "$data\codes_masterlist.xlsx" if tag == 1 & missing(ReporterIncomeGroup), firstrow(variables) sheet("Missing GDP", replace)
drop tag

bysort partner_ISO: gen tag = _n
export excel partner partner_ISO using "$data\codes_masterlist.xlsx" if tag == 1 & missing(PartnerIncomeGroup), firstrow(variables) sheet("Missing GNI", modify) cell("C1")
export excel partner partner_ISO using "$data\codes_masterlist.xlsx" if tag == 1 & missing(PartnerIncomeGroup), firstrow(variables) sheet("Missing GDP", modify) cell("C1")
drop tag

save "$results/FullPanel.dta", replace






/* /////////////////////////////////////////////////////////////////////////////
VULNERABILITIES AND EXPOSURE ANALYSIS
///////////////////////////////////////////////////////////////////////////// */

**** 1. Vulnerability scores for country of interest	
use "$results/FullPanel.dta", clear

keep if year == 2011
drop id
gen id = reporter_ISO + "_" + partner_ISO + "_" + string(year)
bysort id: gen n = _n if _n == _N
tab n
//drop id 
drop n

misstable summarize

//egen id = group(reporter_ISO partner_ISO), label
//tsset id year
save "$results/FullPanel.dta", replace


// Generate dummy Secrecy Scores for countries with no SS equal to the least secretive
egen ReporterSecrecyScoreMin = min(ReporterSecrecyScore)
replace ReporterSecrecyScoreMin = ReporterSecrecyScore if !missing(ReporterSecrecyScore)
egen PartnerSecrecyScoreMin = min(PartnerSecrecyScore)
replace PartnerSecrecyScoreMin = PartnerSecrecyScore if !missing(PartnerSecrecyScore)

save "$results/FullPanel.dta", replace



	**** 1.1. Vulnerability scores in Trade flows
use "$results/FullPanel.dta", clear
replace PartnerSecrecyScore = 0 if missing(PartnerSecrecyScore) // So don't have to deal with specifying not missing in future conditions

		**** 1.1.1. From reporter perspective
// Imports
sort reporter_ISO
by reporter_ISO: egen ImpWithSJ = total(Import) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore) // B_i only with SJ, checked
by reporter_ISO: egen TotImp = total(Import) // B_i with all countries

by reporter_ISO: egen VISJ = total ((Import * PartnerSecrecyScore) / ImpWithSJ ) //same number of obs, checked
by reporter_ISO: egen VI = total ((Import * PartnerSecrecyScore) / TotImp )
by reporter_ISO: egen VIMin = total ((Import * PartnerSecrecyScoreMin) / TotImp )

// Exports
by reporter_ISO: egen ExpWithSJ = total(Export) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore)
by reporter_ISO: egen TotExp = total(Export) 

by reporter_ISO: egen VESJ = total ((Export * PartnerSecrecyScore) / ExpWithSJ ) //same number of obs, checked
by reporter_ISO: egen VE = total ((Export * PartnerSecrecyScore) / TotExp )
by reporter_ISO: egen VEMin = total ((Export * PartnerSecrecyScoreMin) / TotExp )


		**** 1.1.2. From reporter perspective
// Imports
sort partner_ISO
by partner_ISO: egen pImpWithSJ = total(Import) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore) // B_i only with SJ, checked
by partner_ISO: egen pTotImp = total(Import) // B_i with all countries

by partner_ISO: egen pVISJ = total ((Import * ReporterSecrecyScore) / pImpWithSJ ) 
by partner_ISO: egen pVI = total ((Import * ReporterSecrecyScore) / pTotImp )
by partner_ISO: egen pVIMin = total ((Import * ReporterSecrecyScoreMin) / pTotImp )

// Exports
by partner_ISO: egen pExpWithSJ = total(Export) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore)
by partner_ISO: egen pTotExp = total(Export) 

by partner_ISO: egen pVESJ = total ((Export * ReporterSecrecyScore) / pExpWithSJ ) 
by partner_ISO: egen pVE = total ((Export * ReporterSecrecyScore) / pTotExp )
by partner_ISO: egen pVEMin = total ((Export * ReporterSecrecyScoreMin) / pTotExp )



	**** 1.2. Vulnerability scores in Direct Investment stocks

		**** 1.2.1. From reporter perspective
// Inward Direct Investment
sort reporter_ISO
by reporter_ISO: egen DIIWithSJ = total(DI_Inward) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore)
by reporter_ISO: egen TotDII = total(DI_Inward)

by reporter_ISO: egen VDIISJ = total ((DI_Inward * PartnerSecrecyScore) / DIIWithSJ ) //same number of obs, checked
by reporter_ISO: egen VDII = total ((DI_Inward * PartnerSecrecyScore) / TotDII )
by reporter_ISO: egen VDIIMin = total ((DI_Inward * PartnerSecrecyScoreMin) / TotDII )

// Outward Direct Investment
by reporter_ISO: egen DIOWithSJ = total(DI_Outward) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore)
by reporter_ISO: egen TotDIO = total(DI_Outward)

by reporter_ISO: egen VDIOSJ = total ((DI_Outward * PartnerSecrecyScore) / DIOWithSJ ) //same number of obs, checked
by reporter_ISO: egen VDIO = total ((DI_Outward * PartnerSecrecyScore) / TotDIO )
by reporter_ISO: egen VDIOMin = total ((DI_Outward * PartnerSecrecyScoreMin) / TotDIO )


		**** 1.2.2. From partner perspective
// Inward Direct Investment
sort partner_ISO
by partner_ISO: egen pDIIWithSJ = total(DI_Inward) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore)
by partner_ISO: egen pTotDII = total(DI_Inward)

by partner_ISO: egen pVDIISJ = total ((DI_Inward * ReporterSecrecyScore) / pDIIWithSJ )
by partner_ISO: egen pVDII = total ((DI_Inward * ReporterSecrecyScore) / pTotDII )
by partner_ISO: egen pVDIIMin = total ((DI_Inward * ReporterSecrecyScoreMin) / pTotDII )

// Outward Direct Investment
by partner_ISO: egen pDIOWithSJ = total(DI_Outward) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore)
by partner_ISO: egen pTotDIO = total(DI_Outward)

by partner_ISO: egen pVDIOSJ = total ((DI_Outward * ReporterSecrecyScore) / pDIOWithSJ )
by partner_ISO: egen pVDIO = total ((DI_Outward * ReporterSecrecyScore) / pTotDIO )
by partner_ISO: egen pVDIOMin = total ((DI_Outward * ReporterSecrecyScoreMin) / pTotDIO )



	**** 1.3. Vulnerability scores in Portfolio Investment stocks
		
		**** 1.3.1. From reporter perspective
// Assets Portfolio Investment
sort reporter_ISO		
by reporter_ISO: egen PIAWithSJ = total(PI_Assets) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore)
by reporter_ISO: egen TotPIA = total(PI_Assets)

by reporter_ISO: egen VPIASJ = total ((PI_Assets * PartnerSecrecyScore) / PIAWithSJ ) //same number of obs, checked
by reporter_ISO: egen VPIA = total ((PI_Assets * PartnerSecrecyScore) / TotPIA )
by reporter_ISO: egen VPIAMin = total ((PI_Assets * PartnerSecrecyScoreMin) / TotPIA )

// Liabilities Portfolio Investment		
by reporter_ISO: egen PILWithSJ = total(PI_Liabilities) if PartnerSecrecyScore != 0 & !missing(PartnerSecrecyScore)
by reporter_ISO: egen TotPIL = total(PI_Liabilities)

by reporter_ISO: egen VPILSJ = total ((PI_Liabilities * PartnerSecrecyScore) / PILWithSJ ) //same number of obs, checked
by reporter_ISO: egen VPIL = total ((PI_Liabilities * PartnerSecrecyScore) / TotPIL )
by reporter_ISO: egen VPILMin = total ((PI_Liabilities * PartnerSecrecyScoreMin) / TotPIL )
egen test = total ((PI_Liabilities * PartnerSecrecyScoreMin) / TotPIL ) if !missing(PI_Liabilities) 


		**** 1.3.2. From partner perspective
// Assets Portfolio Investment
sort partner_ISO		
by partner_ISO: egen pPIAWithSJ = total(PI_Assets) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore)
by partner_ISO: egen pTotPIA = total(PI_Assets)

by partner_ISO: egen pVPIASJ = total ((PI_Assets * ReporterSecrecyScore) / pPIAWithSJ ) 
by partner_ISO: egen pVPIA = total ((PI_Assets * ReporterSecrecyScore) / pTotPIA )
by partner_ISO: egen pVPIAMin = total ((PI_Assets * ReporterSecrecyScoreMin) / pTotPIA )

// Liabilities Portfolio Investment		
by partner_ISO: egen pPILWithSJ = total(PI_Liabilities) if ReporterSecrecyScore != 0 & !missing(ReporterSecrecyScore)
by partner_ISO: egen pTotPIL = total(PI_Liabilities)

by partner_ISO: egen pVPILSJ = total ((PI_Liabilities * ReporterSecrecyScore) / pPILWithSJ )
by partner_ISO: egen pVPIL = total ((PI_Liabilities * ReporterSecrecyScore) / pTotPIL )
by partner_ISO: egen pVPILMin = total ((PI_Liabilities * ReporterSecrecyScoreMin) / pTotPIL )





**** 2. Jurisdiction-level Exposure scores for country of interest
rename Reporter_ny_gdp_mktp_cd ReporterGDP
rename Partner_ny_gdp_mktp_cd PartnerGDP


	**** 2.1. Exposure in Trade flows

			**** 2.1.1. From reporter perspective
// Imports
gen EI = VI * TotImp / ReporterGDP // Checked that this is equivalent to gen EI = VI * II
gen EISJ = VISJ * ImpWithSJ / ReporterGDP // Checked that this is equivalent to gen EISJ = VISJ * IISJ
gen EIMin = VIMin * TotImp / ReporterGDP // Checked that this is equivalent to gen EISJ = VISJ * IISJ

// Exports
gen EE = VE * TotExp / ReporterGDP
gen EESJ = VESJ * ExpWithSJ / ReporterGDP
gen EEMin = VEMin * TotExp / ReporterGDP


			**** 2.1.2. From partner perspective
// Imports
gen pEI = pVI * pTotImp / PartnerGDP
gen pEISJ = pVISJ * pImpWithSJ / PartnerGDP
gen pEIMin = pVIMin * pTotImp / PartnerGDP 

// Exports
gen pEE = pVE * pTotExp / PartnerGDP
gen pEESJ = pVESJ * pExpWithSJ / PartnerGDP
gen pEEMin = pVEMin * pTotExp / PartnerGDP



	**** 2.2. Exposure in Trade flows

			**** 2.2.1. From reporter perspective
// Inward Direct Investment
gen EDII = VDII * TotDII / ReporterGDP // Checked that this is equivalent to gen EDII = VDII * IDII
gen EDIISJ = VDIISJ * DIIWithSJ / ReporterGDP // Checked that this is equivalent to gen EDIISJ = VDIISJ * IDIISJ
gen EDIIMin = VDIIMin * TotDII / ReporterGDP // Checked that this is equivalent to gen EDIIMin = VDIIMin * IDIIMin

// Outward Direct Investment
gen EDIO = VDIO * TotDIO / ReporterGDP
gen EDIOSJ = VDIOSJ * DIOWithSJ / ReporterGDP
gen EDIOMin = VDIOMin * TotDIO / ReporterGDP


			**** 2.2.2. From partner perspective
// Inward Direct Investment
gen pEDII = pVDII * pTotDII / PartnerGDP
gen pEDIISJ = pVDIISJ * pDIIWithSJ / PartnerGDP
gen pEDIIMin = pVDIIMin * pTotDII / PartnerGDP

// Outward Direct Investment
gen pEDIO = pVDIO * pTotDIO / PartnerGDP
gen pEDIOSJ = pVDIOSJ * pDIOWithSJ / PartnerGDP
gen pEDIOMin = pVDIOMin * pTotDIO / PartnerGDP



	**** 2.3. Exposure in Trade flows

			**** 2.3.1. From reporter perspective
// Assets Portfolio Investment
gen EPIA = VPIA * TotPIA / ReporterGDP
gen EPIASJ = VPIASJ * PIAWithSJ / ReporterGDP
gen EPIAMin = VPIAMin * TotPIA / ReporterGDP

// Liabilities Portfolio Investment
gen EPIL = VPIL * TotPIL / ReporterGDP
gen EPILSJ = VPILSJ * PILWithSJ / ReporterGDP
gen EPILMin = VPILMin * TotPIL / ReporterGDP


			**** 2.3.2. From partner perspective
// Assets Portfolio Investment
gen pEPIA = pVPIA * pTotPIA / PartnerGDP
gen pEPIASJ = pVPIASJ * pPIAWithSJ / PartnerGDP
gen pEPIAMin = pVPIAMin * pTotPIA / PartnerGDP

// Liabilities Portfolio Investment
gen pEPIL = pVPIL * pTotPIL / PartnerGDP
gen pEPILSJ = pVPILSJ * pPILWithSJ / PartnerGDP
gen pEPILMin = pVPILMin * pTotPIL / PartnerGDP





**** 3. Jurisdiction-level Importance of flows/stocks to country of interest's GDP

	**** 3.1. For reporters
gen II = TotImp / ReporterGDP
gen IISJ = ImpWithSJ / ReporterGDP

gen IE = TotExp / ReporterGDP
gen IESJ = ExpWithSJ / ReporterGDP

gen IDII = TotDII / ReporterGDP
gen IDIISJ = DIIWithSJ / ReporterGDP

gen IDIO = TotDIO / ReporterGDP
gen IDIOSJ = DIOWithSJ / ReporterGDP

gen IPIA = TotPIA / ReporterGDP
gen IPIASJ = PIAWithSJ / ReporterGDP

gen IPIL = TotPIL / ReporterGDP
gen IPILSJ = PILWithSJ / ReporterGDP


	**** 3.2. For partners
gen pII = pTotImp / PartnerGDP
gen pIISJ = pImpWithSJ / PartnerGDP

gen pIE = pTotExp / PartnerGDP
gen pIESJ = pExpWithSJ / PartnerGDP

gen pIDII = pTotDII / PartnerGDP
gen pIDIISJ = pDIIWithSJ / PartnerGDP

gen pIDIO = pTotDIO / PartnerGDP
gen pIDIOSJ = pDIOWithSJ / PartnerGDP

gen pIPIA = pTotPIA / PartnerGDP
gen pIPIASJ = pPIAWithSJ / PartnerGDP

gen pIPIL = pTotPIL / PartnerGDP
gen pIPILSJ = pPILWithSJ / PartnerGDP





**** 4. Jurisdiction-level mean Vulnerability, Importance and Exposure scores

	**** 4.1. For reporters
egen E = rowmean(EI EE EDII EDIO EPIA EPIL)
egen ESJ = rowmean(EISJ EESJ EDIISJ EDIOSJ EPIASJ EPILSJ)
egen EMin = rowmean(EIMin EEMin EDIIMin  EDIOMin EPIAMin EPILMin)

egen V = rowmean(VI VE VDII VDIO VPIA VPIL)
egen I = rowmean(II IE IDII IDIO IPIA IPIL)


	**** 4.2. For partners
egen pE = rowmean(pEI pEE pEDII pEDIO pEPIA pEPIL)
egen pESJ = rowmean(pEISJ pEESJ pEDIISJ pEDIOSJ pEPIASJ pEPILSJ)
egen pEMin = rowmean(pEIMin pEEMin pEDIIMin pEDIOMin pEPIAMin pEPILMin)





**** 5. Dummy Groups for Exposure and Secrecy Scores

	**** 5.1. Exposure scores
// Generating cut-off points at third quartile for exposure
egen Q3EMin = pctile(EMin), p(75)

// Putting countries in quartiles according to their exposure scores
_pctile(E), p(25 50 75)
gen Q = 1 if E < r(r1)
_pctile(E), p(25 50 75)
replace Q = 2 if E >= r(r1) & E < r(r2)
_pctile(E), p(25 50 75)
replace Q = 3 if E >= r(r2) & E < r(r3)
_pctile(E), p(25 50 75)
replace Q = 4 if E >= r(r3)


	**** 5.2. Secrecy scores
	
		**** 5.2.1. Partner secrecy scores
mvdecode PartnerSecrecyScore, mv(0=.)
gen QSSp = 1 if missing(PartnerSecrecyScore)
_pctile(PartnerSecrecyScore), p(25 50 75)
return list
replace QSSp = 2 if PartnerSecrecyScore < r(r1)
_pctile(PartnerSecrecyScore), p(25 50 75)
replace QSSp = 3 if PartnerSecrecyScore >= r(r1) & PartnerSecrecyScore < r(r2)
_pctile(PartnerSecrecyScore), p(25 50 75)
replace QSSp = 4 if PartnerSecrecyScore >= r(r2) & PartnerSecrecyScore < r(r3)
_pctile(PartnerSecrecyScore), p(25 50 75)
replace QSSp = 5 if PartnerSecrecyScore >= r(r3) & !missing(PartnerSecrecyScore)
label define Qp 1 "Least secretive" 2 "Moderately secretive" 3 "Secretive" 4 "Very secretive" 5 "Most secretive"
label values QSSp Qp
mvencode PartnerSecrecyScore, mv(.=0)

		**** 5.2.1. Reporter secrecy scores
mvdecode ReporterSecrecyScore, mv(0=.)
gen QSSr = 1 if missing(ReporterSecrecyScore)
_pctile(ReporterSecrecyScore), p(25 50 75)
return list
replace QSSr = 2 if ReporterSecrecyScore < r(r1)
_pctile(ReporterSecrecyScore), p(25 50 75)
replace QSSr = 3 if ReporterSecrecyScore >= r(r1) & ReporterSecrecyScore < r(r2)
_pctile(ReporterSecrecyScore), p(25 50 75)
replace QSSr = 4 if ReporterSecrecyScore >= r(r2) & ReporterSecrecyScore < r(r3)
_pctile(ReporterSecrecyScore), p(25 50 75)
replace QSSr = 5 if ReporterSecrecyScore >= r(r3) & !missing(ReporterSecrecyScore)
label define Qr 1 "Least secretive" 2 "Moderately secretive" 3 "Secretive" 4 "Very secretive" 5 "Most secretive"
label values QSSr Qr
mvencode ReporterSecrecyScore, mv(.=0)





**** 6. Weighted (region-specific and income group-specific) Exposure scores

	**** 6.1. Generate region specific exposure scores (countries from same region will have same Exposure score)

		**** 6.1.1. Vulnerability
sort reporter_region
by reporter_region: egen wTotImp = total(Import)
by reporter_region: egen wTotExport = total(Export)
by reporter_region: egen wVIMin = total ((Import * PartnerSecrecyScoreMin) / wTotImp )
by reporter_region: egen wVEMin = total ((Export * PartnerSecrecyScoreMin) / wTotExp )

by reporter_region: egen wTotDII = total(DI_Inward)
by reporter_region: egen wTotDIO = total(DI_Outward)
by reporter_region: egen wVDIIMin = total ((DI_Inward * PartnerSecrecyScoreMin) / wTotDII )
by reporter_region: egen wVDIOMin = total ((DI_Outward * PartnerSecrecyScoreMin) / wTotDIO )

by reporter_region: egen wTotPIA = total(PI_Assets)
by reporter_region: egen wTotPIL = total(PI_Liabilities)
by reporter_region: egen wVPIAMin = total ((PI_Assets * PartnerSecrecyScoreMin) / wTotPIA )
by reporter_region: egen wVPILMin = total ((PI_Liabilities * PartnerSecrecyScoreMin) / wTotPIL )


		**** 6.1.2. Importance
by reporter_region: egen wReporterGDP = total(ReporterGDP)
gen wII = wTotImp / wReporterGDP
gen wIE = wTotExp / wReporterGDP
gen wIDII = wTotDII / wReporterGDP
gen wIDIO = wTotDIO / wReporterGDP
gen wIPIA = wTotPIA / wReporterGDP
gen wIPIL = wTotPIL / wReporterGDP


		**** 6.1.3. Exposure = Vulnerability x Importance
gen wEIMin = wVIMin * wII
gen wEEMin = wVEMin * wIE
gen wEDIIMin = wVDIIMin * wIDII
gen wEDIOMin = wVDIOMin * wIDIO
gen wEPIAMin = wVPIAMin * wIPIA
gen wEPILMin = wVPILMin * wIPIL

// Total Exposure for a region
egen wEMin = rowtotal(wEIMin wEEMin wEDIIMin  wEDIOMin wEPIAMin wEPILMin)



	**** 6.2. Generate income group specific exposure scores (countries in same income group will have same Exposure score)

		**** 6.2.1. Vulnerability
sort ReporterIncomeGroup
by ReporterIncomeGroup: egen wiTotImp = total(Import)
by ReporterIncomeGroup: egen wiTotExport = total(Export)
by ReporterIncomeGroup: egen wiVIMin = total ((Import * PartnerSecrecyScoreMin) / wiTotImp )
by ReporterIncomeGroup: egen wiVEMin = total ((Export * PartnerSecrecyScoreMin) / wiTotExp )

by ReporterIncomeGroup: egen wiTotDII = total(DI_Inward)
by ReporterIncomeGroup: egen wiTotDIO = total(DI_Outward)
by ReporterIncomeGroup: egen wiVDIIMin = total ((DI_Inward * PartnerSecrecyScoreMin) / wiTotDII )
by ReporterIncomeGroup: egen wiVDIOMin = total ((DI_Outward * PartnerSecrecyScoreMin) / wiTotDIO )

by ReporterIncomeGroup: egen wiTotPIA = total(PI_Assets)
by ReporterIncomeGroup: egen wiTotPIL = total(PI_Liabilities)
by ReporterIncomeGroup: egen wiVPIAMin = total ((PI_Assets * PartnerSecrecyScoreMin) / wiTotPIA )
by ReporterIncomeGroup: egen wiVPILMin = total ((PI_Liabilities * PartnerSecrecyScoreMin) / wiTotPIL )


		**** 6.2.2. Importance
by ReporterIncomeGroup: egen wiReporterGDP = total(ReporterGDP)
gen wiII = wiTotImp / wiReporterGDP
gen wiIE = wiTotExp / wiReporterGDP
gen wiIDII = wiTotDII / wiReporterGDP
gen wiIDIO = wiTotDIO / wiReporterGDP
gen wiIPIA = wiTotPIA / wiReporterGDP
gen wiIPIL = wiTotPIL / wiReporterGDP


		**** 6.2.3. Exposure = Vulnerability x Importance
gen wiEIMin = wiVIMin * wiII
gen wiEEMin = wiVEMin * wiIE
gen wiEDIIMin = wiVDIIMin * wiIDII
gen wiEDIOMin = wiVDIOMin * wiIDIO
gen wiEPIAMin = wiVPIAMin * wiIPIA
gen wiEPILMin = wiVPILMin * wiIPIL

// Total Exposure for an income group
egen wiEMin = rowtotal(wiEIMin wiEEMin wiEDIIMin  wiEDIOMin wiEPIAMin wiEPILMin)





**** 7. Labels and extra stuff
label variable II "Imports to GDP"
label variable IE "Exports to GDP"
label variable IDII "Inward Direct Investment to GDP"
label variable IDIO "Outward Direct Investment to GDP"
label variable IPIA "Portfolio Investment Assets to GDP"
label variable IPIL "Portfolio Investment Liabilities to GDP"

label variable EIMin "Imports"
label variable EEMin "Exports to GDP"
label variable EDIIMin "Inward Direct Investment"
label variable EDIOMin "Outward Direct Investment"
label variable EPIAMin "Portfolio Investment Assets"
label variable EPILMin "Portfolio Investment Liabilities"

save "$results/FullPanel.dta", replace






/* /////////////////////////////////////////////////////////////////////////////
GRAPHS AND OUTPUTS
///////////////////////////////////////////////////////////////////////////// */

use "$results\FullPanel.dta", clear

**** 1. Jurisdiction-level Vulnerability scores

	**** 1.1. Vulnerability scores in Trade flows
// From reporter perspective
graph bar (mean) VISJ, over(reporter_region, label(angle(-45))) title("Import Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VI, over(reporter_region, label(angle(-45)))  title("Import Vulnerability of reporters") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VIMin, over(reporter_region, label(angle(-45))) title("Import Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) VESJ, over(reporter_region, label(angle(-45))) title("Export Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability of score")
graph bar (mean) VE, over(reporter_region, label(angle(-45))) title("Export Vulnerability of reporters") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability of score")
graph bar (mean) VEMin, over(reporter_region, label(angle(-45))) title("Export Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability of Imports")

// From partner perspective
graph bar (mean) pVISJ, over(partner_region, label(angle(-45))) title("Import Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVI, over(partner_region, label(angle(-45)))  title("Import Vulnerability of partners") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVIMin, over(partner_region, label(angle(-45))) title("Import Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) pVESJ, over(partner_region, label(angle(-45))) title("Export Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability of score")
graph bar (mean) pVE, over(partner_region, label(angle(-45))) title("Export Vulnerability of partners") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability of score")
graph bar (mean) pVEMin, over(partner_region, label(angle(-45))) title("Export Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability of Imports")



		**** 1.2. Vulnerability scores in Direct Investment stocks
// From reporter perspective
graph bar (mean) VDIISJ, over(reporter_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VDII, over(reporter_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of reporters") subtitle("Trading all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VDIIMin, over(reporter_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) VDIOSJ, over(reporter_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VDIO, over(reporter_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of reporters") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VDIOMin, over(reporter_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")

// From partner perspective
graph bar (mean) pVDIISJ, over(partner_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVDII, over(partner_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of partners") subtitle("Trading all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVDIIMin, over(partner_region, label(angle(-45))) title("Direct Investment (inward) Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) pVDIOSJ, over(partner_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVDIO, over(partner_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of partners") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVDIOMin, over(partner_region, label(angle(-45))) title("Direct Investment (outward) Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")



		**** 1.3. Vulnerability scores in Portfolio Investment stocks
// From reporter perspective
graph bar (mean) VPIASJ, over(reporter_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VPIA, over(reporter_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of reporters") subtitle("Trading all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VPIAMin, over(reporter_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) VPILSJ, over(reporter_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VPIL, over(reporter_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of reporters") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) VPILMin, over(reporter_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")

// From partner perspective
graph bar (mean) pVPIASJ, over(partner_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVPIA, over(partner_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of partners") subtitle("Trading all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVPIAMin, over(partner_region, label(angle(-45))) title("Portfolio Investment (assets) Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")
graph bar (mean) pVPILSJ, over(partner_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVPIL, over(partner_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of partners") subtitle("Trading with all jurisdictions") ytitle("Mean vulnerability score")
graph bar (mean) pVPILMin, over(partner_region, label(angle(-45))) title("Portfolio Investment (liabilities) Vulnerability of partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean vulnerability score")




**** 2. Jurisdiction-level Exposure scores

		**** 2.1. Exposure in Trade flows
// From reporter perspective - Imports
graph bar (mean) EI, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Imports by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EISJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Imports by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EIMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Imports by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EI, over(ReporterIncomeGroup) title("Exposure of Imports by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EISJ, over(ReporterIncomeGroup) title("Exposure of Imports by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EIMin, over(ReporterIncomeGroup) title("Exposure of Imports by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From reporter perspective - Exports
graph bar (mean) EE, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Exports by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EESJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Exports by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EEMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Exports by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EE, over(ReporterIncomeGroup) title("Exposure of Exports by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EESJ, over(ReporterIncomeGroup) title("Exposure of Exports by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EEMin, over(ReporterIncomeGroup) title("Exposure of Exports by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partner perspective - Imports
graph bar (mean) pEI, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Imports by partners") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEISJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Imports by partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEIMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Imports by partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEI, over(PartnerIncomeGroup) title("Exposure of Imports by partners") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEISJ, over(PartnerIncomeGroup) title("Exposure of Imports by partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEIMin, over(PartnerIncomeGroup) title("Exposure of Imports by partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partner perspective - Exports
graph bar (mean) pEE, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Exports by partners") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEESJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Exports by partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEEMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Exports by partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEE, over(PartnerIncomeGroup) title("Exposure of Exports by partners") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEESJ, over(PartnerIncomeGroup) title("Exposure of Exports by partners") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEEMin, over(PartnerIncomeGroup) title("Exposure of Exports by partners") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")



		**** 2.2. Exposure in Direct Investment Stocks
// From reporter perspective - Direct Investment Inward
graph bar (mean) EDII, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIISJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIIMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EDII, over(ReporterIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIISJ, over(ReporterIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIIMin, over(ReporterIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From reporter perspective - Direct Investment Outward
graph bar (mean) EDIO, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIOSJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIOMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EDIO, over(ReporterIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIOSJ, over(ReporterIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EDIOMin, over(ReporterIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partner perspective - Direct Investment Inward
graph bar (mean) pEDII, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIISJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIIMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEDII, over(PartnerIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIISJ, over(PartnerIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIIMin, over(PartnerIncomeGroup) title("Exposure of Direct Investment (inward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partner perspective - Direct Investment Outward
graph bar (mean) pEDIO, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIOSJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIOMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEDIO, over(PartnerIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIOSJ, over(PartnerIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEDIOMin, over(PartnerIncomeGroup) title("Exposure of Direct Investment (outward) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")



		**** 2.3. Exposure in Portfolio Investment Stocks
// From reporter perspective - Portfolio Investment Assets
graph bar (mean) EPIA, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPIASJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPIAMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EPIA, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPIASJ, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (assets)) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPIAMin, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From reporter perspective - Portfolio Investment Liabilities
graph bar (mean) EPIL, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPILSJ, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPILMin, over(reporter_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) EPIL, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPILSJ, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (liabilities)) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) EPILMin, over(ReporterIncomeGroup) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partner perspective - Portfolio Investment Assets
graph bar (mean) pEPIA, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPIASJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPIAMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEPIA, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPIASJ, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (assets)) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPIAMin, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (assets) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")

// From partners perspective - Portfolio Investment Liabilities
graph bar (mean) pEPIL, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPILSJ, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPILMin, over(partner_region, label(angle(-45) labsize(small))) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")
graph bar (mean) pEPIL, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPILSJ, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (liabilities)) by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean exposure score")
graph bar (mean) pEPILMin, over(PartnerIncomeGroup) title("Exposure of Portfolio Investment (liabilities) by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean exposure score")




**** 3. Stacked Exposure Scores (unweighted, i.e. unweighted mean jurisdiction-level scores) - From Reporter perspective

	**** 3.1. Assuming partner countries without Secrecy Scores are fully transparent
//By region
graph bar (mean) EI (mean) EE (mean) EDII (mean) EDIO (mean) EPIA (mean) EPIL, over(reporter_region, sort(E) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//By income group
graph bar (mean) EI (mean) EE (mean) EDII (mean) EDIO (mean) EPIA (mean) EPIL, over(ReporterIncomeGroup, sort(E) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by jurisdiction
graph bar (mean) EI (mean) EE (mean) EDII (mean) EDIO (mean) EPIA (mean) EPIL if reporter_region == "Africa", over(reporter, sort(E) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by subregion
graph bar (mean) EI (mean) EE (mean) EDII (mean) EDIO (mean) EPIA (mean) EPIL if reporter_region == "Africa", over(reporter_subregion, sort(E) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions") ytitle("Mean (unweighted) exposure score") stack


	**** 3.2. Assuming partner countries without Secrecy Scores are at least as secretive as best performer on FSI
//By region
graph bar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin, over(reporter_region, sort(EMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (unweighted) exposure score") stack

//By income group
graph bar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin, over(ReporterIncomeGroup, sort(EMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by jurisdiction
graph bar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Africa", over(reporter, sort(EMin) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by subregion
graph bar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Africa", over(reporter_subregion, sort(EMin) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (unweighted) exposure score") stack


	**** 3.3. Assuming partner countries only the Secrecy Jurisdictions
//By region
graph bar (mean) EISJ (mean) EESJ (mean) EDIISJ (mean) EDIOSJ (mean) EPIASJ (mean) EPILSJ, over(reporter_region, sort(EMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//By income group
graph bar (mean) EISJ (mean) EESJ (mean) EDIISJ (mean) EDIOSJ (mean) EPIASJ (mean) EPILSJ, over(ReporterIncomeGroup, sort(EMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by jurisdiction
graph bar (mean) EISJ (mean) EESJ (mean) EDIISJ (mean) EDIOSJ (mean) EPIASJ (mean) EPILSJ if reporter_region == "Africa", over(reporter, sort(EMin) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean (unweighted) exposure score") stack

//For Africa, by subregion
graph bar (mean) EISJ (mean) EESJ (mean) EDIISJ (mean) EDIOSJ (mean) EPIASJ (mean) EPILSJ if reporter_region == "Africa", over(reporter_subregion, sort(EMin) label(angle(-45) labsize(tiny))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading only with Secrecy Jurisdictions") ytitle("Mean (unweighted) exposure score") stack




**** 4. Ranking countries' individual exposure scores to identify outliers - From reporter perspective

	**** 4.1. By region, all countries included, assuming partner countries without SS are at least as secretive as best performer on FSI
//Africa
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Africa", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("African Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack

//Asia
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Asia", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) graphregion(margin(25 2 2 2)) ///
title("Asian Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack

//Europe
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Europe", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("European Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack

//Latin America and the Caribbean
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Latin America and the Caribbean", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Latin American and Caribbean Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack

//Northern American
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Northern America", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Northern American Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack

//Oceania
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Oceania", ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Oceanian Exposure by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score", size(vsmall)) stack



	**** 4.2. By region, excludes countries where Partner Secrecy Score is > Q3, assuming partner countries without SS are at least as secretive as best performer on FSI
//Africa
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Africa" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("African Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack

//Asia
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Asia" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Asian Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack

//Europe
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Europe" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("European Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack

//Latin America and the Caribbean
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Latin America and the Caribbean" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Latin American and Caribbean Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack

//Northern America
graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Northern America" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Northern American Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack

//Oceania -- NO OBSERVATIONS
/* graph hbar (mean) EIMin (mean) EEMin (mean) EDIIMin (mean) EDIOMin (mean) EPIAMin (mean) EPILMin if reporter_region == "Oceanian" & EMin < Q3EMin, ///
over(reporter, sort(EMin) descending label(angle(0) labsize(tiny)) ) ylabel(,labsize(tiny)) ///
legend(off) ///
title("Oceanian Exposure, by reporters", size(medium)) subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive", size(small)) ytitle("Mean (unweighted) exposure score in Q1-Q3", size(vsmall)) stack
*/




**** 5. Specialisation of GDP with secretive partners
	
	**** 5.1. All countries - Q5 (most secretive countries) group has no obs
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 1, over(reporter_region, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Least secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(Q1, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 2, over(reporter_region, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(Q2, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 3, over(reporter_region, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Moderately secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(Q3, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 4, over(reporter_region, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Very secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(Q4, replace)
//graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 5, over(reporter_region, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Most secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(Q5, replace)
graph combine Q1.gph Q2.gph Q3.gph Q4.gph, title("Specialisation of GDP in secrecy") subtitle("Ratio of flows/stocks to GDP, by secrecy of partner")



	**** 5.2.  For Africa - Q5 (most secretive countries) group has no obs
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 1 & reporter_region == "Africa" & I != 0 & !missing(I), over(reporter, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Least secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(AfrQ1, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 2 & reporter_region == "Africa" & I != 0 & !missing(I), over(reporter, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(AfrQ2, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 3 & reporter_region == "Africa" & I != 0 & !missing(I), over(reporter, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Moderately secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(AfrQ3, replace)
graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 4 & reporter_region == "Africa" & I !=0 & !missing(I), over(reporter, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Very secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(AfrQ4, replace)
//graph hbar (mean) II (mean) IE (mean) IDII (mean) IDIO (mean) IPIA (mean) IPIL if Q == 5 & reporter_region == "Africa" & I != 0, over(reporter, sort(I) label(angle(0) labsize(vsmall)) ) ytitle("Most secretive", size(small)) ylabel(,labsize(vsmall)) legend(off) stack saving(AfrQ5, replace)
graph combine AfrQ1.gph AfrQ2.gph AfrQ3.gph AfrQ4.gph, title("Specialisation of GDP in secrecy in Africa") subtitle("Ratio of flows/stocks to GDP, by secrecy of partner")





**** 6. Weighted exposures (all countries within a region or income group have the same Exposure scores)

	**** 6.1. Weighted Regional Exposures
// Stacked
graph bar (mean) wEIMin (mean) wEEMin (mean) wEDIIMin (mean) wEDIOMin (mean) wEPIAMin (mean) wEPILMin if reporter_region != "", over(reporter_region, sort(wEMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (weighted) exposure score") stack

//Overall, unstacked
graph bar (mean) wEMin if reporter_region != "", over(reporter_region, sort(wEMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (weighted) exposure score") 
	
	
	
	**** 6.2. Weighted Income Group Exposures
// Stacked
graph bar (mean) wiEIMin (mean) wiEEMin (mean) wiEDIIMin (mean) wiEDIOMin (mean) wiEPIAMin (mean) wiEPILMin if reporter_region != "", over(ReporterIncomeGroup, sort(wiEMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
legend(size(small) label(1 "Imports") label(2 "Exports") label(3 "Inward Direct Investment") label(4 "Outward Direct Investment") label(5 "Portfolio Investment Assets") label(6 "Portfolio Investment Liabilities")) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (weighted) exposure score") stack

//Overall, unstacked
graph bar (mean) wiEMin if reporter_region != "", over(ReporterIncomeGroup, sort(wiEMin) label(angle(-45) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
title("Overall Exposure by reporters") subtitle("Trading with all jurisdictions, assuming all are at least minimally secretive") ytitle("Mean (weighted) exposure score") 




save "$results/FullPanel.dta", replace




/*
**** 13. Import human trafficking
clear
import excel "$data\GlobalSlaveryIndex_2013_Data_FINAL.xlsx", sheet("Prevalence") cellrange("A5:N167") firstrow
keep CountryName TraffOUT TraffIN INOUT
mmerge country using "$data\codes_masterlist.dta", unmatched(master) ukeep(ISO3166)


/**** FOOTNOTES.
#1. The IMF had two country names: "Timor" and "Timor-Leste, Dem. Rep. of". Both had some non-zero values and weren't immediate duplicates, so I couldn't
drop them off the bat. The IMF code for Timor-Leste is 537, and this squares with the recognised ISO-3166 code which is TLS. However, the IMF code they
had for Timor (579) squares with nothing, its ISO-3166 was empty, and they didn't add any meta-data. So we are renaming Timor to Timor-Leste. We will then
have to consolidate the two countries' values together (i.e. merge but not double-count in the case of duplicates).
#2. We have checked if there are any duplicates with the actual values. They all refer to Timor-Leste (which includes Timor-Leste from the raw data and the
previously replaced Timor), and to cases where the value is 0. I have checked that these are OK to drop. This happens twice, when we consolidate reporter
and then partner names.
#3. This again refers to the Timor/Timor-Leste problem. There are 30 occurences (15 where TLS is a reporter and 15 where TLS is a partner), where the value
is 0 but the ID (reporter/partner/year/indicator) is a duplicate. We make sure to drop the 30 ID duplicates where the value is 0 (there are 30 duplicate IDs
where the value is non-0).
