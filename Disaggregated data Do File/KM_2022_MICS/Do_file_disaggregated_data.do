/*==============================================================================
Données désagrégées : Enquête MICS 2022 
==============================================================================*/
clear all
set more off
set varabbrev off
version 17

*=== 0. CHEMINS =============================================================
global root   "C:\Users\bmd\Desktop\COURS MASTER ADEPP\Travaux mémoire"
global data   "$root\KM_2022_MICS"
global output "$root\Output"
global tables "$output\Tables"
global temp   "$output\Temp"

qui cap noisily shell mkdir "$root"
qui cap noisily shell mkdir "$output"
qui cap noisily shell mkdir "$tables"
qui cap noisily shell mkdir "$temp"
qui cap cd "$data"
if _rc {
    di as error "Dossier de données introuvable : $data"
    exit 601
}
cd "$root"
cap log close
log using "$output\log_Tableaux_Comores.log", replace text
cap which estout
if _rc ssc install estout, replace

*=== 1. CALENDRIER DES DIRIGEANTS (1976-2022, île au pouvoir) ===============
* 1=Mwali 2=Ndzuwani 3=Ngazidja
* dirigeant : 1=Soilih 2=Abdallah 3=Djohar 4=Taki 5=Azali(putsch) 6=Azali(1er
*             mandat) 7=Sambi 8=Ikililou 9=Azali(2e mandat)
preserve
    clear
    set obs 49
    gen annee = 1974 + _n
    gen ile_pouvoir = .
    gen dirigeant = .
    replace ile_pouvoir = 3 if inrange(annee,1976,1977)
    replace dirigeant   = 1 if inrange(annee,1976,1977)
    replace ile_pouvoir = 2 if inrange(annee,1978,1989)
    replace dirigeant   = 2 if inrange(annee,1978,1989)
    replace ile_pouvoir = 3 if inrange(annee,1990,1995)
    replace dirigeant   = 3 if inrange(annee,1990,1995)
    replace ile_pouvoir = 3 if inrange(annee,1996,1998)
    replace dirigeant   = 4 if inrange(annee,1996,1998)
    replace ile_pouvoir = 3 if inrange(annee,1999,2001)
    replace dirigeant   = 5 if inrange(annee,1999,2001)
    replace ile_pouvoir = 3 if inrange(annee,2002,2005)
    replace dirigeant   = 6 if inrange(annee,2002,2005)
    replace ile_pouvoir = 2 if inrange(annee,2006,2010)
    replace dirigeant   = 7 if inrange(annee,2006,2010)
    replace ile_pouvoir = 1 if inrange(annee,2011,2015)
    replace dirigeant   = 8 if inrange(annee,2011,2015)
    replace ile_pouvoir = 3 if inrange(annee,2016,2022)
    replace dirigeant   = 9 if inrange(annee,2016,2022)
    save "$temp\calendrier_dirigeants.dta", replace
restore
label define ileL 1 "Mwali" 2 "Ndzuwani" 3 "Ngazidja"
label define dirL 1 "Soilih" 2 "Abdallah" 3 "Djohar" 4 "Taki" 5 "Azali (putsch)" ///
    6 "Azali (1er mandat)" 7 "Sambi" 8 "Ikililou" 9 "Azali (2e mandat)"

