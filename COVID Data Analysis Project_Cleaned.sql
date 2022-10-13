-- =============================================
-- Author: Yahya Talab
-- Create date: 10/12/2022
-- Description:	Analysis Update on COVID-19 Worldwide
-- =============================================

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Below provide a quick detailed view of the 3 tables used

USE covid_analysis;
--Table 1 on Deaths
exec sp_help 'dbo.coviddeaths'
SELECT COUNT(*) AS ct_rows
FROM coviddeaths
--Table 2 on vaccinations
exec sp_help 'dbo.covidvaccinations'
SELECT COUNT(*) AS ct_rows
FROM coviddeaths
-- Table 3 on deaths and other demographic, health, and socioeconomic variables
exec sp_help 'dbo.covid_all_other'
SELECT COUNT(*) AS ct_rows
FROM coviddeaths

-- Quick view of the tables
SELECT *
FROM covid_analysis..coviddeaths
WHERE continent IS NOT NULL -- a null in continent implies that value is not a country (e.g. continent)
ORDER BY 3,4

SELECT * 
FROM covid_analysis..covidvaccinations
WHERE continent IS NOT NULL
ORDER BY 3 ,4

SELECT * 
FROM covid_analysis..covid_all_other
WHERE continent IS NOT NULL
ORDER BY 3 ,4


----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Creating a table to examine total cases vs total deaths 
--Viewing the likelihood of dying from covid
--note: variables for age and income were included for further analysis in Tableau

--Code:
--Create View deathlikelihoodbycountry as

SELECT dth.continent, dth.location, dth.date, dth.total_cases, dth.total_deaths
,oth.[stringency_index] , oth.[median_age] ,oth.[aged_65_older] , oth.[aged_70_older], oth.[gdp_per_capita],oth.[extreme_poverty],oth.[population],oth.[population_density]
,(dth.total_deaths/dth.total_cases)*100 AS deathpercentage
From covid_analysis..coviddeaths dth
JOIN covid_analysis..covid_all_other oth
	ON dth.location = oth.location 
	and dth.date = oth.date
WHERE dth.continent is not null
--Where location like '%states' 
--order by 1, 2

----------------------------------------------------------------------------------------------------------------------------------------------------------------

--Looking at total cases vs total population
--percent of population that contracted it

--Code:
--CREATE VIEW deaths_aspctof_pop AS
SELECT continent, location, date, population, total_cases,  (total_cases/population)*100 AS percent_pop_infected, (total_deaths/population)*100 AS covid_deaths_pctofpop
From covid_analysis..coviddeaths
--Where location like '%states' 
--order by 1, 2

---------------------------------------------------------------------------------------------------------------------------------------------------------------

--Finding countries with highest infection rate compared to population

--Code:
--Create View maxinfectionratebycountry as
SELECT location, population, MAX(total_cases) as highest_infect_ct,  MAX((total_cases/population))*100 AS max_percent_pop_infected
--, MIN(total_cases) as lowest_infect_ct, MIN((total_cases/population))*100 AS min_percent_pop_infected
From covid_analysis..coviddeaths
WHERE continent IS NOT NULL -- to provide only countries
Group by location, population
--order by 4 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Finding highest death count by country
-- Create max_percent_pop_dead as the amount of deaths reached as a percent of population

--Code:

SELECT location, population, MAX(cast(total_deaths as int)) as highest_death_ct, MAX((cast(total_deaths as int)/population))*100 AS max_percent_pop_dead
From covid_analysis..coviddeaths
WHERE continent IS NOT NULL
Group by location, population
order by 4 DESC 

----------------------------------------------------------------------------------------------------------------------------------------------------------------

--Finding highest percent of deaths by continent

-- Code:
-- Create View maxdeathpct_reached_by_country as
SELECT location, MAX(cast(total_deaths as int)) as Total_Death_ct, MAX((cast(total_deaths as int)/population))*100 AS maxDead_as_percent_ofPop
FROM covid_analysis..coviddeaths
WHERE continent is null AND location not like '%income' AND location not like 'International' 
GROUP BY location
ORDER BY Total_Death_ct desc

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Global numbers on total deaths, total cases, and deaths as a perc of cases

