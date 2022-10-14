-- =============================================
-- Author: Yahya Talab
-- Create date: 10/12/2022
-- Description:	Analysis Update on COVID-19 Worldwide
-- =============================================

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Below provides a quick detailed view of the 3 tables used

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
--Viewing the likelihood of dying from COVID-19 in different countries

--Code:
--Create View deathlikelihoodbycountry as

SELECT dth.continent, dth.location, dth.date, dth.total_cases, dth.total_deaths
,oth.[stringency_index] , oth.[median_age] ,oth.[aged_65_older] , oth.[aged_70_older], oth.[gdp_per_capita]
,oth.[extreme_poverty],oth.[population],oth.[population_density]
,(dth.total_deaths/dth.total_cases)*100 AS deathpercentage
From covid_analysis..coviddeaths dth
JOIN covid_analysis..covid_all_other oth
	ON dth.location = oth.location 
	AND dth.date = oth.date
WHERE dth.continent is not null
--WHERE location like '%states' 
--ORDER BY 1, 2

----------------------------------------------------------------------------------------------------------------------------------------------------------------

--Looking at total cases vs total population
--percent of population that contracted it

--Code:
--CREATE VIEW deaths_aspctof_pop AS
SELECT continent, location, date, population, total_cases
, (total_cases/population)*100 AS percent_pop_infected
, (total_deaths/population)*100 AS covid_deaths_pctofpop
FROM covid_analysis..coviddeaths
--WHERE location LIKE '%states' -- for examining the US specifically
--ORDER BY 1, 2

---------------------------------------------------------------------------------------------------------------------------------------------------------------

--Finding countries with highest infection rate compared to population

--Code:
--Create View maxinfectionratebycountry as
SELECT location, population, MAX(total_cases) AS highest_infect_ct,  MAX((total_cases/population))*100 AS max_percent_pop_infected
FROM covid_analysis..coviddeaths
WHERE continent IS NOT NULL -- to provide only countries
Group by location, population
--ORDER BY 4 DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Finding highest death count by country
-- Create max_percent_pop_dead as the amount of deaths reached as a percent of population

--Code:

SELECT location, population, MAX(cast(total_deaths AS int)) AS highest_death_ct, MAX((cast(total_deaths AS int)/population))*100 AS max_percent_pop_dead
FROM covid_analysis..coviddeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY 4 DESC 

----------------------------------------------------------------------------------------------------------------------------------------------------------------

--Finding highest percent of deaths by continent

-- Code:
-- Create View maxdeathpct_reached_by_country as
SELECT location, MAX(cast(total_deaths AS int)) AS Total_Death_ct, MAX((cast(total_deaths AS int)/population))*100 AS maxDead_as_percent_ofPop
FROM covid_analysis..coviddeaths
WHERE continent IS NULL AND location NOT LIKE '%income' AND location NOT LIKE 'International' 
GROUP BY location
ORDER BY Total_Death_ct DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Global numbers on total deaths, total cases, and deaths as a perc of cases

--Code:
--CREATE VIEW global_tot as
Select SUM(new_cases) AS  total_cases, SUM(cast(new_deaths AS bigint)) AS total_deaths, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
FROM covid_analysis..coviddeaths
WHERE continent IS NOT null 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Death rates grouped by country income levels 

--Code:
--CREATE VIEW income_lvl_deaths as
SELECT location,population, SUM(new_cases) AS  total_cases, SUM(cast(new_deaths as bigint)) as total_deaths, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
FROM covid_analysis..coviddeaths
WHERE continent IS NULL AND location  LIKE '%income'
GROUP BY continent,location, population
ORDER BY death_percentof_cases desc

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--Examining cases and deaths based on avg stringency levels of countries since the pandemic began

