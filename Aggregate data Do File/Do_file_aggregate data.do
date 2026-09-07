/*==============================================================================
   TITRE DU DO : DONNÉES AGRÉGÉES
   ------------------------------------------------------------------------
   Favoritisme régional et développement : l'origine insulaire du président en exercice 
   a-t-elle une influence sur le développement de son île ? Analyse de l'impact de la 
   présidence tournante aux Comores
   Panel de 54 communes x 1992-2023 (luminosité nocturne, DMSP-OLS / VIIRS)
   Auteur : Moustadrane Oussama
==============================================================================*/

clear all
set more off
set linesize 120
set scheme s2color

*-------------------------------------------------------------------------
* 0. CHEMINS ET OUTILS
*-------------------------------------------------------------------------
global DATA "C:\Users\bmd\Desktop\Master's thesis_ Frensh version\Aggregate data_Do_File"
global FIG  "$DATA\Figures"
global TAB  "$DATA\Tableaux"
capture mkdir "$FIG"
capture mkdir "$TAB"

* ssc install outreg2, replace
* ssc install coefplot, replace

capture program drop xpng
program define xpng
    args nom w h
    if "`w'" == "" local w 1400
    if "`h'" == "" local h 900
    graph export "$FIG\\`nom'.png", replace width(`w') height(`h')
    display as result "  -> `nom'.png exporte"
end

use "$DATA\Panel_54_communes.dta", clear
xtset commune_id year

/*==============================================================================
   1. PRÉPARATION DES VARIABLES (communes à tout le do-file)
==============================================================================*/

* --- Indicatrices iles / tendances (recalculées dans chaque bloc selon la
*     fenêtre temporelle retenue, cf. sections 3 à 6) ---
cap drop d_ndz d_mwa
gen byte d_ndz = (island_id == 2)
gen byte d_mwa = (island_id == 3)
label var d_ndz "Indicatrice Ndzuwani"
label var d_mwa "Indicatrice Mwali"

* --- Post-réforme et interaction CoCL x Post (echantillon complet) ---
cap drop post
gen byte post = (year >= 2002)
label var post "Post-reforme (1 si year >= 2002)"

cap drop CoCL_post
gen byte CoCL_post = CoCL * post
label var CoCL_post "CoCL x Post"

* --- Decomposition CoCL par dirigeant, pré-réforme (1992-2001) ---
cap drop CoCL_djohar CoCL_taki CoCL_azali0
gen byte CoCL_djohar = CoCL * (year >= 1992 & year <= 1995)
gen byte CoCL_taki   = CoCL * (year >= 1996 & year <= 1998)
gen byte CoCL_azali0 = CoCL * (year >= 1999 & year <= 2001)
label var CoCL_djohar "CoCL x Djohar (1992-95)"
label var CoCL_taki   "CoCL x Taki (1996-98)"
label var CoCL_azali0 "CoCL x Azali putsch (1999-01)"

* --- Decomposition CoCL par dirigeant, post-réforme (2002-2023) ---
cap drop CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2
gen byte CoCL_azali1   = CoCL * (year >= 2002 & year <= 2006)
gen byte CoCL_sambi    = CoCL * (year >= 2006 & year <= 2011)
gen byte CoCL_ikililou = CoCL * (year >= 2011 & year <= 2016)
gen byte CoCL_azali2   = CoCL * (year >= 2016 & year <= 2023)
label var CoCL_azali1   "CoCL x Azali I (2002-06)"
label var CoCL_sambi    "CoCL x Sambi (2006-11)"
label var CoCL_ikililou "CoCL x Ikililou (2011-16)"
label var CoCL_azali2   "CoCL x Azali II (2016-23)"

* --- Decomposition CoIL par dirigeant, post-réforme (2002-2023) ---
cap drop CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2
gen byte CoIL_azali1   = (island_id==1 & year>=2002 & year<=2006)
gen byte CoIL_sambi    = (island_id==2 & year>=2006 & year<=2011)
gen byte CoIL_ikililou = (island_id==3 & year>=2011 & year<=2016)
gen byte CoIL_azali2   = (island_id==1 & year>=2016 & year<=2023)
label var CoIL_azali1   "CoIL x Azali I (2002-06)"
label var CoIL_sambi    "CoIL x Sambi (2006-11)"
label var CoIL_ikililou "CoIL x Ikililou (2011-16)"
label var CoIL_azali2   "CoIL x Azali II (2016-23)"

* --- Effets fixes annee x ile (echantillon complet) ---
cap drop year_island_full
egen year_island_full = group(year island_id)
label var year_island_full "EF annee x ile (echantillon complet)"


/*==============================================================================
   2. TABLEAU 1 - STATISTIQUES DESCRIPTIVES - DONNÉES AGRÉGÉES
   (tableau unique à 3 blocs : variable dépendante + ventilation par île,
    variables de traitement, variables de contrôle - même structure que le
    tableau modèle)
==============================================================================*/

* --- Variables auxiliaires pour ventiler ln_nl par île sans créer de
*     nouvelles COLONNES (l'usage de ctitle() dans une table sum() force
*     outreg2 à ouvrir une colonne par appel, ce qui n'est pas ce qu'on veut
*     ici : on veut 3 LIGNES indentées sous la variable dépendante). Chaque
*     variable est manquante hors de son île, donc outreg2 calcule N/moyenne/
*     écart-type/min/max uniquement sur les observations de cette île. ---
cap drop ln_nl_ngz ln_nl_ndz ln_nl_mwa
gen double ln_nl_ngz = ln_nl if island_id == 1
gen double ln_nl_ndz = ln_nl if island_id == 2
gen double ln_nl_mwa = ln_nl if island_id == 3

* --- Libellés utilisés comme intitulés de ligne par outreg2 (label) ---
label var ln_nl      "Luminosité nocturne annuelle log(NL_t + 1)"
label var ln_nl_ngz  "      Ngazidja"
label var ln_nl_ndz  "      Ndzuwani"
label var ln_nl_mwa  "      Mwali"
label var CoIL       "CoIL (Co-appartenance insulaire)"
label var CoCL       "CoCL (Co-appartenance communale)"
cap label var pop           "Population communale"
cap label var ln_pop        "Logarithme de la population communale"
cap label var precipitation "Précipitations annuelles totales"
cap label var malaria_rate  "Taux d'incidence du paludisme"
label var dist_roads    "Distance aux routes principales"
label var access_cities "Temps d'accessibilité aux villes"

* --- Bloc 1 : variable dépendante (agrégée + ventilation par île) ---
* NB IMPORTANT : outreg2, en mode sum(), résume par défaut TOUTES les
*      variables présentes dans le dataset en mémoire au moment de l'appel
*      (et, s'il traîne un e(sample) d'une régression tournée plus tôt dans
*      la session, il l'utilise en plus comme restriction d'échantillon) -
*      il NE se limite PAS automatiquement à la liste passée à la commande
*      `sum` qui précède. C'est ce qui produisait un tableau avec des
*      dizaines de lignes (post, trend_ndz, CoIL_azali1, esample()..., etc.)
*      dès que ce bloc était exécuté après les sections 3 à 11. L'option
*      keep() ci-dessous force outreg2 à n'afficher QUE les variables
*      listées, quoi qu'il y ait par ailleurs dans le dataset ou en mémoire.
* NB : outreg2 n'insère pas non plus de ligne d'en-tête en gras du type
*      "Variable dépendante" / "Variables de traitement" / "Variables de
*      contrôle" au sein d'un tableau sum() : ces 3 intitulés (visibles sur
*      le tableau modèle) sont à taper à la main dans le .doc généré, puis
*      mettre la ligne en gras (Accueil > Gras).
sum ln_nl ln_nl_ngz ln_nl_ndz ln_nl_mwa
outreg2 using "$TAB\Tableau1_Statistiques_descriptives.doc", replace word ///
    sum(log) label dec(4) ///
    keep(ln_nl ln_nl_ngz ln_nl_ndz ln_nl_mwa) ///
    sortvar(ln_nl ln_nl_ngz ln_nl_ndz ln_nl_mwa) ///
    title("Tableau 1 - Statistiques descriptives - données agrégées")

