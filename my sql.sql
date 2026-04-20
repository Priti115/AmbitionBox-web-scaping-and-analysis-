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

/* 4. Which companies are the most reliably top-rated within each country when adjusting for review volume bias, 
and who are the top 5 companies per country based on credibility-adjusted rankings?  */
WITH global_stats AS (
    SELECT
        AVG(Rating) AS global_avg_rating,
        AVG(RatingCount) AS min_votes_threshold
    FROM companies
    WHERE Rating IS NOT NULL
      AND RatingCount IS NOT NULL
),
scored_companies AS (
    SELECT
        c.Name,
        c.Country,
        c.Rating,
        c.RatingCount,
        ROUND(
            (
                (c.RatingCount / NULLIF(c.RatingCount + gs.min_votes_threshold, 0)) * c.Rating
            ) +
            (
                (gs.min_votes_threshold / NULLIF(c.RatingCount + gs.min_votes_threshold, 0)) * gs.global_avg_rating
            ),
            3
        ) AS credibility_score
    FROM companies c
    CROSS JOIN global_stats gs
    WHERE c.Rating IS NOT NULL
      AND c.RatingCount IS NOT NULL
),
ranked_companies AS (
    SELECT
        Name,
        Country,
        Rating,
        RatingCount,
        credibility_score,
        RANK() OVER (
            PARTITION BY Country
            ORDER BY credibility_score DESC, RatingCount DESC, Name ASC
        ) AS country_rank
    FROM scored_companies
)
SELECT
    Country,
    Name,
    Rating,
    RatingCount,
    credibility_score,
    country_rank
FROM ranked_companies
WHERE country_rank <= 5
ORDER BY Country, country_rank, credibility_score DESC;


/*
5. Identify companies that have strong ratings but are under-recognized because their RatingCount is below the country median. 
Compare them with popular leaders that are also highly rated but have RatingCount at or above the country median. 
Classify each company as Hidden Leader, Popular Leader, or Average Performer within its country. */

WITH base_companies AS (
    SELECT
        Name,
        Country,
        Rating,
        RatingCount
    FROM companies
    WHERE Rating IS NOT NULL
      AND RatingCount IS NOT NULL
),
review_distribution AS (
    SELECT
        Name,
        Country,
        Rating,
        RatingCount,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY RatingCount
        ) AS review_rn,
        COUNT(*) OVER (
            PARTITION BY Country
        ) AS country_company_count,
        NTILE(4) OVER (
            PARTITION BY Country
            ORDER BY Rating DESC, RatingCount DESC
        ) AS rating_quartile
    FROM base_companies
),
country_review_median AS (
    SELECT
        Country,
        AVG(RatingCount) AS median_ratingcount
    FROM review_distribution
    WHERE review_rn IN (
        FLOOR((country_company_count + 1) / 2),
        FLOOR((country_company_count + 2) / 2)
    )
    GROUP BY Country
),
classified_companies AS (
    SELECT
        rd.Name,
        rd.Country,
        rd.Rating,
        rd.RatingCount,
        crm.median_ratingcount,
        CASE
            WHEN rd.rating_quartile = 1
                 AND rd.RatingCount < crm.median_ratingcount
                THEN 'Hidden Leader'
            WHEN rd.rating_quartile = 1
                 AND rd.RatingCount >= crm.median_ratingcount
                THEN 'Popular Leader'
            ELSE 'Average Performer'
        END AS performance_group,
        ROUND(crm.median_ratingcount - rd.RatingCount, 2) AS review_gap_to_median
    FROM review_distribution rd
    JOIN country_review_median crm
      ON rd.Country = crm.Country
),
ranked_companies AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Country, performance_group
            ORDER BY Rating DESC, RatingCount DESC, Name ASC
        ) AS segment_rank
    FROM classified_companies
)
SELECT
    Country,
    Name,
    Rating,
    RatingCount,
    median_ratingcount,
    performance_group,
    review_gap_to_median,
    segment_rank
FROM ranked_companies
ORDER BY
    Country,
    FIELD(performance_group, 'Hidden Leader', 'Popular Leader', 'Average Performer'),
    segment_rank;
    

/*
6. Create age buckets from Company_Year such as Startup, Growth, Established, and Legacy. Within each Country, 
evaluate which age segment is strongest based on average rating and average employee count. Use CTEs and DENSE_RANK() to 
rank the age segments and identify the top-performing age segment in each country. */