--Code:
--CREATE View stingency_lvls as
SELECT  location, population, AVG([stringency_index]) AS avg_string,SUM(new_cases) AS  total_cases, SUM(cast(new_deaths AS bigint)) AS total_deaths
FROM covid_analysis..covid_all_other
WHERE continent IS NOT null AND location NOT LIKE '%income' AND location NOT LIKE 'International' 
--WHERE continent IS NULL AND location  LIKE '%income'
GROUP BY location, population
ORDER BY avg_string DESC

----------------------------------------------------------------------------------------------------------------------------------------------------------------
--USE CTE Table to create rolling sum and percentage of people vaccinated 

--Rolling sum of first time vaccinations for nations willingness to vaccinate
Select dth.[continent], dth.[location], dth.[date], dth.population, vcn.[new_vaccinations]
, SUM(convert(bigint, vcn.[new_vaccinations])) OVER (Partition BY dth.location order by dth.location, dth.date) AS Vcn_rolling_sum
FROM covid_analysis..coviddeaths dth	
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location = vcn.location 
	and dth.date = vcn.date
WHERE dth.continent IS NOT null
ORDER BY 2,3

--USE CTE
--CREATE View rolling_vaccinations as
WITH PopVacTable (continent, location, date, population, new_vaccinations,vcn_rolling_sum)
AS 
(
select dth.continent, dth.location, dth.date, dth.population, vcn.new_people_vaccinated_smoothed
, SUM(CONVERT(bigint, vcn.new_people_vaccinated_smoothed)) OVER (partition by dth.location order by dth.location, dth.date) as vcn_rolling_sum
FROM covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	AND dth.date = vcn.date
--WHERE dth.continent is not null 
)

SELECT *, (vcn_rolling_sum/population)*100 as rolling_pcnt_ofvcn
FROM PopVacTable

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

INSERT INTO #PercentPopVacinated
SELECT dth.continent, dth.location, dth.date, dth.population, vcn.new_people_vaccinated_smoothed
, SUM(CONVERT(bigint, vcn.new_people_vaccinated_smoothed)) OVER (partition by dth.location order by dth.location, dth.date) as rollingsumvcn
FROM covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	and dth.date = vcn.date
WHERE dth.continent IS NOT null 

SELECT *, (rollingsumvcn/population)*100 AS rolliing_pctof_popvacinated
FROM #PercentPopVacinated


SELECT dth.continent, dth.location, dth.date, dth.population, CONVERT(BIGINT,vcn.people_fully_vaccinated) as fully_vac,(CONVERT(BIGINT,vcn.people_fully_vaccinated)/dth.population)*100 as full_vac_pcnt
FROM covid_analysis..coviddeaths dth
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location =vcn.location
	AND dth.date = vcn.date

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Examining Full Vaccination levels

-- Due to full vacination variable values having null values between reporting, I performed a forward fill to populate the previous reported number unitl an update was reported

CODE:
--CREATE View fully_vac_by_country as
SELECT
	continent
	,location
    ,date
    ,people_fully_vaccinated
    ,MAX(people_fully_vaccinated) OVER (PARTITION BY location, grouper) as forward_filled_fully_vac
FROM
    (
        SELECT
			continent
            ,location
            ,date
            ,people_fully_vaccinated
            ,COUNT(people_fully_vaccinated) OVER (PARTITION BY location ORDER BY date) AS grouper
        FROM
            covidvaccinations
    ) AS grouped
WHERE Continent IS NOT null
ORDER BY location,date


--CODE:
--CREATE View fully_vac_by_noncountry as
SELECT
	continent
	,location
    ,date
    ,people_fully_vaccinated
    ,MAX(people_fully_vaccinated) OVER (PARTITION BY location, grouper) as forward_filled_fully_vac
FROM
    (
        SELECT
			continent
            ,location
            ,date
            ,people_fully_vaccinated
            ,COUNT(people_fully_vaccinated) OVER (PARTITION BY location ORDER BY date) as grouper
        FROM
            covidvaccinations
    ) AS grouped
WHERE Continent IS null AND location NOT LIKE 'international'
ORDER BY location,date

-- This concludes the SQL Project