* --- Bloc 2 : variables de traitement ---
sum CoIL CoCL
outreg2 using "$TAB\Tableau1_Statistiques_descriptives.doc", append word ///
    sum(log) label dec(4) ///
    keep(CoIL CoCL) sortvar(CoIL CoCL)

* --- Bloc 3 : variables de contrôle ---
* (pop et malaria_rate sont ignorées automatiquement si absentes du panel)
local POPVAR ""
local MALVAR ""
cap confirm variable pop
if _rc == 0 local POPVAR pop
cap confirm variable malaria_rate
if _rc == 0 local MALVAR malaria_rate
local KEEP_T1 `POPVAR' ln_pop precipitation `MALVAR' dist_roads access_cities

sum `KEEP_T1'
outreg2 using "$TAB\Tableau1_Statistiques_descriptives.doc", append word ///
    sum(log) label dec(2) ///
    keep(`KEEP_T1') sortvar(`KEEP_T1') ///
    addnote("Note : L'unité d'observation est la commune par année. La variable dépendante est le logarithme de la luminosité nocturne augmentée d'une unité, log(NL_t + 1), construit à partir des données satellitaires DMSP-OLS et VIIRS. CoIL est un indicateur égal à 1 si la commune appartient à l'île d'origine du président en exercice. CoCL est un indicateur égal à 1 si la commune est la commune d'origine du président en exercice. Les effectifs inférieurs à 1728 reflètent les données manquantes pour certaines variables de contrôle sur la sous-période considérée.")


