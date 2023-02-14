-- Sales Analysis tables [Invoices, Order_Leads, Sales_Team]
-- Purpose: Joins, Temporary Tables, Ad Hoc queries.
USE mini_projects;

SELECT *
FROM INFORMATION_SCHEMA.TABLES;

SELECT *
FROM Order_Leads;

SELECT *
FROM Invoices;

SELECT *
FROM Sales_Team;

-- Join the 3 tables in a temporary table to run queries against. 
SELECT iv.Order_Id, iv.Date
	, iv.Meal_Id
	, iv.Company_Id
	, iv.Participants
	, iv.Meal_Price
	, iv.Type_of_Meal
	, ol.Company_Name
	, ol.Order_Value
	, st.Sales_Rep
	, st.Sales_Rep_Id
	, ol.Converted
INTO #Sales_Converted
FROM Invoices iv LEFT JOIN Order_Leads ol
ON iv.Order_Id = ol.Order_Id AND iv.Company_Id = ol.Company_Id AND iv.Date = iv.Date
LEFT JOIN Sales_Team st
ON iv.Company_Id = st.Company_Id;

SELECT *
FROM #Sales_Converted;

-- Which meal has the highest rate of conversion?
---- There is no real difference in rate conversion. The highest is Dinner with 25.52%.
WITH sum_total_meals AS(
SELECT Type_of_Meal
	, Converted
	, COUNT(Type_of_Meal) total_meals
	, SUM(COUNT(Type_of_Meal)) OVER (PARTITION BY Type_of_Meal ORDER BY Converted) cum_total_meals
FROM #Sales_Converted
GROUP BY Type_of_Meal, Converted
)
SELECT Type_of_Meal, Converted, ROUND(100.0 * total_meals / MAX(cum_total_meals) OVER (PARTITION BY Type_of_Meal), 2) conv_rate
FROM sum_total_meals;

-- Which meal has the lowest average price to get a conversion?
---- The average price seems mostly equal in all the type of meals.
---- Breakfast has a lower average meal price to get a conversion.
---- Although Dinner has a higher percentage to get a conversion it also has a higher meal price.
---- Its cheaper to get a conversion during Breakfast.
SELECT Type_of_Meal
	, Converted
	, COUNT(Type_of_Meal) total_meals
	, AVG(Meal_Price) Avg_meal_price
	, AVG(Meal_Price) - LAG(AVG(Meal_Price)) OVER (PARTITION BY Type_of_Meal ORDER BY Converted) diff_meal_price
	, COUNT(Type_of_Meal) * (AVG(Meal_Price) - LAG(AVG(Meal_Price)) OVER (PARTITION BY Type_of_Meal ORDER BY Converted)) money_spend
FROM #Sales_Converted
GROUP BY Type_of_Meal, Converted
ORDER BY Type_of_Meal, Converted;

-- Which Sales Representative have the highest Conversion Rate?
---- The highest is Tamica Daves, but Jonh Crenshaw might be the best as it has 3 times the amount of total conversions with similar rate.
---- We can also see that Linda Mailman has 0 conversions.
---- Lisa Williams and Anthony Mears might need help as they have a low conversion rate with the most meetings.
WITH total_meetings AS(
	SELECT Sales_Rep
	, Sales_Rep_Id
	, Converted
	, COUNT(Converted) count_meetings
	, SUM(COUNT(Converted)) OVER (PARTITION BY Sales_Rep_Id Order BY Converted) total_meetings
	FROM #Sales_Converted
	GROUP BY Sales_Rep, Sales_Rep_Id, Converted
)
SELECT Sales_Rep, Sales_Rep_Id, Converted, count_meetings, ROUND(100.0 * count_meetings / MAX(total_meetings) OVER (PARTITION BY Sales_Rep_Id), 2) conv_rate
FROM total_meetings
ORDER BY Converted DESC, conv_rate DESC, Sales_Rep;