*=== 2. PROGRAMMES DE CONSTRUCTION DE CoIL ==================================
capture program drop build_coil
program define build_coil
    args idvar byvar ilevar
    tempfile base coil_result
    preserve
        keep `idvar' `byvar' `ilevar'
        drop if missing(`byvar') | missing(`ilevar')
        save `base', replace
    restore
    preserve
        use `base', clear
        expand 6
        bys `idvar': gen _offset = 5 + _n
        gen annee = `byvar' + _offset
        merge m:1 annee using "$temp\calendrier_dirigeants.dta", keep(master match) nogenerate
        gen _co = (ile_pouvoir == `ilevar') if !missing(ile_pouvoir)
        replace _co = 0 if missing(_co)
        collapse (sum) CoIL_nb=_co, by(`idvar')
        gen CoIL     = CoIL_nb/6
        gen CoIL_bin = (CoIL > 0.5) if !missing(CoIL)
        keep `idvar' CoIL CoIL_bin
        save `coil_result', replace
    restore
    merge m:1 `idvar' using `coil_result', nogenerate
end
 
capture program drop build_coil_window
program define build_coil_window
    args idvar byvar ilevar agestart ageend outname
    local nyears = `ageend' - `agestart' + 1
    tempfile base coil_result
    preserve
        keep `idvar' `byvar' `ilevar'
        drop if missing(`byvar') | missing(`ilevar')
        save `base', replace
    restore
    preserve
        use `base', clear
        expand `nyears'
        bys `idvar': gen _offset = `agestart' - 1 + _n
        gen annee = `byvar' + _offset
        merge m:1 annee using "$temp\calendrier_dirigeants.dta", keep(master match) nogenerate
        gen _co = (ile_pouvoir == `ilevar') if !missing(ile_pouvoir)
        * Nombre d'années effectivement couvertes par le calendrier, par individu.
        bys `idvar': egen _nvalid = count(_co)
        collapse (sum) `outname'_nb=_co (mean) _nvalid, by(`idvar')
        gen `outname' = `outname'_nb/`nyears' if _nvalid == `nyears'
        keep `idvar' `outname'
        save `coil_result', replace
    restore
    merge m:1 `idvar' using `coil_result', nogenerate
end

capture program drop build_coil_contemp
program define build_coil_contemp
    args idvar byvar ilevar outname
    tempfile base coil_result
    preserve
        keep `idvar' `byvar' `ilevar'
        drop if missing(`byvar') | missing(`ilevar')
        rename `byvar' annee
        merge m:1 annee using "$temp\calendrier_dirigeants.dta", keep(master match) nogenerate
        gen `outname' = (ile_pouvoir == `ilevar') if !missing(ile_pouvoir)
        keep `idvar' `outname'
        save `coil_result', replace
    restore
    merge m:1 `idvar' using `coil_result', nogenerate
end

capture program drop build_mandat_dominant
program define build_mandat_dominant
    args idvar byvar
    tempfile base result
    preserve
        keep `idvar' `byvar'
        drop if missing(`byvar')
        save `base', replace
    restore
    preserve
        use `base', clear
        expand 6
        bys `idvar': gen _offset = 5 + _n
        gen annee = `byvar' + _offset
        merge m:1 annee using "$temp\calendrier_dirigeants.dta", keep(master match) nogenerate
        forvalues k = 1/9 {
            gen _c`k' = (dirigeant==`k')
        }
        collapse (sum) _c1-_c9, by(`idvar')
        egen _maxc = rowmax(_c1-_c9)
        gen mandat_dominant = .
        forvalues k = 1/9 {
            replace mandat_dominant = `k' if _c`k'==_maxc & _c`k'>0 & missing(mandat_dominant)
        }
        keep `idvar' mandat_dominant
        save `result', replace
    restore
    merge m:1 `idvar' using `result', nogenerate
end

* starfmt : formate "coefficient***[erreur-type]" (sert au Tableau 7)
capture program drop starfmt
program define starfmt, rclass
    args b se df
    local pval = 2*ttail(`df', abs(`b'/`se'))
    local stars ""
    if `pval'<0.01 local stars "***"
    else if `pval'<0.05 local stars "**"
    else if `pval'<0.10 local stars "*"
    local bstr : display %6.4f `b'
    local sestr : display %6.4f `se'
    return local out = trim("`bstr'") + "`stars'" + " [" + trim("`sestr'") + "]"
end

*=== 3. CONSTRUCTION DES 4 ÉCHANTILLONS =====================================

* --- (a) Éducation - Principal ---
use "$data\mics2022_hh_members_listing.dta", clear
gen long id_obs = _n
gen annee_naiss = HL5Y
replace annee_naiss = . if inlist(annee_naiss,9999,9998)
gen age = HL6
gen fem = (HL4==2) if !missing(HL4)
gen urbain = (HH6==1) if !missing(HH6)
* Éducation primaire partielle = 1 si scolarisé et niveau atteint >= primaire (primaire,
* secondaire 1/2, supérieur) ; = 0 si jamais scolarisé OU si seul le préprimaire a été
* fréquenté (ED5A==0). Le préprimaire n'est pas le primaire : il doit être codé 0, pas
* manquant. Logique confirmée avec l'encadreur, cohérente avec completed_primary
* ci-dessous, qui traite déjà ED5A==0 comme 0.
gen some_primary = .
replace some_primary = 0 if ED4==2
replace some_primary = 0 if ED4==1 & ED5A==0
replace some_primary = 1 if ED4==1 & inrange(ED5A,1,4)
gen completed_primary = .
replace completed_primary = 0 if ED4==2 | (ED4==1 & ED5A==0) | (ED4==1 & ED5A==1 & !(ED5B==6 & ED6==1))
replace completed_primary = 1 if (ED4==1 & inrange(ED5A,2,4)) | (ED4==1 & ED5A==1 & ED5B==6 & ED6==1)
keep if inrange(age,6,77) & !missing(annee_naiss)
build_coil id_obs annee_naiss HH7
gen male = 1 - fem
label values HH7 ileL

drop if missing(some_primary, completed_primary, CoIL, urbain, male)
save "$temp\sample_main.dta", replace

* --- (b) Éducation - Femmes ---
use "$data\mics2022_women.dta", clear
gen long id_obs = _n
gen annee_naiss = WB3Y
replace annee_naiss = . if inlist(annee_naiss,9999,9998)
gen age = WB4
gen urbain = (HH6==1) if !missing(HH6)
gen litteratie = .
* WB14 (test de lecture) n'est PAS administre aux femmes ayant atteint le
* secondaire ou plus (WB6A>=2) : schema de "skip" standard MICS, ces
* personnes sont PRESUMEES lettrees, ce ne sont PAS des valeurs manquantes.
* (Verifie sur les donnees : WB14 est manquant pour 100% des WB6A>=2 et
*  renseigne pour 100% des WB6A<=1 -- un vrai skip pattern, pas du hasard.)
replace litteratie = 1 if inrange(WB6A,2,4)
replace litteratie = 0 if WB14==1
replace litteratie = 0 if WB14==2
replace litteratie = 1 if WB14==3
* WB14==4 (pas de phrase dans la langue requise/braille) et WB14==9 (non
* reponse) restent non renseignes (litteratie manquante).
gen some_primary = .
replace some_primary = 0 if WB5==2
replace some_primary = 0 if WB5==1 & WB6A==0
replace some_primary = 1 if WB5==1 & inrange(WB6A,1,4)
gen completed_primary = .
replace completed_primary = 0 if WB5==2 | (WB5==1 & WB6A==0) | (WB5==1 & WB6A==1 & !(WB6B==6 & WB7==1))
replace completed_primary = 1 if (WB5==1 & inrange(WB6A,2,4)) | (WB5==1 & WB6A==1 & WB6B==6 & WB7==1)
keep if !missing(annee_naiss)
build_coil id_obs annee_naiss HH7
label values HH7 ileL

* --- Échantillon d'estimation constant : mêmes N sur toutes les variables -----
* litteratie (WB14==4/9 non couverts), some_primary et completed_primary (WB6A
* NSP/non réponse, WB6B/WB7 non renseignés) laissent un résidu de valeurs
* manquantes. On aligne l'échantillon sur les variables du Tableau A2 et des
* régressions, pour un N constant entre toutes les colonnes.
drop if missing(litteratie, some_primary, completed_primary, CoIL, urbain)
save "$temp\sample_women.dta", replace

* --- (c) Éducation - Hommes ---
use "$data\mics2022_men.dta", clear
gen long id_obs = _n
gen annee_naiss = MWB3Y
replace annee_naiss = . if inlist(annee_naiss,9999,9998)
gen age = MWB4
gen urbain = (HH6==1) if !missing(HH6)
gen litteratie = .
* Meme correctif que pour les femmes : MWB14 non administre aux hommes
* ayant atteint le secondaire ou plus (MWB6A>=2) -- presumes lettres.
replace litteratie = 1 if inrange(MWB6A,2,4)
replace litteratie = 0 if MWB14==1
replace litteratie = 0 if MWB14==2
replace litteratie = 1 if MWB14==3
gen some_primary = .
replace some_primary = 0 if MWB5==2
replace some_primary = 0 if MWB5==1 & MWB6A==0
replace some_primary = 1 if MWB5==1 & inrange(MWB6A,1,4)
gen completed_primary = .
replace completed_primary = 0 if MWB5==2 | (MWB5==1 & MWB6A==0) | (MWB5==1 & MWB6A==1 & !(MWB6B==6 & MWB7==1))
replace completed_primary = 1 if (MWB5==1 & inrange(MWB6A,2,4)) | (MWB5==1 & MWB6A==1 & MWB6B==6 & MWB7==1)
keep if !missing(annee_naiss)
build_coil id_obs annee_naiss HH7
label values HH7 ileL

* --- Échantillon d'estimation constant : mêmes N sur toutes les variables -----
drop if missing(litteratie, some_primary, completed_primary, CoIL, urbain)
save "$temp\sample_men.dta", replace

* --- (d) Mortalité infantile (avec éducation de la mère fusionnée) ---
preserve
    use "$data\mics2022_women.dta", clear
    gen meduc_completed_primary = .
    replace meduc_completed_primary = 0 if WB5==2 | (WB5==1 & WB6A==0) | (WB5==1 & WB6A==1 & !(WB6B==6 & WB7==1))
    replace meduc_completed_primary = 1 if (WB5==1 & inrange(WB6A,2,4)) | (WB5==1 & WB6A==1 & WB6B==6 & WB7==1)
    keep HH1 HH2 LN meduc_completed_primary
    save "$temp\women_educ_for_merge.dta", replace
restore

use "$data\mics2020_birth_history.dta", clear
gen long id_obs = _n
gen annee_naiss_mere = 1900 + floor((WDOB-1)/12)
gen annee_naiss_enf  = BH4Y
gen annee_enquete    = 1900 + floor((WDOI-1)/12)
merge m:1 HH1 HH2 LN using "$temp\women_educ_for_merge.dta", keep(master match) nogenerate

gen deces = (BH5==2)
gen age_deces_mois = .
replace age_deces_mois = BH9N     if BH9U==2
replace age_deces_mois = BH9N/30  if BH9U==1
replace age_deces_mois = BH9N*12  if BH9U==3
gen infant_death = .
replace infant_death = 0 if deces==0
replace infant_death = 1 if deces==1 & age_deces_mois<12
replace infant_death = 0 if deces==1 & age_deces_mois>=12 & !missing(age_deces_mois)
keep if annee_naiss_enf <= annee_enquete - 1 & !missing(infant_death)

gen fille   = (BH3==2) if !missing(BH3)
gen jumeaux = (BH2==2) if !missing(BH2)
gen urbain  = (HH6==1) if !missing(HH6)
gen mage_birth = annee_naiss_enf - annee_naiss_mere
gen mage_birth2 = mage_birth^2
gen brthord2 = brthord^2
* birthint : 0=1ère naissance, 1=<2 ans, 2=2 ans, 3=3 ans, 4=4 ans+
gen shortspacing = (birthint==1)

keep if !missing(annee_naiss_mere)

build_coil_contemp id_obs annee_naiss_enf HH7 CoIL
label var CoIL "Dirigeant co-insulaire (Franck et Rainer 2012 : année de naissance de l'enfant)"
label values HH7 ileL

drop if missing(meduc_completed_primary)

save "$temp\sample_infantmort.dta", replace

use "$temp\sample_main.dta", clear
build_coil_window id_obs annee_naiss HH7 12 17 CoIL_fals12
build_coil_window id_obs annee_naiss HH7 18 24 CoIL_fals18
build_coil_window id_obs annee_naiss HH7 24 30 CoIL_fals24
save "$temp\sample_main_fals.dta", replace

use "$temp\sample_women.dta", clear
build_coil_window id_obs annee_naiss HH7 12 17 CoIL_fals12
build_coil_window id_obs annee_naiss HH7 18 24 CoIL_fals18
build_coil_window id_obs annee_naiss HH7 24 30 CoIL_fals24
save "$temp\sample_women_fals.dta", replace

use "$temp\sample_men.dta", clear
build_coil_window id_obs annee_naiss HH7 12 17 CoIL_fals12
build_coil_window id_obs annee_naiss HH7 18 24 CoIL_fals18
build_coil_window id_obs annee_naiss HH7 24 30 CoIL_fals24
save "$temp\sample_men_fals.dta", replace

use "$temp\sample_infantmort.dta", clear
gen annee_naiss_enf_p2 = annee_naiss_enf + 2
build_coil_contemp id_obs annee_naiss_enf_p2 HH7 CoIL_fals12
drop annee_naiss_enf_p2
gen annee_naiss_enf_p4 = annee_naiss_enf + 4
build_coil_contemp id_obs annee_naiss_enf_p4 HH7 CoIL_fals18
drop annee_naiss_enf_p4
gen annee_naiss_enf_p6 = annee_naiss_enf + 6
build_coil_contemp id_obs annee_naiss_enf_p6 HH7 CoIL_fals24
drop annee_naiss_enf_p6
save "$temp\sample_infantmort_fals.dta", replace

use "$temp\sample_women_fals.dta", clear
gen male = 0
tempfile women_fals_tmp
save `women_fals_tmp'
use "$temp\sample_men_fals.dta", clear
gen male = 1
append using `women_fals_tmp'
drop id_obs
gen long id_obs = _n
save "$temp\sample_litt_pooled_fals.dta", replace

use "$temp\sample_women.dta", clear
gen male = 0
tempfile women_tmp
save `women_tmp'
use "$temp\sample_men.dta", clear
gen male = 1
append using `women_tmp'
drop id_obs
gen long id_obs = _n

gen educ_lvl = WB6A if male==0
replace educ_lvl = MWB6A if male==1
save "$temp\sample_litt_pooled.dta", replace

*=== 4. TABLEAU 1 : STATISTIQUES DESCRIPTIVES - DONNÉES DÉSAGRÉGÉES ========
local scells "count(fmt(%9.0fc)) mean(fmt(%9.4f)) sd(fmt(%9.3f)) min(fmt(%9.0f)) max(fmt(%9.0f))"
local slabs  `" "Obs" "Moyenne" "Écart-type" "Min" "Max" "'

use "$temp\sample_main.dta", clear
label var some_primary "Éducation primaire partielle"
label var completed_primary "Éducation primaire complète"
label var CoIL "Dirigeant co-insulaire (CoIL)"
label var urbain "Milieu urbain"
label var male "Homme"
label var age "Âge"
label var annee_naiss "Année de naissance"
eststo clear
estpost summarize some_primary completed_primary CoIL urbain male age annee_naiss
esttab using "$tables\Table1.rtf", replace cells("`scells'") collabels(`slabs') ///
    noobs nomtitle nonumber label ///
    refcat(some_primary "{\b Variables dépendantes}" CoIL "{\b Variables indépendantes}" ///
           age "{\b Variables de contexte}", nolabel) ///
    title("{\b Échantillon : Éducation – Principal}")

use "$temp\sample_women.dta", clear
label var litteratie "Alphabétisation"
label var some_primary "Éducation primaire partielle"
label var completed_primary "Éducation primaire complète"
label var CoIL "Dirigeant co-insulaire (CoIL)"
label var urbain "Milieu urbain"
label var age "Âge"
label var annee_naiss "Année de naissance"
eststo clear
estpost summarize litteratie some_primary completed_primary CoIL urbain age annee_naiss
esttab using "$tables\Table1.rtf", append cells("`scells'") collabels(`slabs') ///
    noobs nomtitle nonumber label ///
    refcat(litteratie "{\b Variables dépendantes}" CoIL "{\b Variables indépendantes}" ///
           age "{\b Variables de contexte}", nolabel) ///
    title("{\b Échantillon : Éducation – Femmes}")

use "$temp\sample_men.dta", clear
label var litteratie "Alphabétisation"
label var some_primary "Éducation primaire partielle"
label var completed_primary "Éducation primaire complète"
label var CoIL "Dirigeant co-insulaire (CoIL)"
label var urbain "Milieu urbain"
label var age "Âge"
label var annee_naiss "Année de naissance"
eststo clear
estpost summarize litteratie some_primary completed_primary CoIL urbain age annee_naiss
esttab using "$tables\Table1.rtf", append cells("`scells'") collabels(`slabs') ///
    noobs nomtitle nonumber label ///
    refcat(litteratie "{\b Variables dépendantes}" CoIL "{\b Variables indépendantes}" ///
           age "{\b Variables de contexte}", nolabel) ///
    title("{\b Échantillon : Éducation – Hommes}")

use "$temp\sample_infantmort.dta", clear
label var infant_death "Décès infantile"
label var CoIL "Dirigeant co-insulaire (CoIL)"
label var urbain "Milieu urbain"
label var meduc_completed_primary "Éducation de la mère (primaire complet)"
label var fille "Fille"
label var jumeaux "Naissance multiple"
label var mage_birth "Âge de la mère à la naissance"
label var brthord "Rang de naissance"
label var shortspacing "Espacement court des naissances"
label var annee_naiss_enf "Année de naissance"
eststo clear
estpost summarize infant_death CoIL urbain meduc_completed_primary fille jumeaux mage_birth brthord shortspacing annee_naiss_enf
esttab using "$tables\Table1.rtf", append cells("`scells'") collabels(`slabs') ///
    noobs nomtitle nonumber label ///
    refcat(infant_death "{\b Variable dépendante}" CoIL "{\b Variables indépendantes}" ///
           fille "{\b Variables de contexte}", nolabel) ///
    title("{\b Échantillon : Mortalité infantile}")

*=== 5. TABLEAU 2 : FAVORITISME INSULAIRE - ÉDUCATION, ALPHABÉTISATION, MORTALITÉ
* FE Année de naissance + FE Île + tendance île ; erreurs-types clusterisées (HH1)
eststo clear
use "$temp\sample_main.dta", clear
eststo T1_1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T1_2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

use "$temp\sample_litt_pooled.dta", clear
eststo T1_3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

use "$temp\sample_infantmort.dta", clear
* Contrôle ajouté : éducation de la mère (primaire complet), déjà fusionnée dans
* l'échantillon (section construction) et désormais non manquante pour toutes les
* observations retenues (voir la restriction à échantillon constant plus haut).
eststo T1_4: reg infant_death CoIL urbain meduc_completed_primary fille jumeaux mage_birth mage_birth2 ///
    brthord brthord2 shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab T1_1 T1_2 T1_3 T1_4 using "$tables\Table2.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL urbain male fille meduc_completed_primary) order(CoIL urbain male fille meduc_completed_primary) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)" urbain "Milieu urbain" male "Homme" fille "Fille" ///
              meduc_completed_primary "Éducation de la mère (primaire complet)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 2 : Favoritisme insulaire dans l'éducation primaire, l'alphabétisation et la mortalité infantile") ///
    addnotes("FE Année de naissance, FE Île, tendance par île. Erreurs-types groupées par cluster HH1." ///
             "Alphabétisation : femmes et hommes réunis (contrôle Homme inclus).")

*=== 6. TABLEAU 3 : ALPHABÉTISATION ET ÉDUCATION PAR SEXE ===================
eststo clear
use "$temp\sample_women.dta", clear
eststo T2_1: reg litteratie CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T2_3: reg some_primary CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T2_5: reg completed_primary CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

use "$temp\sample_men.dta", clear
eststo T2_2: reg litteratie CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T2_4: reg some_primary CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T2_6: reg completed_primary CoIL urbain i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

esttab T2_1 T2_2 T2_3 T2_4 T2_5 T2_6 using "$tables\Table3.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL urbain) order(CoIL urbain) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)" urbain "Milieu urbain") ///
    mgroups("Alphabétisation" "Éducation partielle" "Éducation complète", pattern(1 0 1 0 1 0)) ///
    mtitles("Femmes" "Hommes" "Femmes" "Hommes" "Femmes" "Hommes") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 3 : Favoritisme insulaire dans l'alphabétisation et l'éducation, par sexe — Comores") ///
    addnotes("FE Année de naissance, FE Île, tendance par île. Erreurs-types groupées par cluster HH1.")