/*==============================================================================
   3. TABLEAU 2 - FAVORITISME COMMUNAL ET ACTIVITÉ ÉCONOMIQUE
      (échantillon pré-réforme, 1992-2001 ; décomposition par dirigeant)
==============================================================================*/

preserve
    keep if year >= 1992 & year <= 2001

    cap drop year_c
    gen double year_c = year - 1992
    cap drop trend_ndz trend_mwa
    gen double trend_ndz = year_c * d_ndz
    gen double trend_mwa = year_c * d_mwa
    cap drop dist_roads_t access_t
    gen double dist_roads_t = dist_roads    * year_c
    gen double access_t     = access_cities * year_c

    cap drop year_island_pre
    egen year_island_pre = group(year island_id)

    * --- (1) Base ---
    xtreg ln_nl CoCL i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", replace word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(1) Base") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non) ///
        title("Tableau 2 - Favoritisme communal et activité économique")

    * --- (2) Contrôles ---
    xtreg ln_nl CoCL precipitation dist_roads_t access_t i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", append word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(2) Contrôles") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

    * --- (3) Tendances ---
    xtreg ln_nl CoCL precipitation dist_roads_t access_t trend_ndz trend_mwa i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", append word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(3) Tendances") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Oui)

    * --- (4) Dirigeants ---
    xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", append word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(4) Dirigeants") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

    * --- (5) Année x île ---
    xtreg ln_nl CoCL i.year_island_pre, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", append word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(5) Année x île") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)

    * --- (6) Dirigeants + Année x île ---
    xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 i.year_island_pre, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau2_Favoritisme_communal_activite_eco.doc", append word ///
        keep(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_djohar CoCL_taki CoCL_azali0 precipitation dist_roads_t access_t) ///
        nocons ctitle("(6) Dirigeants + Année x île") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)
restore


/*==============================================================================
   4. TABLEAU 3 - FAVORITISME COMMUNAL AVANT ET APRÈS LA RÉFORME DE LA
      PRÉSIDENCE TOURNANTE (échantillon complet, 1992-2023, interaction CoCL x Post)
==============================================================================*/

cap drop year_c
gen double year_c = year - 2002
cap drop trend_ndz trend_mwa
gen double trend_ndz = year_c * d_ndz
gen double trend_mwa = year_c * d_mwa
cap drop dist_roads_t access_t
gen double dist_roads_t = dist_roads    * year_c
gen double access_t     = access_cities * year_c

