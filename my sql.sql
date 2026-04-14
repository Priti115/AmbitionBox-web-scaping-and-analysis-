CREATE DATABASE company_analysis;
USE company_analysis;

CREATE TABLE companies (
    id INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(255),
    Rating FLOAT,
    Headquarters VARCHAR(255),
    Company_year INT,
    Employees_Count INT,
    RatingCount INT,
    Country VARCHAR(100)
);
SELECT * FROM companies;

-- 1. Which companies demonstrate the best combination of high employee strength and high ratings, indicating strong internal culture and scalability?

SELECT * FROM companies
ORDER BY Rating DESC, RatingCount desc;
        -- so here we can clearly seen that  Marpu Foundation and Tekwissen has more retings 4.9 each with ratingsCount of 3100 and 1900 respectivly 
		-- They are seems to be StartUP havig employees 200 and 500 -- 

SELECT * FROM companies
Where RatingCount >= 10000
ORDER BY Rating DESC, RatingCount desc
LIMIT 5;
		-- Now we can conclude that there are some companies with good ratings and Rating Counts They are :
		-- Muthoot FinCorp , Jio, Tata Motors having rating more than 4 and having Rating Counts more than 13000 
		-- Also Jio having 4.4 rating with 33600. These all companies are india based companies 

-- 2. Identify companies that are highly rated but have very low rating counts, and evaluate whether these ratings may be unreliable or biased.

SELECT * FROM companies
ORDER BY Rating DESC, RatingCount asc;
		-- Its now clear that there are some companies having high rating with very low rating count 
		-- These companies like  Sistema Shyam Teleservices (4.9 with 180 sample), Cadworks India (4.9 with 182 sample, employees ; 200)

-- 3. Which countries have the highest average company ratings, and how does company size distribution vary across these countries? 	
SELECT  
    LOWER(TRIM(Country)) AS Country,
    
    CASE 
        WHEN Employees_Count > 2000 THEN 'Large'
        WHEN Employees_Count > 300 THEN 'Mid size'
        ELSE 'Startup/Small'
    END AS company_size,
    
    ROUND(AVG(Rating), 2) AS AverageRating

FROM companies

GROUP BY LOWER(TRIM(Country)), company_size
ORDER BY AverageRating desc;

     -- Top-rated companies are distributed across diverse regions including South Africa, the US, and Canada, with both large enterprises and 
     -- startups achieving high ratings. Mid-size companies show consistent performance globally. However, analysis revealed inconsistencies in 
	 -- geographical data (mix of cities and countries), highlighting the importance of data normalization for accurate regional insights. 

