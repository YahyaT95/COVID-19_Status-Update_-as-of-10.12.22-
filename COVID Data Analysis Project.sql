-- =============================================
-- Author:		Yahya Talab
-- Create date: 10/12/2022
-- Description:	Analysis on current state of COVID-19 Worldwide and in the US
-- =============================================

-- Below provide a quick view of the 3 tables used

SELECT *
FROM covid_analysis..coviddeaths
WHERE continent IS NOT NULL
ORDER BY 3,4

SELECT * 
FROM covid_analysis..covidvaccinations
WHERE continent IS NOT NULL
ORDER BY 3 ,4

--SELECT * 
--FROM covid_analysis..covidvaccinations
--ORDER BY 3 DESC,4 DESC

SELECT Location, date, total_cases, new_cases, total_deaths, population 
FROM covid_analysis..coviddeaths
WHERE continent IS NOT NULL

--Creating a table to examine total cases vs total deaths 
--Viewing the likelihood of dying from covid
--note: variables for age and income were included for further analysis in Tableau

--creating the view
Create View deathlikelihoodbycountry as

--designing the table for the view
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



--Looking at total cases vs total population
--percent of population that contracted it

SELECT location, date, population, total_cases,  (total_cases/population)*100 AS percent_pop_infected, (total_deaths/population)*100 AS percent_pop_dead
From covid_analysis..coviddeaths
Where location like '%states' 
order by 1, 2

--Finding countries with highest infection rate compared to population
SELECT location, population, MAX(total_cases) as highest_infect_ct,  MAX((total_cases/population))*100 AS max_percent_pop_infected 
From covid_analysis..coviddeaths
Group by location, population
WHERE continent IS NOT NULL
order by 4 DESC

-- finding highest death count
SELECT location, population, MAX(cast(total_deaths as int)) as highest_death_ct, MAX((cast(total_deaths as int)/population))*100 AS max_percent_pop_dead
From covid_analysis..coviddeaths
WHERE continent IS NOT NULL
Group by location, population
order by 4 DESC 

--breaking down by continent
SELECT continent, MAX(cast(total_deaths as int)) as Total_Death_ct, MAX((cast(total_deaths as int)/population))*100 AS maxDead_as_percent_ofPop
FROM covid_analysis..coviddeaths
WHERE continent is not null 
--AND location not like '%income' AND location not like 'International' AND location not like 'World'
GROUP BY continent
ORDER BY Total_Death_ct desc

--CORRECTED breaking down by continent
SELECT location, MAX(cast(total_deaths as int)) as Total_Death_ct, MAX((cast(total_deaths as int)/population))*100 AS maxDead_as_percent_ofPop
FROM covid_analysis..coviddeaths
WHERE continent is null -- AND location not like '%income' AND location not like 'International' AND location not like 'World'
GROUP BY location
ORDER BY Total_Death_ct desc

--Global numbers
Select SUM(new_cases) as  total_cases, SUM(cast(new_deaths as bigint)) as total_deaths, SUM(cast(new_deaths AS int))/SUM(new_cases)*100 AS death_percentof_cases
From covid_analysis..coviddeaths
Where continent is not null
order by 1,2 

--by income levels MY contributions
SELECT continent, location, sum(cast(new_deaths as bigint))
from covid_analysis..coviddeaths
WHERE continent is null
Group BY continent,location


Select dth.[continent], dth.[location], dth.[date], dth.population, vcn.[new_vaccinations]
, SUM(convert(bigint, vcn.[new_vaccinations])) OVER (Partition BY dth.location order by dth.location, dth.date) as Vcn_rolling_sum
From covid_analysis..coviddeaths dth	
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location = vcn.location 
	and dth.date = vcn.date
WHERE dth.continent is not null
Order by 2,3

--USE CTE

WITH popVacTable (continent, location, date, population, new_vaccinations,vcn_rolling_sum)
as 
(
Select dth.[continent], dth.[location], dth.[date], dth.population, vcn.[new_vaccinations]
, SUM(convert(bigint, vcn.[new_vaccinations])) OVER (Partition BY dth.location order by dth.location, dth.date) as vcn_rolling_sum
From covid_analysis..coviddeaths dth	
JOIN covid_analysis..covidvaccinations vcn
	ON dth.location = vcn.location 
	and dth.date = vcn.date
WHERE dth.continent is not null
)
SELECT *, --(vcn_rolling_sum/population)*100 as rolling_pcnt_ofvcn
From popVacTable

-- TEMP Table on percent vaccinated Note: used new_people_vaccinated_smoothed to show Daily number of people receiving their first vaccine dose (7-day smoothed)
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

SELECT *, (rollingsumvcn/population)*100 as rolliing_sumof_popvacinated
FROM #PercentPopVacinated

CREATE VIEW 