WITH company_age_segments AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        Company_Year,
        YEAR(CURDATE()) - Company_Year AS company_age,
        CASE
            WHEN YEAR(CURDATE()) - Company_Year BETWEEN 0 AND 5 THEN 'Startup'
            WHEN YEAR(CURDATE()) - Company_Year BETWEEN 6 AND 15 THEN 'Growth'
            WHEN YEAR(CURDATE()) - Company_Year BETWEEN 16 AND 30 THEN 'Established'
            ELSE 'Legacy'
        END AS age_segment
    FROM companies
    WHERE Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
      AND Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
),
segment_performance AS (
    SELECT
        Country,
        age_segment,
        COUNT(*) AS company_count,
        ROUND(AVG(company_age), 1) AS avg_company_age,
        ROUND(AVG(Rating), 3) AS avg_rating,
        ROUND(AVG(Employees_Count), 0) AS avg_employees
    FROM company_age_segments
    GROUP BY Country, age_segment
),
scored_segments AS (
    SELECT
        Country,
        age_segment,
        company_count,
        avg_company_age,
        avg_rating,
        avg_employees,
        ROUND(
            0.70 * COALESCE(
                (
                    (avg_rating - MIN(avg_rating) OVER (PARTITION BY Country)) /
                    NULLIF(
                        MAX(avg_rating) OVER (PARTITION BY Country) -
                        MIN(avg_rating) OVER (PARTITION BY Country),
                        0
                    )
                ),
                0
            )
            +
            0.30 * COALESCE(
                (
                    (avg_employees - MIN(avg_employees) OVER (PARTITION BY Country)) /
                    NULLIF(
                        MAX(avg_employees) OVER (PARTITION BY Country) -
                        MIN(avg_employees) OVER (PARTITION BY Country),
                        0
                    )
                ),
                0
            ),
            4
        ) AS segment_strength_score
    FROM segment_performance
),
ranked_segments AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY Country
            ORDER BY segment_strength_score DESC, avg_rating DESC, avg_employees DESC
        ) AS segment_rank
    FROM scored_segments
)
SELECT
    Country,
    age_segment,
    company_count,
    avg_company_age,
    avg_rating,
    avg_employees,
    segment_strength_score,
    segment_rank
FROM ranked_segments
ORDER BY Country, segment_rank, age_segment;


/*
7. Segment companies into Small, Mid, and Large based on Employees_Count and identify companies
whose Rating is at least 0.50 points above their size-segment average. Return the top 3
overperformers in each size segment using ROW_NUMBER().
*/

WITH size_buckets AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        NTILE(3) OVER (ORDER BY Employees_Count) AS size_bucket_no
    FROM companies
    WHERE Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
),
labeled_sizes AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        CASE
            WHEN size_bucket_no = 1 THEN 'Small'
            WHEN size_bucket_no = 2 THEN 'Mid'
            ELSE 'Large'
        END AS size_segment
    FROM size_buckets
),
segment_benchmarks AS (
    SELECT
        size_segment,
        ROUND(AVG(Rating), 3) AS segment_avg_rating,
        ROUND(AVG(Employees_Count), 0) AS segment_avg_employees
    FROM labeled_sizes
    GROUP BY size_segment
),
overperformers AS (
    SELECT
        ls.Name,
        ls.Country,
        ls.size_segment,
        ls.Rating,
        ls.Employees_Count,
        sb.segment_avg_rating,
        ROUND(ls.Rating - sb.segment_avg_rating, 3) AS rating_lift
    FROM labeled_sizes ls
    JOIN segment_benchmarks sb
      ON ls.size_segment = sb.size_segment
    WHERE ls.Rating >= sb.segment_avg_rating + 0.50
),
ranked_companies AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY size_segment
            ORDER BY rating_lift DESC, Rating DESC, Employees_Count DESC, Name ASC
        ) AS segment_rank
    FROM overperformers
)
SELECT
    size_segment,
    Name,
    Country,
    Rating,
    Employees_Count,
    segment_avg_rating,
    rating_lift,
    segment_rank
FROM ranked_companies
WHERE segment_rank <= 3
ORDER BY size_segment, segment_rank;


/*
8. Detect whether top ratings may be biased by low review volume. Compare the average Rating
of the top 10% most-reviewed companies versus the bottom 10% least-reviewed companies
within each Country, and rank countries by the size of this bias gap.
*/