* --- (1) Baseline ---
xtreg ln_nl CoCL CoCL_post i.year, fe vce(cluster commune_id)
outreg2 using "$TAB\Tableau3_Favoritisme_avant_apres_reforme.doc", replace word ///
    keep(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    sortvar(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    nocons ctitle("(1) Baseline") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non) ///
    title("Tableau 3 - Favoritisme communal avant et après la réforme de la présidence tournante")

* --- (2) Tendances ---
xtreg ln_nl CoCL CoCL_post trend_ndz trend_mwa i.year, fe vce(cluster commune_id)
outreg2 using "$TAB\Tableau3_Favoritisme_avant_apres_reforme.doc", append word ///
    keep(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    sortvar(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    nocons ctitle("(2) Tendances") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Oui)

* --- (3) Contrôles ---
xtreg ln_nl CoCL CoCL_post precipitation dist_roads_t access_t i.year, fe vce(cluster commune_id)
outreg2 using "$TAB\Tableau3_Favoritisme_avant_apres_reforme.doc", append word ///
    keep(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    sortvar(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    nocons ctitle("(3) Contrôles") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

* --- (4) Année x île ---
xtreg ln_nl CoCL CoCL_post i.year_island_full, fe vce(cluster commune_id)
outreg2 using "$TAB\Tableau3_Favoritisme_avant_apres_reforme.doc", append word ///
    keep(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    sortvar(CoCL CoCL_post precipitation dist_roads_t access_t) ///
    nocons ctitle("(4) Année x île") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)

* Test de l'effet total post-réforme (β_CoCL + β_CoCL_post) sur la spec. (3)
xtreg ln_nl CoCL CoCL_post precipitation dist_roads_t access_t i.year, fe vce(cluster commune_id)
display _n "Effet total CoCL post-reforme (beta_CoCL + beta_CoCL_post) :"
lincom CoCL + CoCL_post


/*==============================================================================
   5. TABLEAU 4 - FAVORITISME AU NIVEAU COMMUNAL APRÈS LA RÉFORME
      (échantillon post-réforme, 2002-2023 ; décomposition par dirigeant)
==============================================================================*/

preserve
    keep if year >= 2002 & year <= 2023

    cap drop year_c
    gen double year_c = year - 2002
    cap drop trend_ndz trend_mwa
    gen double trend_ndz = year_c * d_ndz
    gen double trend_mwa = year_c * d_mwa
    cap drop dist_roads_t access_t
    gen double dist_roads_t = dist_roads    * year_c
    gen double access_t     = access_cities * year_c

    cap drop year_island_post
    egen year_island_post = group(year island_id)

    * --- (1) Base ---
    xtreg ln_nl CoCL i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", replace word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(1) Base") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non) ///
        title("Tableau 4 - Favoritisme au niveau communal après la réforme")

    * --- (2) Contrôles ---
    xtreg ln_nl CoCL precipitation dist_roads_t access_t i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", append word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(2) Contrôles") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

    * --- (3) Tendances (ajoutées aux contrôles) ---
    xtreg ln_nl CoCL precipitation dist_roads_t access_t trend_ndz trend_mwa i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", append word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(3) Tendances") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Oui)

    * --- (4) Dirigeants (avec contrôles) ---
    xtreg ln_nl CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t i.year, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", append word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(4) Dirigeants") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

    * --- (5) Année x île ---
    xtreg ln_nl CoCL i.year_island_post, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", append word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(5) Année x île") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)

    * --- (6) Dirigeants + Année x île ---
    xtreg ln_nl CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 i.year_island_post, fe vce(cluster commune_id)
    outreg2 using "$TAB\Tableau4_Favoritisme_communal_apres_reforme.doc", append word ///
        keep(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        sortvar(CoCL CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 precipitation dist_roads_t access_t) ///
        nocons ctitle("(6) Dirigeants + Année x île") label dec(4) ///
        addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)
restore


/*==============================================================================
   6. TABLEAU 5 - DÉCOMPOSITION COMPLÈTE DE CoCL ET CoIL PAR DIRIGEANT
      (échantillon complet, 1992-2023)
==============================================================================*/

