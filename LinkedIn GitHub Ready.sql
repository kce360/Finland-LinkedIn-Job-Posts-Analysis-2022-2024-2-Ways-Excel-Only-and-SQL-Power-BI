CREATE TABLE LinkedInJobsCombined (
    applicationsCount VARCHAR(100),
    companyId INT,
    companyName VARCHAR(255),
    companyUrl VARCHAR(255),
    contractType VARCHAR(50),
    description TEXT,
    experienceLevel VARCHAR(50),
    jobUrl VARCHAR(500),
    location VARCHAR(255),
    postedTime VARCHAR(255),
    publishedAt DATETIME,
    sector VARCHAR(255),
    title VARCHAR(255),
    workType VARCHAR(255),
    workArrangement VARCHAR(50)
);
--populate with the data from all table using UNION ALL
INSERT INTO LinkedInJobsCombined (
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    publishedAt,
    sector,
    title,
    workType,
    workArrangement
)
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime, 
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Finland_hybrid]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Finland_no_work_arr]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Finland_on-site]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Finland_Remote]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Suomi_hybrid]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Suomi_no_work_arr]
UNION ALL
SELECT 
    applicationsCount,
    companyId,
    companyName,
    companyUrl,
    contractType,
    description,
    experienceLevel,
    jobUrl,
    location,
    postedTime,
    TRY_CONVERT(DATETIME, publishedAt, 120) AS publishedAt,
    sector,
    title,
    workType,
    workArrangement
FROM [dbo].[LinkedIn_Suomi_on-site];

--1263 or less rows should be in the final query
SELECT DISTINCT jobUrl
FROM LinkedInJobsCombined;

/* Data Cleaning*/

-- Add a new column to mark duplicates
ALTER TABLE LinkedInJobsCombined ADD IsDuplicate VARCHAR(10);

-- Update the IsDuplicate column to mark duplicates
WITH DuplicateJobs AS (
    SELECT jobUrl, COUNT(*) AS cnt
    FROM LinkedInJobsCombined
    GROUP BY jobUrl
    HAVING COUNT(*) > 1
)
UPDATE LinkedInJobsCombined
SET IsDuplicate = 'Duplicate'
FROM LinkedInJobsCombined lj
JOIN DuplicateJobs dj ON lj.jobUrl = dj.jobUrl;

-- Add a new column to mark rows for deletion
ALTER TABLE LinkedInJobsCombined ADD MarkForDeletion VARCHAR(10);

-- Update the MarkForDeletion column to remove 'unknown' work arrangement if the duplicate has other value
UPDATE LinkedInJobsCombined
SET MarkForDeletion = 'Delete'
WHERE IsDuplicate = 'Duplicate'
AND workArrangement = 'unknown'
AND EXISTS (
    SELECT 1
    FROM LinkedInJobsCombined lj2
    WHERE lj2.jobUrl = LinkedInJobsCombined.jobUrl
    AND lj2.workArrangement <> 'unknown'
);
-- check what we got
SELECT *
FROM LinkedInJobsCombined
ORDER BY location;

-- remove duplicates (1268 rows left)
DELETE FROM LinkedInJobsCombined
WHERE IsDuplicate = 'Duplicate'
AND workArrangement = 'unknown'
AND MarkForDeletion = 'Delete';

-- Remove Companies Without companyId and companyURL (-3 rows, 1265 left)
SELECT * FROM LinkedInJobsCombined
WHERE companyId IS NULL OR companyURL IS NULL;

DELETE FROM LinkedInJobsCombined
WHERE companyId IS NULL OR companyURL IS NULL;

-- check for the complete duplicates
SELECT jobUrl, workArrangement, title, isDuplicate, COUNT(*) 
FROM LinkedInJobsCombined
GROUP BY jobUrl, workArrangement, title, isDuplicate
HAVING COUNT(*) > 1;

-- Delete duplicates (keep only one row per jobUrl)
WITH CTE AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY jobUrl ORDER BY title) AS rn
    FROM LinkedInJobsCombined
)
DELETE FROM CTE WHERE rn > 1;
  
-- delete companies where the job description has a different location than Finland/Nordics
DELETE FROM LinkedInJobsCombined
WHERE jobUrl IN (
    'https://fi.linkedin.com/jobs/view/transportation-clerk-at-canada-cartage-3940053796?trk=public_jobs_topcard-title',
    'https://fi.linkedin.com/jobs/view/seo-content-producer-at-tui-3934712786?trk=public_jobs_topcard-title',
	'https://fi.linkedin.com/jobs/view/directeur-g%C3%A9n%C3%A9ral-des-services-pour-la-ville-de-bischwiller-directeur-g%C3%A9n%C3%A9ral-adjoint-de-la-communaut%C3%A9-d%E2%80%99agglom%C3%A9ration-de-haguenau-f-h-at-emploi-public-3904649541?trk=public_jobs_topcard-title'
);
/*  Removing duplicates is complete 1257 rows left */