WITH review_volume_deciles AS (
    SELECT
        Name,
        Country,
        Rating,
        RatingCount,
        NTILE(10) OVER (
            PARTITION BY Country
            ORDER BY RatingCount DESC
        ) AS most_reviewed_decile,
        NTILE(10) OVER (
            PARTITION BY Country
            ORDER BY RatingCount ASC
        ) AS least_reviewed_decile
    FROM companies
    WHERE Rating IS NOT NULL
      AND RatingCount IS NOT NULL
),
extreme_groups AS (
    SELECT
        Country,
        Rating,
        RatingCount,
        CASE
            WHEN most_reviewed_decile = 1 THEN 'Most Reviewed 10%'
            WHEN least_reviewed_decile = 1 THEN 'Least Reviewed 10%'
        END AS review_group
    FROM review_volume_deciles
    WHERE most_reviewed_decile = 1
       OR least_reviewed_decile = 1
),
country_bias_summary AS (
    SELECT
        Country,
        COUNT(CASE WHEN review_group = 'Most Reviewed 10%' THEN 1 END) AS most_reviewed_company_count,
        COUNT(CASE WHEN review_group = 'Least Reviewed 10%' THEN 1 END) AS least_reviewed_company_count,
        ROUND(AVG(CASE WHEN review_group = 'Most Reviewed 10%' THEN Rating END), 3) AS avg_rating_most_reviewed,
        ROUND(AVG(CASE WHEN review_group = 'Least Reviewed 10%' THEN Rating END), 3) AS avg_rating_least_reviewed,
        ROUND(AVG(CASE WHEN review_group = 'Most Reviewed 10%' THEN RatingCount END), 0) AS avg_ratingcount_most_reviewed,
        ROUND(AVG(CASE WHEN review_group = 'Least Reviewed 10%' THEN RatingCount END), 0) AS avg_ratingcount_least_reviewed
    FROM extreme_groups
    GROUP BY Country
),
ranked_bias AS (
    SELECT
        *,
        ROUND(avg_rating_least_reviewed - avg_rating_most_reviewed, 3) AS rating_bias_gap,
        CASE
            WHEN avg_rating_least_reviewed > avg_rating_most_reviewed
                THEN 'Possible positive bias in low-volume reviews'
            WHEN avg_rating_least_reviewed < avg_rating_most_reviewed
                THEN 'High-volume companies are rated better'
            ELSE 'No visible bias gap'
        END AS bias_interpretation,
        DENSE_RANK() OVER (
            ORDER BY ABS(avg_rating_least_reviewed - avg_rating_most_reviewed) DESC
        ) AS bias_rank
    FROM country_bias_summary
)
SELECT
    Country,
    most_reviewed_company_count,
    least_reviewed_company_count,
    avg_rating_most_reviewed,
    avg_rating_least_reviewed,
    avg_ratingcount_most_reviewed,
    avg_ratingcount_least_reviewed,
    rating_bias_gap,
    bias_interpretation,
    bias_rank
FROM ranked_bias
ORDER BY bias_rank, Country;


/*
9. Build a competitive intensity score for each Country using number of companies, average rating,
average employee count, and average company age. Normalize each metric, combine them into
a weighted score, and rank countries using DENSE_RANK().
*/

WITH country_metrics AS (
    SELECT
        Country,
        COUNT(*) AS company_count,
        ROUND(AVG(Rating), 3) AS avg_rating,
        ROUND(AVG(Employees_Count), 0) AS avg_employees,
        ROUND(AVG(YEAR(CURDATE()) - Company_Year), 1) AS avg_company_age
    FROM companies
    WHERE Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
      AND Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
    GROUP BY Country
),
normalized_metrics AS (
    SELECT
        Country,
        company_count,
        avg_rating,
        avg_employees,
        avg_company_age,
        COALESCE(
            (company_count - MIN(company_count) OVER ()) /
            NULLIF(MAX(company_count) OVER () - MIN(company_count) OVER (), 0),
            0
        ) AS company_count_score,
        COALESCE(
            (avg_rating - MIN(avg_rating) OVER ()) /
            NULLIF(MAX(avg_rating) OVER () - MIN(avg_rating) OVER (), 0),
            0
        ) AS rating_score,
        COALESCE(
            (avg_employees - MIN(avg_employees) OVER ()) /
            NULLIF(MAX(avg_employees) OVER () - MIN(avg_employees) OVER (), 0),
            0
        ) AS employee_score,
        COALESCE(
            (avg_company_age - MIN(avg_company_age) OVER ()) /
            NULLIF(MAX(avg_company_age) OVER () - MIN(avg_company_age) OVER (), 0),
            0
        ) AS age_score
    FROM country_metrics
),
scored_countries AS (
    SELECT
        *,
        ROUND(
            (0.35 * company_count_score) +
            (0.30 * rating_score) +
            (0.20 * employee_score) +
            (0.15 * age_score),
            4
        ) AS competitive_intensity_score
    FROM normalized_metrics
),
ranked_countries AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY competitive_intensity_score DESC, avg_rating DESC, company_count DESC
        ) AS competitive_rank
    FROM scored_countries
)
SELECT
    Country,
    company_count,
    avg_rating,
    avg_employees,
    avg_company_age,
    competitive_intensity_score,
    competitive_rank