cap drop year_c
gen double year_c = year - 2002
cap drop trend_ndz trend_mwa
gen double trend_ndz = year_c * d_ndz
gen double trend_mwa = year_c * d_mwa
cap drop dist_roads_t access_t
gen double dist_roads_t = dist_roads    * year_c
gen double access_t     = access_cities * year_c

local KEEP_T5 CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 ///
              CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2 precipitation dist_roads_t access_t

* --- (1) CoCL seul ---
xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 i.year, fe vce(cluster commune_id)
estimates store T5c1
outreg2 using "$TAB\Tableau5_Decomposition_CoCL_CoIL.doc", replace word ///
    keep(`KEEP_T5') sortvar(`KEEP_T5') ///
    nocons ctitle("(1) CoCL") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non) ///
    title("Tableau 5 - Décomposition complète de CoCL et CoIL par dirigeant")

* --- (2) CoCL + CoIL ---
xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 ///
      CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2 i.year, fe vce(cluster commune_id)
estimates store T5c2
outreg2 using "$TAB\Tableau5_Decomposition_CoCL_CoIL.doc", append word ///
    keep(`KEEP_T5') sortvar(`KEEP_T5') ///
    nocons ctitle("(2) CoCL + CoIL") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Non)

* --- (3) Tendances ---
xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 ///
      CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2 trend_ndz trend_mwa i.year, fe vce(cluster commune_id)
estimates store T5c3
outreg2 using "$TAB\Tableau5_Decomposition_CoCL_CoIL.doc", append word ///
    keep(`KEEP_T5') sortvar(`KEEP_T5') ///
    nocons ctitle("(3) Tendances") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Oui)

* --- (4) Contrôles (= Tendances + précipitations/routes/villes) ---
xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 ///
      CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2 precipitation dist_roads_t access_t ///
      trend_ndz trend_mwa i.year, fe vce(cluster commune_id)
estimates store T5c4
outreg2 using "$TAB\Tableau5_Decomposition_CoCL_CoIL.doc", append word ///
    keep(`KEEP_T5') sortvar(`KEEP_T5') ///
    nocons ctitle("(4) Contrôles") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Oui, EF annee x ile, Non, Tend. lin. iles, Oui)

* --- (5) Année x île ---
xtreg ln_nl CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2 ///
      CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2 i.year_island_full, fe vce(cluster commune_id)