*=== 8. TABLEAU 4 : ÎLE PAR ÎLE PAR INTERACTION ======
eststo clear

use "$temp\sample_main.dta", clear
eststo TI_1: reg some_primary ibn.HH7 c.CoIL#ibn.HH7 urbain male i.annee_naiss c.annee_naiss#i.HH7, vce(cluster HH1)
eststo TI_2: reg completed_primary ibn.HH7 c.CoIL#ibn.HH7 urbain male i.annee_naiss c.annee_naiss#i.HH7, vce(cluster HH1)

use "$temp\sample_litt_pooled.dta", clear
eststo TI_3: reg litteratie ibn.HH7 c.CoIL#ibn.HH7 urbain male i.annee_naiss c.annee_naiss#i.HH7, vce(cluster HH1)

use "$temp\sample_infantmort.dta", clear
eststo TI_4: reg infant_death ibn.HH7 c.CoIL#ibn.HH7 urbain fille jumeaux mage_birth mage_birth2 ///
    brthord brthord2 shortspacing i.annee_naiss_enf c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab TI_1 TI_2 TI_3 TI_4 using "$tables\Table4.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.HH7#c.CoIL 2.HH7#c.CoIL 3.HH7#c.CoIL) ///
    varlabels(1.HH7#c.CoIL "CoIL × Mwali" 2.HH7#c.CoIL "CoIL × Ndzuwani" 3.HH7#c.CoIL "CoIL × Ngazidja") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 4 : Hétérogénéité insulaire par interaction 
	") ///
    addnotes("Spécification poolée (les 3 îles réunies dans la même régression, aucune restriction" ///
             "d'échantillon), CoIL interagi séparément avec chaque île (ibn.HH7 : pas de catégorie de" ///
             "référence). FE Île, FE Année de naissance, tendance par île. Alphabétisation : femmes et" ///
             "hommes réunis (contrôle Homme inclus). Erreurs-types groupées par cluster HH1." ///
             "Complète le Tableau 3 (régressions par sous-échantillon insulaire, tendance cubique).")

*=== 8. TABLEAU 4 (SUITE) : TESTS D'ÉGALITÉ DES COEFFICIENTS CoIL x ÎLE ==

foreach m in TI_1 TI_2 TI_3 TI_4 {
    estimates restore `m'

    * Test joint : les 3 coefficients sont-ils tous égaux entre eux ?
    qui test 1.HH7#c.CoIL = 2.HH7#c.CoIL = 3.HH7#c.CoIL
    estadd scalar F_joint = r(F)
    estadd scalar p_joint = r(p)

    * Tests par paire
    qui test 1.HH7#c.CoIL = 2.HH7#c.CoIL
    estadd scalar p_MwaliNdz = r(p)
    qui test 1.HH7#c.CoIL = 3.HH7#c.CoIL
    estadd scalar p_MwaliNga = r(p)
    qui test 2.HH7#c.CoIL = 3.HH7#c.CoIL
    estadd scalar p_NdzNga = r(p)

    estimates store `m'
}

esttab TI_1 TI_2 TI_3 TI_4 using "$tables\Table4.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.HH7#c.CoIL 2.HH7#c.CoIL 3.HH7#c.CoIL) ///
    varlabels(1.HH7#c.CoIL "CoIL × Mwali" 2.HH7#c.CoIL "CoIL × Ndzuwani" 3.HH7#c.CoIL "CoIL × Ngazidja") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(p_MwaliNdz p_MwaliNga p_NdzNga F_joint p_joint N r2, ///
        fmt(%9.3f %9.3f %9.3f %9.3f %9.3f %12.0fc %9.3f) ///
        labels("p (Mwali = Ndzuwani)" "p (Mwali = Ngazidja)" "p (Ndzuwani = Ngazidja)" ///
               "F (test joint, 3 coeff. égaux)" "p (test joint)" "Observations" "R²")) ///
    title("Tests d'égalité des coefficients CoIL x île (complète le Tableau 4)") ///
    addnotes("Tests de Wald post-estimation (commande test de Stata), utilisant la matrice de" ///
             "covariance exacte de chaque régression. H0 pour chaque paire : les deux coefficients" ///
             "indiqués sont égaux. H0 pour le test joint : les trois coefficients CoIL x île sont" ///
             "tous égaux entre eux (test F). Erreurs-types groupées par cluster HH1.")

*=== 9. TABLEAU 5 : HÉTÉROGÉNÉITÉ PAR MANDAT PRÉSIDENTIEL (UN SEUL TABLEAU, PAS DE
*        SOUS-ÉCHANTILLON, 4 VARIABLES DÉPENDANTES) ========================

eststo clear

* --- (1)-(2) Éducation : échantillon principal ---
use "$temp\sample_main.dta", clear
build_mandat_dominant id_obs annee_naiss
label values mandat_dominant dirL
eststo TM_1: reg some_primary ibn.mandat_dominant c.CoIL#ibn.mandat_dominant urbain male ///
    i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo TM_2: reg completed_primary ibn.mandat_dominant c.CoIL#ibn.mandat_dominant urbain male ///
    i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

* --- (3) Alphabétisation : échantillon poolé (femmes + hommes) ---
use "$temp\sample_litt_pooled.dta", clear
build_mandat_dominant id_obs annee_naiss
label values mandat_dominant dirL
eststo TM_3: reg litteratie ibn.mandat_dominant c.CoIL#ibn.mandat_dominant urbain male ///
    i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)