FROM ranked_countries
ORDER BY competitive_rank, Country;

 
 /*
10. Find companies that are older than their Country's median company age but have ratings below
their Country's average rating. Rank the most underperforming mature companies by rating gap.
*/

WITH company_ages AS (
    SELECT
        Name,
        Country,
        Rating,
        Company_Year,
        YEAR(CURDATE()) - Company_Year AS company_age
    FROM companies
    WHERE Rating IS NOT NULL
      AND Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
),
age_ordering AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY company_age
        ) AS age_rn,
        COUNT(*) OVER (
            PARTITION BY Country
        ) AS country_company_count
    FROM company_ages
),
country_median_age AS (
    SELECT
        Country,
        AVG(company_age) AS median_company_age
    FROM age_ordering
    WHERE age_rn IN (
        FLOOR((country_company_count + 1) / 2),
        FLOOR((country_company_count + 2) / 2)
    )
    GROUP BY Country
),
country_rating_benchmark AS (
    SELECT
        Country,
        AVG(Rating) AS country_avg_rating
    FROM company_ages
    GROUP BY Country
),
mature_underperformers AS (
    SELECT
        ca.Name,
        ca.Country,
        ca.company_age,
        ca.Rating,
        cma.median_company_age,
        crb.country_avg_rating,
        ROUND(crb.country_avg_rating - ca.Rating, 3) AS rating_gap
    FROM company_ages ca
    JOIN country_median_age cma
      ON ca.Country = cma.Country
    JOIN country_rating_benchmark crb
      ON ca.Country = crb.Country
    WHERE ca.company_age > cma.median_company_age
      AND ca.Rating < crb.country_avg_rating
),
ranked_companies AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY Country
            ORDER BY rating_gap DESC, company_age DESC, Name ASC
        ) AS underperformance_rank
    FROM mature_underperformers
)
SELECT
    Country,
    Name,
    company_age,
    median_company_age,
    Rating,
    country_avg_rating,
    rating_gap,
    underperformance_rank
FROM ranked_companies
ORDER BY Country, underperformance_rank;


/*
11. Identify young companies founded within the last 10 years that already have above-country-average
Employees_Count and above-country-average Rating. Return the top 3 emerging employers per Country using ROW_NUMBER().
*/

WITH base_companies AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        Company_Year,
        YEAR(CURDATE()) - Company_Year AS company_age
    FROM companies
    WHERE Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
      AND Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
),
country_benchmarks AS (
    SELECT
        Country,
        AVG(Rating) AS country_avg_rating,
        AVG(Employees_Count) AS country_avg_employees
    FROM base_companies
    GROUP BY Country
),
emerging_candidates AS (
    SELECT
        bc.Name,
        bc.Country,
        bc.Rating,
        bc.Employees_Count,
        bc.Company_Year,
        bc.company_age,
        cb.country_avg_rating,
        cb.country_avg_employees,
        ROUND(bc.Rating - cb.country_avg_rating, 3) AS rating_lift,
        ROUND(bc.Employees_Count - cb.country_avg_employees, 0) AS employee_lift,
        ROUND(
            (0.60 * (bc.Rating / NULLIF(cb.country_avg_rating, 0))) +
            (0.40 * (bc.Employees_Count / NULLIF(cb.country_avg_employees, 0))),
            4
        ) AS emerging_score
    FROM base_companies bc
    JOIN country_benchmarks cb
      ON bc.Country = cb.Country
    WHERE bc.company_age <= 10
      AND bc.Rating > cb.country_avg_rating
      AND bc.Employees_Count > cb.country_avg_employees
),
ranked_employers AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY emerging_score DESC, Rating DESC, Employees_Count DESC, Name ASC
        ) AS emerging_rank
    FROM emerging_candidates
)
SELECT
    Country,
    Name,
    Company_Year,
    company_age,
    Rating,
    country_avg_rating,
    Employees_Count,
    country_avg_employees,
    rating_lift,
    employee_lift,
    emerging_score,
    emerging_rank
