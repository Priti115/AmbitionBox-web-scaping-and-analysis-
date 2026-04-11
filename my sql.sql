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

-- 1. Top 5 Companies (High Rating + High Trust) 

SELECT * FROM companies
ORDER BY Rating DESC, RatingCount desc
LIMIT 5;
-- so here we can clearly seen that  