* --- (4) Décès infantile ---
use "$temp\sample_infantmort.dta", clear
build_mandat_dominant id_obs annee_naiss_mere
label values mandat_dominant dirL
eststo TM_4: reg infant_death ibn.mandat_dominant c.CoIL#ibn.mandat_dominant urbain fille jumeaux ///
    mage_birth mage_birth2 brthord brthord2 shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, ///
    vce(cluster HH1)

esttab TM_1 TM_2 TM_3 TM_4 using "$tables\Table5.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(2.mandat_dominant#c.CoIL 3.mandat_dominant#c.CoIL 4.mandat_dominant#c.CoIL ///
         5.mandat_dominant#c.CoIL 6.mandat_dominant#c.CoIL 7.mandat_dominant#c.CoIL ///
         8.mandat_dominant#c.CoIL 9.mandat_dominant#c.CoIL) ///
    order(2.mandat_dominant#c.CoIL 3.mandat_dominant#c.CoIL 4.mandat_dominant#c.CoIL ///
          5.mandat_dominant#c.CoIL 6.mandat_dominant#c.CoIL 7.mandat_dominant#c.CoIL ///
          8.mandat_dominant#c.CoIL 9.mandat_dominant#c.CoIL) ///
    varlabels(2.mandat_dominant#c.CoIL "CoIL × Abdallah" 3.mandat_dominant#c.CoIL "CoIL × Djohar" ///
              4.mandat_dominant#c.CoIL "CoIL × Taki" 5.mandat_dominant#c.CoIL "CoIL × Azali (putsch)" ///
              6.mandat_dominant#c.CoIL "CoIL × Azali (1er mandat)" 7.mandat_dominant#c.CoIL "CoIL × Sambi" ///
              8.mandat_dominant#c.CoIL "CoIL × Ikililou" 9.mandat_dominant#c.CoIL "CoIL × Azali (2e mandat)") ///
    refcat(2.mandat_dominant#c.CoIL "{\b Mandats pré-réforme (avant 2002)}" ///
           6.mandat_dominant#c.CoIL "{\b Mandats post-réforme (2002 et après)}", nolabel) ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 5 : Hétérogénéité insulaire par mandat présidentiel") ///
    addnotes("Régression poolée UNIQUE par variable dépendante (aucune restriction d'échantillon) ;" ///
             "CoIL interagi séparément avec chaque mandat (ibn. : pas de catégorie de référence)." ///
             "Alphabétisation : femmes et hommes réunis, avec contrôle Homme. « Mandat dominant » =" ///
             "dirigeant en exercice pendant la majorité de la fenêtre scolaire primaire (6-11 ans) de" ///
             "l'individu (de la mère pour la mortalité infantile). Erreurs-types groupées par cluster" ///
             "HH1. Le mandat de Soilih (1976-1977, 2 ans, plus court que la fenêtre de 6 ans) ne peut" ///
             "dominer la scolarité d'aucun individu et n'apparaît donc pas.")

*=== 10. TABLEAU 8 : TEST DE FALSIFICATION =================================
eststo clear
use "$temp\sample_main.dta", clear
eststo T5_o1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T5_o2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_litt_pooled.dta", clear
eststo T5_o3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_infantmort.dta", clear
eststo T5_o4: reg infant_death CoIL urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab T5_o1 T5_o2 T5_o3 T5_o4 using "$tables\Table8.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL) varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 8 : Favoritisme insulaire — test de falsification") ///
    mgroups("Régression originale (CoIL, 6-11 ans)", pattern(1 0 0 0))

eststo clear
use "$temp\sample_main_fals.dta", clear
eststo T5_f1: reg some_primary CoIL_fals12 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T5_f2: reg completed_primary CoIL_fals12 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_litt_pooled_fals.dta", clear
eststo T5_f3: reg litteratie CoIL_fals12 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_infantmort_fals.dta", clear
eststo T5_f4: reg infant_death CoIL_fals12 urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab T5_f1 T5_f2 T5_f3 T5_f4 using "$tables\Table8.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL_fals12) varlabels(CoIL_fals12 "CoIL (fenêtre placebo)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Falsification, 12-17 ans (décalage de 6 ans)", pattern(1 0 0 0))

eststo clear
use "$temp\sample_main_fals.dta", clear
eststo T5_g1: reg some_primary CoIL_fals18 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T5_g2: reg completed_primary CoIL_fals18 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_litt_pooled_fals.dta", clear
eststo T5_g3: reg litteratie CoIL_fals18 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_infantmort_fals.dta", clear
eststo T5_g4: reg infant_death CoIL_fals18 urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab T5_g1 T5_g2 T5_g3 T5_g4 using "$tables\Table8.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL_fals18) varlabels(CoIL_fals18 "CoIL (fenêtre placebo)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Falsification, 18-24 ans (décalage de 12 ans)", pattern(1 0 0 0))

eststo clear
use "$temp\sample_main_fals.dta", clear
eststo T5_h1: reg some_primary CoIL_fals24 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T5_h2: reg completed_primary CoIL_fals24 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_litt_pooled_fals.dta", clear
eststo T5_h3: reg litteratie CoIL_fals24 urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_infantmort_fals.dta", clear
eststo T5_h4: reg infant_death CoIL_fals24 urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)

esttab T5_h1 T5_h2 T5_h3 T5_h4 using "$tables\Table8.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL_fals24) varlabels(CoIL_fals24 "CoIL (fenêtre placebo)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Falsification, 24-30 ans (décalage de 18 ans)", pattern(1 0 0 0)) ///
    addnotes("Un coefficient non significatif conforte l'interprétation causale de l'effet original." ///
             "Chaque fenêtre exige une couverture complète par le calendrier des dirigeants" ///
             "(1976-2022) : les individus dont la fenêtre déborde après 2022 sont exclus de la" ///
             "régression correspondante (voir build_coil_window), d'où un N qui diminue à mesure" ///
             "que la fenêtre s'éloigne. Alphabétisation : échantillon poolé femmes + hommes, contrôle" ///
             "Homme inclus (comme au Tableau 1), non la littératie des seules femmes utilisée au" ///
             "Tableau 2. Colonne (4), mortalité infantile : les trois panneaux de falsification" ///
             "avancent CoIL de 2, 4 et 6 ans par rapport à la naissance de l'enfant, conformément" ///
             "à la construction contemporaine de CoIL pour cette variable (section 3.5) ; les" ///
             "fenêtres d'âge 12-17, 18-24 et 24-30 ne s'appliquent pas telles quelles à cette" ///
             "colonne. FE année de naissance, FE île, tendance par île. Erreurs-types groupées" ///
             "par cluster HH1. * p < 0.10, ** p < 0.05, *** p < 0.01.")

*=== 12. TABLEAU 6 : ROBUSTESSE - EFFETS DE SÉLECTION =======================

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_A1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
eststo T7_A2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_litt_pooled.dta", clear
eststo T7_A3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
use "$temp\sample_infantmort.dta", clear
eststo T7_A4: reg infant_death CoIL urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)
esttab T7_A1 T7_A2 T7_A3 T7_A4 using "$tables\Table6.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    title("Tableau 6 : Favoritisme insulaire — robustesse aux effets de sélection") ///
    mgroups("Échantillon principal", pattern(1 0 0 0))

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_B1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (ED5A!=4|missing(ED5A)), vce(cluster HH1)
eststo T7_B2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (ED5A!=4|missing(ED5A)), vce(cluster HH1)
use "$temp\sample_litt_pooled.dta", clear
eststo T7_B3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (educ_lvl!=4|missing(educ_lvl)), vce(cluster HH1)
esttab T7_B1 T7_B2 T7_B3 using "$tables\Table6.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Sans les répondants ayant un niveau supérieur", pattern(1 0 0))

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_C1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (ED5A<3|missing(ED5A)), vce(cluster HH1)
eststo T7_C2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (ED5A<3|missing(ED5A)), vce(cluster HH1)
use "$temp\sample_litt_pooled.dta", clear
eststo T7_C3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if (educ_lvl<3|missing(educ_lvl)), vce(cluster HH1)
esttab T7_C1 T7_C2 T7_C3 using "$tables\Table6.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Sans les répondants ayant terminé le secondaire ou plus", pattern(1 0 0))

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_D1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=59, vce(cluster HH1)
eststo T7_D2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=59, vce(cluster HH1)
esttab T7_D1 T7_D2 using "$tables\Table6.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Sans les répondants de plus de 59 ans", pattern(1 0))

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_E1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=49, vce(cluster HH1)
eststo T7_E2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=49, vce(cluster HH1)
esttab T7_E1 T7_E2 using "$tables\Table6.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Sans les répondants de plus de 49 ans", pattern(1 0))