FROM ranked_employers
WHERE emerging_rank <= 3
ORDER BY Country, emerging_rank;


/*
12. Group companies into combined segments such as Young + Small, Young + Large, Old + Small,
and Old + Large using each Country's median company age and median employee count. 
Compare average ratings across these groups by Country and identify which segment wins
most often across countries.
*/

WITH base_companies AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        YEAR(CURDATE()) - Company_Year AS company_age
    FROM companies
    WHERE Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
      AND Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
),
age_ordering AS (
    SELECT
        Country,
        company_age,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY company_age
        ) AS age_rn,
        COUNT(*) OVER (
            PARTITION BY Country
        ) AS age_cnt
    FROM base_companies
),
country_age_median AS (
    SELECT
        Country,
        AVG(company_age) AS median_company_age
    FROM age_ordering
    WHERE age_rn IN (
        FLOOR((age_cnt + 1) / 2),
        FLOOR((age_cnt + 2) / 2)
    )
    GROUP BY Country
),
employee_ordering AS (
    SELECT
        Country,
        Employees_Count,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY Employees_Count
        ) AS emp_rn,
        COUNT(*) OVER (
            PARTITION BY Country
        ) AS emp_cnt
    FROM base_companies
),
country_employee_median AS (
    SELECT
        Country,
        AVG(Employees_Count) AS median_employees
    FROM employee_ordering
    WHERE emp_rn IN (
        FLOOR((emp_cnt + 1) / 2),
        FLOOR((emp_cnt + 2) / 2)
    )
    GROUP BY Country
),
combined_segments AS (
    SELECT
        bc.Country,
        bc.Name,
        bc.Rating,
        bc.company_age,
        bc.Employees_Count,
        cam.median_company_age,
        cem.median_employees,
        CASE
            WHEN bc.company_age <= cam.median_company_age
                THEN 'Young'
            ELSE 'Old'
        END AS age_group,
        CASE
            WHEN bc.Employees_Count <= cem.median_employees
                THEN 'Small'
            ELSE 'Large'
        END AS size_group
    FROM base_companies bc
    JOIN country_age_median cam
      ON bc.Country = cam.Country
    JOIN country_employee_median cem
      ON bc.Country = cem.Country
),
segment_performance AS (
    SELECT
        Country,
        CONCAT(age_group, ' + ', size_group) AS combined_segment,
        COUNT(*) AS company_count,
        ROUND(AVG(Rating), 3) AS avg_rating,
        ROUND(AVG(company_age), 1) AS avg_age,
        ROUND(AVG(Employees_Count), 0) AS avg_employees
    FROM combined_segments
    GROUP BY Country, CONCAT(age_group, ' + ', size_group)
),
ranked_segments AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY Country
            ORDER BY avg_rating DESC, company_count DESC, avg_employees DESC
        ) AS segment_rank
    FROM segment_performance
),
winner_summary AS (
    SELECT
        combined_segment,
        COUNT(*) AS countries_where_segment_is_best
    FROM ranked_segments
    WHERE segment_rank = 1
    GROUP BY combined_segment
)
SELECT
    rs.Country,
    rs.combined_segment,
    rs.company_count,
    rs.avg_rating,
    rs.avg_age,
    rs.avg_employees,
    rs.segment_rank,
    COALESCE(ws.countries_where_segment_is_best, 0) AS countries_where_segment_is_best
FROM ranked_segments rs
LEFT JOIN winner_summary ws
  ON rs.combined_segment = ws.combined_segment
ORDER BY rs.Country, rs.segment_rank, rs.combined_segment;


/*
13. For each company, calculate its rank by Rating, Employees_Count, and company age within its
Country. Convert these ranks into a composite score and identify companies that are strong
across all three dimensions.
*/

