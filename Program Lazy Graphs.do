capture program drop lazy

program define lazy

	args weight measure flowstock conduit group directory

	if ("`weight'" == "wincome") {
	local w "wi"
	local wlab = "weighted"
	local ov = "ReporterIncomeGroup"
	local cd ""
	local gr ""
	}

	else if ("`weight'" == "wregion") {
	local w "w"
	local wlab "weighted"
	local ov = "reporter_region"
	local cd ""
	local gr ""
	}

	else if ("`weight'" == "noweight") {
	local w ""
	local wlab "unweighted"
	local ov = "reporter"
	local gr "`group'"
	}

	
		if ("`measure'" == "v") {
		local m "V"
		local mlab = "vulnerability"
		local ylab "Vulnerability score (`wlab')"
		}
		else if ("`measure'" == "i") {
		local m "I"
		local mlab "intensity"
		local ylab "Share of GDP (`wlab')"
		}
		else if ("`measure'" == "e") {
		local m "E"
		local mlab "exposure"
		local ylab "Exposure score (`wlab')"
		}

			if	("`flowstock'" == "Trade") {
			local var "IMin EMin"
			local leglab "Imports Exports"
			local vlab "Trade"
			local colour "navy maroon"
			}
			else if ("`flowstock'" == "DirectInv") {
			local var "DIdIMin DIdOMin"
			local leglab `" `"Inward Direct Investment (derived)"' `"Outward Direct Investment (derived) "' "'
			local vlab "Direct investment"
			local colour "forest_green dkorange"
			}
			else if ("`flowstock'" == "PortInv") {
			local var "PIdAMin PIdLMin"
			local vlab "Portfolio investment"
			local leglab `" `"Assets Portfolio Investment (derived)"' `"Liabilities Portfolio Investment (derived)   "' "'
			local colour "teal cranberry"
			}
			else if ("`flowstock'" == "BC") {
			local var "BCMin BCMin"
			local vlab "Banking"
			local leglab "blah"
			local colour "gold"
			}

	
	tokenize `var'
	local v1  `"`1'"'
	local v2  `"`2'"'
	tokenize `colour'
	local c1  `"`1'"'
	local c2  `"`2'"'
	tokenize `"`leglab'"'
	local leg1  `"`1'"'
	local leg2  `"`2'"'
	
				if	("`conduit'" == "conduits" & "`weight'" == "noweight") {
				local cd "if `flowstock'Conduit$cut == 1"
				local cdw ""
				local cdlab "Conduits (percentile $cut)"
				}
				
				else if ("`conduit'" == "noconduits" & "`weight'" == "noweight") {
				local cd "if `flowstock'Conduit$cut != 1 & !missing(`m'`v1') & !missing(`m'`v2')"
				local cdw ""
				local cdlab "Excluding conduits (percentile $cut)"
				}
								
				else if ("`conduit'" == "conduits" & "`weight'" != "noweight") {
				local cd ""
				local cdw ""
				local cdlab "Including conduits (percentile $cut)"
				}
				
				else if ("`conduit'" == "noconduits" & "`weight'" != "noweight") {
				local cd ""
				local cdw "no"
				local cdlab "Excluding conduits (percentile $cut)"
				}

	if ("`gr'" == "" ) {
	graph hbar (mean) `w'`m'`v1'`cdw' (mean) `w'`m'`v2'`cdw' `cd', over(`ov', sort(`w'`m'`flowstock'Min`cdw') descending label(angle(0) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
	legend(size(vsmall) label(1 `"`leg1'"') label(2 `"`leg2'"') ) ///
	bar(1, fcolor(`c1') lcolor(`c1')) bar(2, fcolor(`c2') lcolor(`c2')) stack ///
	title("`vlab' `mlab'", size(medium)) subtitle(`cdlab', size(small)) ytitle(`ylab', size(vsmall))
	//graph save "`weight'_`m'_`flowstock'.gph", replace
	graph export "`weight'_`m'_`flowstock'_$cut.png", as(png) replace
	//erase "`weight'_`m'_`flowstock'.gph"

	}

	else if ("`gr'" != "" ) {
		if ("`gr'" == "inc") {
			local by "ReporterIncomeGroup"
			local gr "1 2 3 4 5"
			local grlab `" `"Low income"' `"Lower middle income"' `"Upper middle income"' `"High income non OECD"' `"High income OECD"' "'
			//local n = wordcount("`grlab'")
			tokenize `"`grlab'"', parse (" ")
				local g1  `"`1'"'
				local g2  `"`2'"'
				local g3  `"`3'"'
				local g4  `"`4'"'
				local g5  `"`5'"'
			}
		else if ("`gr'" == "reg") {
			local by "reporter_region"
			local gr "1 2 3 4 5 6"
			local grlab `" Africa Asia Europe `"Latin America and the Caribbean"' `"Northern America"' Oceania "'
			tokenize `"`grlab'"', parse (" ")
				local g1  `"`1'"'
				local g2  `"`2'"'
				local g3  `"`3'"'
				local g4  `"`4'"'
				local g5  `"`5'"'
				local g6  `"`6'"'
			}
			
		local n = wordcount("`gr'")
		forv i=1/`n' {
			capture {
			graph hbar (mean) `w'`m'`v1'`cdw' (mean) `w'`m'`v2'`cdw' `cd' & `by' == `i', over(`ov', sort(`w'`m'`flowstock'Min) descending label(angle(0) labsize(vsmall))) ylabel(,labsize(vsmall)) ///
			legend(size(vsmall) label(1 `"`leg1'"') label(2 `"`leg2'"') ) ///
			bar(1, fcolor(`c1') lcolor(`c1')) bar(2, fcolor(`c2') lcolor(`c2')) stack ///
			title("`vlab' `mlab'", size(medium)) subtitle(`" `g`i'', `cdlab' "', size(small)) ytitle("Mean (`wlab') `mlab' score", size(vsmall))
			//graph save "`weight'_`m'_`flowstock'_`group'_`i'.gph", replace
			graph export "`weight'_`m'_`flowstock'_`group'_`i'_$cut.png", as(png) replace
			//erase "`weight'_`m'_`flowstock'_`group'_`i'.gph"
					}
			}
}


end