estimates store T5c5
outreg2 using "$TAB\Tableau5_Decomposition_CoCL_CoIL.doc", append word ///
    keep(`KEEP_T5') sortvar(`KEEP_T5') ///
    nocons ctitle("(5) Année x île") label dec(4) ///
    addtext(EF communes, Oui, EF annees, Non, EF annee x ile, Oui, Tend. lin. iles, Non)

* Tests cle
estimates restore T5c4
display _n "TEST CLE : Azali putsch (pre) vs Azali I (post)"
lincom CoCL_azali1 - CoCL_azali0


/*==============================================================================
   7. FIGURE 1 - FAVORITISME COMMUNAL (CoCL) PAR MANDAT - COEFPLOT
      (repose sur la spécification (4) "Contrôles" du Tableau 5)
==============================================================================*/

estimates restore T5c4

coefplot, ///
    keep(CoCL_djohar CoCL_taki CoCL_azali0 CoCL_azali1 CoCL_sambi CoCL_ikililou CoCL_azali2) ///
    vertical recast(connected) ///
    ciopts(recast(rarea) fcolor(navy%15) lcolor(navy%30)) ///
    mcolor(navy) lcolor(navy) lwidth(medthick) msymbol(circle) msize(medium) ///
    xlabel(1 `""Djohar" "1992-95""' 2 `""Taki" "1996-98""' 3 `""Azali" "putsch" "1999-01""' ///
           4 `""Azali I" "2002-06""' 5 `""Sambi" "2006-11""' ///
           6 `""Ikililou" "2011-16""' 7 `""Azali II" "2016-23""', labsize(vsmall) angle(0)) ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    xline(3.5, lcolor(red%70) lpattern(longdash) lwidth(medthick)) ///
    addplot(scatteri 0.08 3.5 "Présidence tournante", msymbol(none) mlabel(col4) mlabsize(vsmall) mlabcolor(red%80) mlabposition(3)) ///
    ytitle("Effet sur ln(NL+1)", size(small)) xtitle("") ///
    title("Évolution du favoritisme communal selon le mandat présidentiel", size(medsmall)) ///
    note("IC à 95%. Ligne rouge = réforme de 2002.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(fig1_CoCL, replace)
xpng Figure1_CoefplotCoCL_mandats 1400 900


/*==============================================================================
   8. FIGURE 2 - ÉVOLUTION DE LA LUMINOSITÉ NOCTURNE SELON LES MANDATS RETENUS
      POUR LA PÉRIODE PRÉ-ROTATION PRÉSIDENTIELLE, 1992-2002
==============================================================================*/

preserve
    collapse (mean) ln_nl, by(island_id year)
    keep if year >= 1992 & year <= 2002

    twoway ///
        (connected ln_nl year if island_id==1, lcolor(navy)      mcolor(navy)      msymbol(circle)   lwidth(medthick) msize(medium)) ///
        (connected ln_nl year if island_id==2, lcolor(cranberry) mcolor(cranberry) msymbol(triangle) lwidth(medthick) msize(medium) lpattern(dash)) ///
        (connected ln_nl year if island_id==3, lcolor(dkgreen)   mcolor(dkgreen)   msymbol(square)   lwidth(medthick) msize(medium) lpattern(shortdash)), ///
        xtitle("Année", size(small)) ytitle("ln(NL + 1)", size(small)) ///
        xlabel(1992(1)2002, labsize(small) angle(45)) ///
        ylabel(0(0.02)0.18, labsize(small) format(%4.2f) nogrid) ///
        text(0.175 1993.5 "{bf:Saïd Mohamed Djohar}", size(vsmall) color(gs2) placement(c)) ///
        text(0.175 1997   "{bf:Mohamed Taki Abdoulkarim}", size(vsmall) color(gs2) placement(c)) ///
        text(0.175 2000.5 "{bf:Azali Assoumani}", size(vsmall) color(gs2) placement(c)) ///
        xline(1996, lcolor(gs8%60)     lpattern(shortdash) lwidth(thin)) ///
        xline(1999, lcolor(gs8%60)     lpattern(shortdash) lwidth(thin)) ///
        xline(2001, lcolor(dkgreen%70) lpattern(longdash)  lwidth(thin)) ///
        xline(2002, lcolor(red%50)     lpattern(longdash)  lwidth(thin)) ///
        text(0.155 2001    " {bf:Accord-cadre}" " {bf:de Fomboni}", size(vsmall) color(dkgreen%80) placement(w)) ///
        text(0.148 2002.05 " {bf:Présidence}"    " {bf:tournante}",  size(vsmall) color(red%70)    placement(w)) ///
        legend(order(1 "Ngazidja" 2 "Ndzuwani" 3 "Mwali") position(6) ring(1) cols(3) size(vsmall) region(lcolor(gs12) fcolor(white))) ///
        title("Évolution de l'intensité lumineuse nocturne selon les mandats" "retenus pour la période pré-rotation présidentielle, 1992-2002", size(medsmall)) ///
        graphregion(color(white)) plotregion(color(white)) name(fig2_prerotation, replace)
    xpng Figure2_Evolution_prerotation_mandats 1400 900
restore

/*==============================================================================
   9. FIGURE 3 - ÉVOLUTION DE LA LUMINOSITÉ NOCTURNE PAR ÎLE ET TRANSITIONS DE
      POUVOIR, 1992-2002 (TOUTES LES TRANSITIONS, Y COMPRIS LES INTÉRIMS COURTS)
==============================================================================*/

preserve
    collapse (mean) ln_nl, by(island_id year)
    keep if year >= 1992 & year <= 2002
    twoway ///
        (connected ln_nl year if island_id==1, lcolor(navy)      mcolor(navy)      msymbol(circle)   lwidth(medthick) msize(medium)) ///
        (connected ln_nl year if island_id==2, lcolor(cranberry) mcolor(cranberry) msymbol(triangle) lwidth(medthick) msize(medium) lpattern(dash)) ///
        (connected ln_nl year if island_id==3, lcolor(dkgreen)   mcolor(dkgreen)   msymbol(square)   lwidth(medthick) msize(medium) lpattern(shortdash)), ///
        xtitle("Année", size(small)) ytitle("ln(NL + 1)", size(small)) ///
        xscale(range(1990.8 2004)) ///
        xlabel(1992(1)2002, labsize(small) angle(45)) ///
        yscale(range(0 0.33)) ///
        ylabel(0(0.04)0.20, labsize(vsmall) angle(0) format(%4.2f) nogrid) ///
        xline(1995.75 1995.84 1995.85 1996.07 1996.23 1998.85 1999.33 2002.05, ///
              lcolor(gs8%50) lpattern(shortdash) lwidth(vthin)) ///
        xline(2001, lcolor(dkgreen%70) lpattern(longdash) lwidth(thin)) ///
        xline(2002, lcolor(red%50)     lpattern(longdash) lwidth(thin)) ///
        text(0.30  1992.6  "{bf:Saïd Mohamed Djohar}"       "{bf:20 mars 90 - 29 sept 95}",  size(vsmall) color(gs2) placement(ne)) ///
        text(0.276 1995.3  "{bf:Combo Ayouba}"              "{bf:29 sept 95 - 2 oct 95}",    size(vsmall) color(gs2) placement(nw)) ///
        text(0.252 1996.3  "{bf:Co-présidence de Taki et Kemal}" "{bf:2 oct 95 - 5 oct 95}",  size(vsmall) color(gs2) placement(ne)) ///
        text(0.228 1995.4  "{bf:Caabi El-Yachroutu}"        "{bf:5 oct 95 - 26 janv 96}",     size(vsmall) color(gs2) placement(nw)) ///
        text(0.204 1996.5  "{bf:Saïd Mohamed Djohar}"       "{bf:26 janv 96 - 25 mars 96}",   size(vsmall) color(gs2) placement(ne)) ///
        text(0.30  1997.3  "{bf:Mohamed Taki Abdoulkarim}"  "{bf:25 mars 96 - 6 nov 98}",     size(vsmall) color(gs2) placement(n)) ///
        text(0.276 1998.6  "{bf:Tadjidine Ben Saïd Massounde}" "{bf:6 nov 98 - 30 avr 99}",   size(vsmall) color(gs2) placement(nw)) ///
        text(0.252 1999.6  "{bf:Azali Assoumani}"           "{bf:30 avr 99 - 21 janv 02}",    size(vsmall) color(gs2) placement(ne)) ///
        text(0.228 2001.9  "{bf:Hamadi Madi Boléro}"        "{bf:21 janv 02 - 26 mai 02}",    size(vsmall) color(gs2) placement(nw)) ///
        text(0.17  2001    " {bf:Accord Fomboni}",  size(vsmall) color(dkgreen%80) placement(ne)) ///
        text(0.15  2002.05 " {bf:Présidence tournante}", size(vsmall) color(red%70) placement(ne)) ///
        legend(order(1 "Ngazidja" 2 "Ndzuwani" 3 "Mwali") position(6) ring(1) cols(3) size(vsmall) region(lcolor(gs12) fcolor(white))) ///
        title("Évolution de la luminosité nocturne par île et transitions de" "pouvoir, 1992-2002", size(medsmall)) ///
        graphregion(color(white) margin(r+6 l+2)) plotregion(color(white)) ///
        xsize(12) ysize(7.5) ///
        name(fig3_transitions, replace)

    xpng Figure3_Evolution_transitions_pouvoir 2100 1300
restore



/*==============================================================================
   10. FIGURE 4 - ÉVOLUTION DE LA LUMINOSITÉ NOCTURNE PAR ÎLE PENDANT LA
       PRÉSIDENCE TOURNANTE, 2000-2023
==============================================================================*/

preserve
    collapse (mean) ln_nl, by(island_id year)
    keep if year >= 2000

    twoway ///
        (connected ln_nl year if island_id==1, lcolor(navy)      mcolor(navy)      msymbol(circle)   lwidth(medthick) msize(vsmall)) ///
        (connected ln_nl year if island_id==2, lcolor(cranberry) mcolor(cranberry) msymbol(triangle) lwidth(medthick) msize(vsmall) lpattern(dash)) ///
        (connected ln_nl year if island_id==3, lcolor(dkgreen)   mcolor(dkgreen)   msymbol(square)   lwidth(medthick) msize(vsmall) lpattern(shortdash)), ///
        xtitle("Année", size(small)) ytitle("ln(NL + 1)", size(small)) ///
        xlabel(2000(2)2023, labsize(vsmall) angle(45)) ///
        ylabel(0(0.04)0.20, labsize(small) format(%4.2f) grid glcolor(gs14)) ///
        xline(2002, lcolor(red%50) lpattern(longdash) lwidth(thin)) ///
        xline(2006, lcolor(red%50) lpattern(longdash) lwidth(thin)) ///
        xline(2011, lcolor(red%50) lpattern(longdash) lwidth(thin)) ///
        xline(2016, lcolor(red%50) lpattern(longdash) lwidth(thin)) ///
        text(0.205 2004   "Azali I",  size(vsmall) color(red%80) placement(n)) ///
        text(0.205 2008.5 "Sambi",    size(vsmall) color(red%80) placement(n)) ///
        text(0.205 2013.5 "Ikililou", size(vsmall) color(red%80) placement(n)) ///
        text(0.205 2019.5 "Azali II", size(vsmall) color(red%80) placement(n)) ///
        legend(order(1 "Ngazidja" 2 "Ndzuwani" 3 "Mwali") position(1) ring(0) cols(1) size(vsmall) region(lcolor(gs12) fcolor(white))) ///
        title("Évolution de l'intensité lumineuse nocturne par île au cours" "de la présidence tournante, 2002-2023", size(medsmall)) ///
        graphregion(color(white)) plotregion(color(white)) name(fig4_tournante, replace)
    xpng Figure4_Evolution_presidence_tournante 1500 900
restore


/*==============================================================================
   11. FIGURE 5 - FAVORITISME INSULAIRE (CoIL) PAR MANDAT - COEFPLOT
       (repose sur la même spécification (4) "Contrôles" du Tableau 5)
==============================================================================*/

estimates restore T5c4

coefplot, ///
    keep(CoIL_azali1 CoIL_sambi CoIL_ikililou CoIL_azali2) ///
    vertical recast(connected) ///
    ciopts(recast(rarea) fcolor(dkgreen%15) lcolor(dkgreen%30)) ///
    mcolor(dkgreen) lcolor(dkgreen) lwidth(medthick) msymbol(square) msize(medium) ///
    xlabel(1 `""Azali I" "2002-06""' 2 `""Sambi" "2006-11""' ///
           3 `""Ikililou" "2011-16""' 4 `""Azali II" "2016-23""', labsize(vsmall) angle(0)) ///
    yline(0, lcolor(black) lpattern(dash) lwidth(thin)) ///
    ytitle("Effet sur ln(NL+1)", size(small)) xtitle("") ///
    title("L'émergence du favoritisme insulaire selon le mandat présidentiel", size(medsmall)) ///
    note("IC à 95%. Post-réforme uniquement.", size(vsmall) color(gs7)) ///
    graphregion(color(white)) plotregion(color(white)) scheme(s2color) name(fig5_CoIL, replace)
xpng Figure5_CoefplotCoIL_mandats 1400 900


/*==============================================================================
   FIN DU DO-FILE — 5 tableaux (.doc) + 5 figures (.png) exportés dans :
     $TAB : Tableau1_Statistiques_descriptives.doc
            Tableau2_Favoritisme_communal_activite_eco.doc
            Tableau3_Favoritisme_avant_apres_reforme.doc
            Tableau4_Favoritisme_communal_apres_reforme.doc
            Tableau5_Decomposition_CoCL_CoIL.doc
     $FIG : Figure1_CoefplotCoCL_mandats.png
            Figure2_Evolution_prerotation_mandats.png
            Figure3_Evolution_transitions_pouvoir.png
            Figure4_Evolution_presidence_tournante.png
            Figure5_CoefplotCoIL_mandats.png
==============================================================================*/