WITH base_companies AS (
    SELECT
        Name,
        Country,
        Rating,
        Employees_Count,
        YEAR(CURDATE()) - Company_Year AS company_age
    FROM companies
    WHERE Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
      AND Company_Year IS NOT NULL
      AND Company_Year <= YEAR(CURDATE())
),
country_sizes AS (
    SELECT
        Country,
        COUNT(*) AS country_company_count
    FROM base_companies
    GROUP BY Country
),
dimension_ranks AS (
    SELECT
        bc.Name,
        bc.Country,
        bc.Rating,
        bc.Employees_Count,
        bc.company_age,
        cs.country_company_count,
        RANK() OVER (
            PARTITION BY bc.Country
            ORDER BY bc.Rating DESC
        ) AS rating_rank,
        RANK() OVER (
            PARTITION BY bc.Country
            ORDER BY bc.Employees_Count DESC
        ) AS employee_rank,
        RANK() OVER (
            PARTITION BY bc.Country
            ORDER BY bc.company_age DESC
        ) AS age_rank
    FROM base_companies bc
    JOIN country_sizes cs
      ON bc.Country = cs.Country
),
scored_companies AS (
    SELECT
        *,
        ROUND((country_company_count - rating_rank + 1) / country_company_count, 4) AS rating_score,
        ROUND((country_company_count - employee_rank + 1) / country_company_count, 4) AS employee_score,
        ROUND((country_company_count - age_rank + 1) / country_company_count, 4) AS age_score,
        ROUND(
            ((country_company_count - rating_rank + 1) / country_company_count) * 0.50 +
            ((country_company_count - employee_rank + 1) / country_company_count) * 0.30 +
            ((country_company_count - age_rank + 1) / country_company_count) * 0.20,
            4
        ) AS composite_score,
        CASE
            WHEN rating_rank <= CEIL(country_company_count * 0.25)
             AND employee_rank <= CEIL(country_company_count * 0.25)
             AND age_rank <= CEIL(country_company_count * 0.25)
                THEN 'Balanced Leader'
            ELSE 'Specialist / Mixed Position'
        END AS profile_type
    FROM dimension_ranks
),
final_ranking AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Country
            ORDER BY composite_score DESC, rating_rank ASC, employee_rank ASC, age_rank ASC, Name ASC
        ) AS composite_rank
    FROM scored_companies
)
SELECT
    Country,
    Name,
    Rating,
    Employees_Count,
    company_age,
    rating_rank,
    employee_rank,
    age_rank,
    composite_score,
    profile_type,
    composite_rank
FROM final_ranking
ORDER BY Country, composite_rank;


/*
14. Analyze whether countries with highly concentrated headquarters locations perform better or worse.
Calculate the number of unique Headquarters per Country, measure concentration using an HHI-style
index, compare it with average Rating and Employees_Count, and rank countries by concentration.
*/

WITH base_companies AS (
    SELECT
        Country,
        Headquarters,
        Rating,
        Employees_Count
    FROM companies
    WHERE Country IS NOT NULL
      AND Headquarters IS NOT NULL
      AND Rating IS NOT NULL
      AND Employees_Count IS NOT NULL
),
country_totals AS (
    SELECT
        Country,
        COUNT(*) AS company_count,
        COUNT(DISTINCT Headquarters) AS unique_headquarters,
        ROUND(AVG(Rating), 3) AS avg_rating,
        ROUND(AVG(Employees_Count), 0) AS avg_employees
    FROM base_companies
    GROUP BY Country
),
hq_distribution AS (
    SELECT
        Country,
        Headquarters,
        COUNT(*) AS hq_company_count
    FROM base_companies
    GROUP BY Country, Headquarters
),
concentration_metrics AS (
    SELECT
        hd.Country,
        ROUND(SUM(POWER(hd.hq_company_count / ct.company_count, 2)), 4) AS hhi_concentration_index,
        ROUND(MAX(hd.hq_company_count / ct.company_count), 4) AS largest_hq_share
    FROM hq_distribution hd
    JOIN country_totals ct
      ON hd.Country = ct.Country
    GROUP BY hd.Country
),
ranked_countries AS (
    SELECT
        ct.Country,
        ct.company_count,
        ct.unique_headquarters,
        cm.hhi_concentration_index,
        cm.largest_hq_share,
        ct.avg_rating,
        ct.avg_employees,
        DENSE_RANK() OVER (
            ORDER BY cm.hhi_concentration_index DESC
        ) AS concentration_rank,
        DENSE_RANK() OVER (
            ORDER BY ct.avg_rating DESC
        ) AS rating_rank,
        DENSE_RANK() OVER (
            ORDER BY ct.avg_employees DESC
        ) AS size_rank
    FROM country_totals ct
    JOIN concentration_metrics cm
      ON ct.Country = cm.Country
)
SELECT
    Country,
    company_count,
    unique_headquarters,
    hhi_concentration_index,
    largest_hq_share,
    avg_rating,
    avg_employees,
    concentration_rank,
    rating_rank,
    size_rank
FROM ranked_countries
ORDER BY concentration_rank, Country;