/**Fix date format errors*/
ALTER TABLE LinkedInJobsCombined
ADD formattedPublishedAt2 VARCHAR(12);

UPDATE LinkedInJobsCombined
SET formattedPublishedAt2 =   RIGHT('0' + CONVERT(VARCHAR, DAY(publishedAt)), 2) + '-' +
    RIGHT('0' + CONVERT(VARCHAR, MONTH(publishedAt)), 2) + '-' +
    CONVERT(VARCHAR, YEAR(publishedAt));

/* Populating the missing values*/

-- Populate publishedAt column with the date based on all vacancies posted 23 hours ago or later – 01-06-2024 (the day the dataset was scrapped)
UPDATE LinkedInJobsCombined
SET publishedAt = '2024-06-01'
WHERE publishedAt IS NULL;

--Fixing my mistake in date
UPDATE LinkedInJobsCombined
SET publishedAt = '2024-01-06'
WHERE publishedAt = '2024-06-01';


-- Add new columns for Year and Month
ALTER TABLE LinkedInJobsCombined ADD Year INT, Month VARCHAR(20);

-- Set the languge to avoid formatting errors
SET LANGUAGE English;


/* Populating Regions based on location column*/

-- Alter the table to add the regionFormatted column
ALTER TABLE LinkedInJobsCombined ADD regionFormatted NVARCHAR(255);

-- Ppopulate regionFormatted with data fron the table 'regions' based on the first value befor comma in the location 
UPDATE LinkedInJobsCombined
SET regionFormatted = reg.admin_name
FROM LinkedInJobsCombined
JOIN regions AS reg
ON LinkedInJobsCombined.location LIKE reg.city + '%';

-- Check where the region is still missing
SELECT location, regionFormatted, workArrangement
FROM LinkedInJobsCombined
WHERE regionFormatted is Null
ORDER BY location;

-- update remote jobs
UPDATE LinkedInJobsCombined
SET regionFormatted = 'Anywhere in Finland'
WHERE location = 'Finland' and regionFormatted IS NULL AND workArrangement = 'Remote';

-- check what has left
SELECT DISTINCT location, regionFormatted
FROM LinkedInJobsCombined
WHERE regionFormatted is Null;

--populate the missing values
UPDATE LinkedInJobsCombined
SET regionFormatted = CASE
    WHEN location = 'Central Finland' THEN 'Keski-Suomi'
    WHEN location = 'Ekenäs, Uusimaa, Finland' THEN 'Uusimaa'
    WHEN location = 'Finland' THEN 'Anywhere in Finland'
    WHEN location = 'European Union' THEN 'Anywhere in Finland'
    WHEN location = 'Greater Lahti Area' THEN 'Päijät-Häme'
    WHEN location = 'Kainuu, Finland' THEN 'Kainuu'
    WHEN location = 'Kallo, Lapland, Finland' THEN 'Lappi'
    WHEN location = 'Kymenlaakso, Finland' THEN 'Kymenlaakso'
    WHEN location = 'Lapland, Finland' THEN 'Lappi'
    WHEN location = 'Nordics' THEN 'Anywhere in Finland'
    WHEN location = 'North Karelia, Finland' THEN 'Pohjois-Karjala'
    WHEN location = 'North Ostrobothnia, Finland' THEN 'Pohjois-Pohjanmaa'
    WHEN location = 'Northern Savonia, Finland' THEN 'Pohjois-Savo'
    WHEN location = 'Päijät-Häme, Finland' THEN 'Päijät-Häme'
    WHEN location = 'Pirkanmaa, Finland' THEN 'Pirkanmaa'
    WHEN location = 'Saariselkä, Lapland, Finland' THEN 'Lappi'
    WHEN location = 'Saija, Lapland, Finland' THEN 'Lappi'
    WHEN location = 'Satakunta, Finland' THEN 'Satakunta'
    WHEN location = 'South Karelia, Finland' THEN 'Etelä-Karjala'
    WHEN location = 'South Ostrobothnia, Finland' THEN 'Etelä-Pohjanmaa'
    WHEN location = 'South Savo, Finland' THEN 'Etelä-Savo'
    WHEN location = 'Southwest Finland, Finland' THEN 'Varsinais-Suomi'
    WHEN location = 'Sydösterbotten sub-region, Ostrobothnia, Finland' THEN 'Pohjanmaa'
    WHEN location = 'Tuuri, South Ostrobothnia, Finland' THEN 'Etelä-Pohjanmaa'
    WHEN location = 'Uusimaa, Finland' THEN 'Uusimaa'
    WHEN location = 'Vehmaan kirkonkylä, Southwest Finland, Finland' THEN 'Varsinais-Suomi'
    ELSE 'unknown'