--Code:
--CREATE VIEW global_tot as
Select SUM(new_cases) as  total_cases, SUM(cast(new_deaths as bigint)) as total_deaths, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
From covid_analysis..coviddeaths
Where continent is not null 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Death rates grouped by country income levels 

--Code:
--CREATE VIEW income_lvl_deaths as
SELECT location,population, SUM(new_cases) as  total_cases, SUM(cast(new_deaths as bigint)) as total_deaths, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
from covid_analysis..coviddeaths
WHERE continent is null AND location  like '%income'
Group BY continent,location, population
order by death_percentof_cases desc

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Examining cases and deaths based on avg stringency levels of countries since the pandemic began

--Code:
--CREATE View stingency_lvls as
SELECT  location, population, AVG([stringency_index]) as avg_string,SUM(new_cases) as  total_cases, SUM(cast(new_deaths as bigint)) as total_deaths--, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
from covid_analysis..covid_all_other
WHERE continent is not null AND location not like '%income' AND location not like 'International' 
--WHERE continent is null AND location  like '%income'
Group BY location, population
order by avg_string DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--USE CTE Table to create rolling sum and percentage of people vaccinated 

--Rolling sum of first time vaccinations for nations willingness to vaccinate
Select dth.[continent], dth.[location], dth.[date], dth.population, vcn.[new_vaccinations]
, SUM(convert(bigint, vcn.[new_vaccinations])) OVER (Partition BY dth.location order by dth.location, dth.date) as Vcn_rolling_sum
From covid_analysis..coviddeaths dth	
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location = vcn.location 
	and dth.date = vcn.date
WHERE dth.continent is not null
Order by 2,3

--USE CTE
--CREATE View rolling_vaccinations as
WITH PopVacTable (continent, location, date, population, new_vaccinations,vcn_rolling_sum)
as 
(
select dth.continent, dth.location, dth.date, dth.population, vcn.new_people_vaccinated_smoothed
, SUM(CONVERT(bigint, vcn.new_people_vaccinated_smoothed)) OVER (partition by dth.location order by dth.location, dth.date) as vcn_rolling_sum
From covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	and dth.date = vcn.date
--where dth.continent is not null 
)

SELECT *, (vcn_rolling_sum/population)*100 as rolling_pcnt_ofvcn
From PopVacTable

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- USE TEMP Table to create rolling sum and percentage of people vaccinated  Note: the variable used is new_people_vaccinated_smoothed to show Daily number of people receiving their first vaccine dose (7-day smoothed)

DROP Table if exists #PercentPopVacinated
CREATE Table #PercentPopVacinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rollingsumvcn numeric
)

Insert Into #PercentPopVacinated
select dth.continent, dth.location, dth.date, dth.population, vcn.new_people_vaccinated_smoothed
, SUM(CONVERT(bigint, vcn.new_people_vaccinated_smoothed)) OVER (partition by dth.location order by dth.location, dth.date) as rollingsumvcn
From covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	and dth.date = vcn.date
where dth.continent is not null 

SELECT *, (rollingsumvcn/population)*100 as rolliing_pctof_popvacinated
FROM #PercentPopVacinated


SELECT dth.continent, dth.location, dth.date, dth.population, CONVERT(BIGINT,vcn.people_fully_vaccinated) as fully_vac,(CONVERT(BIGINT,vcn.people_fully_vaccinated)/dth.population)*100 as full_vac_pcnt
From covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	and dth.date = vcn.date

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Examining Full Vaccination levels

-- Due to full vacination variable values having null values between reporting, I performed a forward fill to populate the previous reported number unitl an update was reported

CREATE View fully_vac as
SELECT
	continent,
	location
    ,date
    ,people_fully_vaccinated
    ,MAX(people_fully_vaccinated) OVER (PARTITION BY location, grouper) as forward_filled_fully_vac
FROM
    (
        SELECT
			continent,
            location
            ,date
            ,people_fully_vaccinated
            ,COUNT(people_fully_vaccinated) OVER (PARTITION BY location ORDER BY date) as grouper
        FROM
            covidvaccinations
    ) as grouped
ORDER BY location,date