eststo clear
use "$temp\sample_main.dta", clear
eststo T7_F1: reg some_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=39, vce(cluster HH1)
eststo T7_F2: reg completed_primary CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=39, vce(cluster HH1)
use "$temp\sample_litt_pooled.dta", clear
eststo T7_F3: reg litteratie CoIL urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7 if age<=39, vce(cluster HH1)
use "$temp\sample_infantmort.dta", clear
eststo T7_F4: reg infant_death CoIL urbain fille jumeaux mage_birth mage_birth2 brthord brthord2 ///
    shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7 if (annee_enquete-annee_naiss_mere)<=39, vce(cluster HH1)
esttab T7_F1 T7_F2 T7_F3 T7_F4 using "$tables\Table6.rtf", append ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) keep(CoIL) ///
    varlabels(CoIL "Dirigeant co-insulaire (CoIL)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(N r2, fmt(%12.0fc %9.3f) labels("Observations" "R²")) ///
    mgroups("Sans les répondants de plus de 39 ans", pattern(1 0 0 0))

*=== 13. TABLEAU 7 : EFFET DIFFÉRENTIEL PRÉ/POST RÉFORME (2001-2002) =======
capture program drop add_post_reforme
program define add_post_reforme
    args byvar
    gen byte post_reforme = (`byvar' + 8 >= 2002) if !missing(`byvar')
end

eststo clear
use "$temp\sample_main.dta", clear
add_post_reforme annee_naiss
eststo T9_1: reg some_primary c.CoIL##i.post_reforme urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
qui lincom CoIL + 1.post_reforme#c.CoIL
starfmt r(estimate) r(se) `e(df_r)'
local et = r(out)
estadd local efftot "`et'"

eststo T9_2: reg completed_primary c.CoIL##i.post_reforme urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
qui lincom CoIL + 1.post_reforme#c.CoIL
starfmt r(estimate) r(se) `e(df_r)'
local et = r(out)
estadd local efftot "`et'"

use "$temp\sample_litt_pooled.dta", clear
add_post_reforme annee_naiss
eststo T9_3: reg litteratie c.CoIL##i.post_reforme urbain male i.annee_naiss i.HH7 c.annee_naiss#i.HH7, vce(cluster HH1)
qui lincom CoIL + 1.post_reforme#c.CoIL
starfmt r(estimate) r(se) `e(df_r)'
local et = r(out)
estadd local efftot "`et'"

use "$temp\sample_infantmort.dta", clear
add_post_reforme annee_naiss_mere
eststo T9_4: reg infant_death c.CoIL##i.post_reforme urbain fille jumeaux mage_birth mage_birth2 ///
    brthord brthord2 shortspacing i.annee_naiss_enf i.HH7 c.annee_naiss_enf#i.HH7, vce(cluster HH1)
qui lincom CoIL + 1.post_reforme#c.CoIL
starfmt r(estimate) r(se) `e(df_r)'
local et = r(out)
estadd local efftot "`et'"

esttab T9_1 T9_2 T9_3 T9_4 using "$tables\Table7_PrePostReforme.rtf", replace ///
    label b(%9.4f) se(%9.4f) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(CoIL 1.post_reforme#c.CoIL) order(CoIL 1.post_reforme#c.CoIL) ///
    varlabels(CoIL "CoIL (pré-réforme, référence)" 1.post_reforme#c.CoIL "CoIL × Post-réforme (2002+)") ///
    mtitles("Éducation partielle" "Éducation complète" "Alphabétisation" "Décès infantile") ///
    stats(efftot N r2, fmt(%9.0g %12.0fc %9.3f) labels("Effet total post-réforme (CoIL+CoIL×Post)" "Observations" "R²")) ///
    title("Tableau 7 : Effet différentiel de la co-insularité avant/après la réforme de la présidence tournante ") ///
    addnotes("Post-réforme=1 si année naissance+8 ≥ 2002 (mère+8 pour la mortalité infantile)." ///
             "Effet total = CoIL + CoIL×Post, erreur-type calculée par la méthode delta (lincom)." ///
             "Alphabétisation : femmes et hommes réunis (contrôle Homme inclus).")


cap erase "$tables\TableA2.rtf"
if _rc == 0 di as result "Nettoyage : TableA2.rtf (obsolète) supprimé."

*=== RÉCAPITULATIF ==========================================================
di as result "Tableaux exportés dans : $tables"
di as result "Table1.rtf (statistiques descriptives - données désagrégées)"
di as result "Table2.rtf (résultat principal : éducation, alphabétisation, mortalité infantile)"
di as result "Table3.rtf (alphabétisation et éducation, par sexe)"
di as result "Table4.rtf (hétérogénéité insulaire par interaction + tests d'égalité des"
di as result "  coefficients CoIL x île, en second panneau du même fichier)"
di as result "Table5.rtf (hétérogénéité par mandat présidentiel)"
di as result "Table6.rtf (robustesse aux effets de sélection)"
di as result "Table7_PrePostReforme.rtf (effet différentiel pré/post-réforme)"
di as result "Table8.rtf (test de falsification)"
di as result "Numérotation continue de 1 à 8, sans saut ni suffixe 'bis'."
log close
exit
