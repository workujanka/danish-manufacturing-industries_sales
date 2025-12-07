SELECT *
FROM raw_data_dk_manufacturing_total_turnover_2000_2024_v2;

-- Total_turnover_by_year
SELECT Year, SUM(TurnoverDKK) AS TotalTurnover
FROM dk_manufacturing_total_turnover_2000_2024_v2
GROUP BY Year
ORDER BY Year;

-- Top_industries_by_turnover_in_2023

SELECT IndustryName, TurnoverDKK
FROM dk_manufacturing_total_turnover_2000_2024_v2
WHERE Year = 2023
ORDER BY TurnoverDKK DESC
LIMIT 10;

-- Year over Year Growth for Selected Industries (Pharma, Oil & Gas, Chemicals, Computers, Metals, Meat)
SELECT 
    t1.IndustryCode,
    t1.IndustryName,
    t1.Year,
    t1.TurnoverDKK,
    ROUND(((t1.TurnoverDKK - t2.TurnoverDKK) / t2.TurnoverDKK) * 100, 2) AS YoYGrowthPercent
FROM dk_manufacturing_total_turnover_2000_2024_v2 t1
JOIN dk_manufacturing_total_turnover_2000_2024_v2 t2
  ON t1.IndustryCode = t2.IndustryCode
 AND t1.Year = t2.Year + 1
WHERE t1.IndustryCode IN ('21000','06000','19009','26001','24000','10001')
ORDER BY t1.IndustryCode, t1.Year;

/*-- Compound Annual Growth Rate (CAGR)
Significance
CAGR smooths volatility: Instead of looking at noisy year‑to‑year changes, it shows the average annual growth rate over the full period.
Helps identify long‑term winners (e.g., Pharma) vs. decliners (e.g., Computers).
Crucial for strategic insights: investors, policymakers, or educators want to know which industries grew steadily.
*/

WITH first_last AS (
  SELECT
    IndustryCode,
    IndustryName,
    MIN(Year) AS StartYear,
    MAX(Year) AS EndYear,
    SUM(CASE WHEN Year = 2000 THEN TurnoverDKK ELSE 0 END) AS StartValue,
    SUM(CASE WHEN Year = 2023 THEN TurnoverDKK ELSE 0 END) AS EndValue
  FROM dk_manufacturing_total_turnover_2000_2024_v2
  GROUP BY IndustryCode, IndustryName
)
SELECT IndustryCode, IndustryName,
       ROUND(POWER(EndValue / StartValue, 1.0 / (EndYear - StartYear)) - 1, 4) AS CAGR
FROM first_last
WHERE StartValue > 0 AND EndValue > 0
ORDER BY CAGR DESC;


/*-- Industry Share of Total Turnover
Why it’s important
Shows relative importance of each industry in the economy.

Even if an industry grows fast, its share might be small (e.g., niche sectors).

Helps answer: Who dominates manufacturing turnover today?
*/
SELECT
  IndustryCode,
  IndustryName,
  TurnoverDKK,
  ROUND(TurnoverDKK / (SELECT SUM(TurnoverDKK)
                       FROM dk_manufacturing_total_turnover_2000_2024_v2
                       WHERE Year = 2023) * 100, 2) AS SharePercent
FROM dk_manufacturing_total_turnover_2000_2024_v2
WHERE Year = 2023
ORDER BY SharePercent DESC;

/* Volatility Analysis
Why it’s important
Identifies industries with unstable growth (big swings up and down).

Volatility matters for risk assessment: investors and policymakers avoid industries with unpredictable turnover.

Example: Oil & Gas vs. Meat — one is volatile, the other steady.
*/


WITH yoy AS (
  SELECT 
    t1.IndustryCode,
    t1.IndustryName,
    t1.Year,
    ROUND(((t1.TurnoverDKK - t2.TurnoverDKK) / t2.TurnoverDKK) * 100, 2) AS YoYGrowthPercent
  FROM dk_manufacturing_total_turnover_2000_2024_v2 t1
  JOIN dk_manufacturing_total_turnover_2000_2024_v2 t2
    ON t1.IndustryCode = t2.IndustryCode
   AND t1.Year = t2.Year + 1
)
SELECT IndustryCode, IndustryName,
       MAX(YoYGrowthPercent) AS MaxGrowth,
       MIN(YoYGrowthPercent) AS MinGrowth,
       ROUND(STDDEV(YoYGrowthPercent),2) AS Volatility
FROM yoy
GROUP BY IndustryCode, IndustryName
ORDER BY Volatility DESC
LIMIT 5;

/*
Ranking Industries by Performance Clusters
Why it’s important
Groups industries into clusters:

High Growth & Stable (ideal performers)

High Growth & Volatile (risky but rewarding)

Moderate Growth (steady contributors)

Declining (structural challenges)

Makes the dataset actionable: instead of raw numbers, you get categories that tell a story.
*/
WITH metrics AS (
  SELECT IndustryCode, IndustryName,
         ROUND(AVG(TurnoverDKK),0) AS AvgTurnover,
         ROUND(POWER(MAX(TurnoverDKK) / MIN(TurnoverDKK), 1.0 / (MAX(Year)-MIN(Year))) - 1, 4) AS CAGR,
         ROUND(STDDEV(TurnoverDKK),0) AS Volatility
  FROM dk_manufacturing_total_turnover_2000_2024_v2
  GROUP BY IndustryCode, IndustryName
)
SELECT IndustryCode, IndustryName, AvgTurnover, CAGR, Volatility,
       CASE 
         WHEN CAGR > 0.05 AND Volatility < 0.1 THEN 'High Growth & Stable'
         WHEN CAGR > 0.05 AND Volatility >= 0.1 THEN 'High Growth & Volatile'
         WHEN CAGR BETWEEN 0 AND 0.05 THEN 'Moderate Growth'
         ELSE 'Declining'
       END AS PerformanceCluster
FROM metrics
ORDER BY PerformanceCluster, CAGR DESC;