END
WHERE regionFormatted IS NULL;

-- add a missing row in the previos query
UPDATE LinkedInJobsCombined
SET regionFormatted = CASE
    WHEN location = 'Central Finland, Finland' THEN 'Keski-Suomi'
    ELSE 'unknown'
END
WHERE regionFormatted = 'unknown';

/*Populating Sector*/

SELECT * FROM LinkedInJobsCombined;

-- Alter the table to add the sectorGlobal column
ALTER TABLE LinkedInJobsCombined ADD sectorGlobal NVARCHAR(255);

-- Ppopulate sectorGlobal with data fron the table 'sector_global' 

---check before updatinh
SELECT ljc.jobUrl, ljc.sector, sg.SectorGlobal
FROM LinkedInJobsCombined ljc
JOIN sector_global sg
ON ljc.sector = sg.sector;

-- update
UPDATE LinkedInJobsCombined
SET sectorGlobal = sg.SectorGlobal
FROM LinkedInJobsCombined
JOIN sector_global AS sg
ON LinkedInJobsCombined.sector = sg.sector;

-- check for missing values
SELECT *
FROM LinkedInJobsCombined
WHERE sectorGlobal is NULL;

-- updating the missing values based on job and title descriptions
UPDATE LinkedInJobsCombined
SET sectorGlobal = 
    CASE 
        WHEN companyName = 'HappySignals Ltd' THEN 'Information Technology'
        WHEN companyName = 'Leader YHYRES' THEN 'Financial Services'
        WHEN companyName = 'Gren' THEN 'Renewable Energy'
        WHEN companyName = 'Keski-Suomen hyvinvointialue' THEN 'Hospitals and Health Care'
        WHEN companyName = 'FIID' THEN 'Marketing Services'
        WHEN companyName = 'Lakihelppi' THEN 'Legal Services'
        WHEN companyName = 'HR Legal Services Oy' THEN 'Human Resources'
        WHEN companyName = 'Eurofins Electric & Electronics Finland Oy' THEN 'Information Technology'
        ELSE sectorGlobal  
    END
WHERE sectorGlobal IS NULL;

/*Transofming the Application Count*/
SELECT *,
    CASE
        WHEN applicationsCount = 'Be among the first 25 applicants' THEN 25
        WHEN applicationsCount = 'Over 200 applicants' THEN 201
        ELSE CAST(LEFT(applicationsCount, CHARINDEX(' ', applicationsCount) - 1) AS INT)
    END AS applicationsCountCleaned
FROM LinkedInJobsCombined;

-- create a column for it
ALTER TABLE LinkedInJobsCombined
ADD applicationsCountCleaned INT;

--update the table with transofrmed data
UPDATE LinkedInJobsCombined
SET applicationsCountCleaned = 
    CASE 
        WHEN applicationsCount = 'Be among the first 25 applicants' THEN 25
        WHEN applicationsCount = 'Over 200 applicants' THEN 201
        ELSE CAST(LEFT(applicationsCount, CHARINDEX(' ', applicationsCount) - 1) AS INT)
    END;

/** Data and Data/Analyst keyword mentions count*/

-- Add a new column for data keyword presence in the job description
ALTER TABLE LinkedInJobsCombined ADD dataCount VARCHAR(10);

-- Update the column
UPDATE LinkedInJobsCombined
SET dataCount = CASE
    WHEN CHARINDEX('data', description) > 0 THEN 'yes'
    ELSE 'no'
END;

SELECT *
FROM LinkedInJobsCombined;

-- Add a new column for data/analyst keyword presence in the job titles
ALTER TABLE LinkedInJobsCombined ADD dataTitleCount VARCHAR(10);

-- Update the column
UPDATE LinkedInJobsCombined
SET dataTitleCount = CASE
    WHEN CHARINDEX('data', title) > 0 OR CHARINDEX('analyst', title) > 0 THEN 'yes'
    ELSE 'no'
END;


/*Fixing one global sector for the one specific company from Design -> IT */

UPDATE LinkedInJobsCombined
SET sectorGlobal = 'Information Technology'
WHERE jobUrl = 'https://fi.linkedin.com/jobs/view/cloud-architect-at-interex-group-3732290254?trk=public_jobs_topcard-title';


/** Preparing query for PowerBI **/

SELECT companyId, companyName, companyUrl, contractType, 
description, experienceLevel, jobUrl, publishedAt, title, workType, workArrangement,
regionFormatted, sectorGlobal, applicationsCountCleaned, dataCount, dataTitleCount,
CONVERT(DATE, formattedPublishedAt2, 105) AS formattedPublishedAt2Date
FROM LinkedInJobsCombined


