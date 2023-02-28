-- Mavens Mexican Toys Store
-- Recommended Analysis Questions:
---- 1. Which product categories drive the biggest profits? Is this the same across store locations?
---- 2. Can you find any seasonal trends or patterns in the sales data?
---- 3. Are sales being lost with out-of-stock products at certain locations?
---- 4. How much money is tied up in inventory at the toy stores? How long will it last?

USE mini_projects;

-- QA of mx_toys_products table.
SELECT *
FROM mx_toys_products;

SELECT Product_Category
	, COUNT(Product_Category) total_categories
FROM mx_toys_products
GROUP BY Product_Category;

SELECT Product_Name
	, COUNT(Product_Name) total_products
FROM mx_toys_products
GROUP BY Product_Name;

SELECT Product_Name, Product_Price - Product_Cost profit_per_product
FROM mx_toys_products;

-- QA of mx_toys_sales table.
SELECT *
FROM mx_toys_sales;

-- Total units by day across all stores.
SELECT date
	, SUM(Units) total_units_sold_day
FROM mx_toys_sales
GROUP BY date
ORDER BY date;

-- Total units by month/year
SELECT DATEPART(YEAR, date) Year
	, DATEPART(MONTH, date) Month
	, SUM(Units) total_units_sold_month
FROM mx_toys_sales
GROUP BY DATEPART(YEAR, date), DATEPART(MONTH, date)
ORDER BY DATEPART(YEAR, date), DATEPART(MONTH, date);

-- Cumulative total units by month/year
WITH units_month AS(
	SELECT DATEPART(YEAR, date) Year
		, DATEPART(MONTH, date) Month
		, SUM(Units) total_units_sold_month
	FROM mx_toys_sales
	GROUP BY DATEPART(YEAR, date), DATEPART(MONTH, date)
)
SELECT Year
	, Month
	, total_units_sold_month
	, SUM(total_units_sold_month) OVER (PARTITION BY Year ORDER BY Year, Month) cum_sum_total_units_sold_year
	, SUM(total_units_sold_month) OVER (ORDER BY Year, Month) cum_sum_total_units_sold
FROM units_month;

-- QA of mx_toys_stores table.
SELECT *
FROM mx_toys_stores;

SELECT Store_City
	, COUNT(Store_City) total_stores
FROM mx_toys_stores
GROUP BY Store_City
ORDER BY COUNT(Store_City) DESC;

-- QA of mx_toys_inventory table.
SELECT *
FROM mx_toys_inventory;

---- 1. Which product categories drive the biggest profits? Is this the same across store locations?
---- Profit is Price - Product
---- Can be defined as with product category sells the most with the most margin profit.

-- Toys are the most profitable category with the most profit margin and less units solds than the second category.
WITH profit_category AS(
	SELECT Product_Category
		, (Product_Price - Product_Cost) * SUM(Units) profit
		, SUM(Units) units_sold
	FROM mx_toys_sales sales LEFT JOIN mx_toys_products prods
	ON sales.Product_ID = prods.Product_ID
	GROUP BY Product_Category, Product_Price, Product_Cost
)
SELECT Product_Category
	, SUM(profit) profit
	, SUM(units_sold) units_sold
FROM profit_category
GROUP BY Product_Category
ORDER BY profit DESC;

-- Toys are the most profitable category for all the store locations, while Sports & Outdoors is the less profitable.
-- Games, Arts & Crafts, and Electronics are always in between.
WITH store_profit AS(
	SELECT Product_Category
		, Store_Location 
		, (Product_Price - Product_Cost) * SUM(Units) profit
		, SUM(Units) units_sold
	FROM mx_toys_sales sales LEFT JOIN mx_toys_products prods
	ON sales.Product_ID = prods.Product_ID
	LEFT JOIN mx_toys_stores stors 
	ON sales.Store_ID = stors.Store_ID
	GROUP BY Product_Category, Store_Location, Product_Price, Product_Cost
)
SELECT Product_Category
	, Store_Location
	, SUM(profit) profit
	, SUM(units_sold) units_sold
FROM store_profit
GROUP BY Product_Category, Store_Location
ORDER BY Store_Location, 3 DESC;

-- Although Art & Crafts isn't the less profitable category it needs to sell a lot to be profitable.
-- This can be seen when we add the max_units_sold by Location and recognize that the maximum is always the Art Category.
WITH profit_location AS(
	SELECT Product_Category
		, Store_Location 
		, (Product_Price - Product_Cost) * SUM(Units) profit
		, SUM(Units) units_sold
	FROM mx_toys_sales sales LEFT JOIN mx_toys_products prods
	ON sales.Product_ID = prods.Product_ID
	LEFT JOIN mx_toys_stores stors 
	ON sales.Store_ID = stors.Store_ID
	GROUP BY Product_Category, Store_Location, Product_Price, Product_Cost
)
SELECT Product_Category
	, profit
	, units_sold
	, Store_Location
	, MAX(units_sold) OVER (Partition BY Store_Location) max_units_sold
FROM profit_location
ORDER BY Store_Location, profit DESC;

---- 2. Can you find any seasonal trends or patterns in the sales data?
---- Considering only the units sold.
---- Using Excel or any other visualization tool. (The Excel file with the Pivot Table is also in the base Folder of the project.)
WITH sales_per_day AS(
	SELECT Product_Category
		, DATEPART(MONTH, date) Month
		, DATEPART(YEAR, date) Year
		, SUM(Units) units_sold
	FROM mx_toys_sales sales LEFT JOIN mx_toys_products prods
	ON sales.Product_ID = prods.Product_ID
	GROUP BY Product_Category, date
)
SELECT Product_Category
	, Year
	, Month
	, SUM(units_sold) total_units_sold
FROM sales_per_day
GROUP BY Product_Category, Year, Month
ORDER BY Product_Category, Month;

---- 3. Are sales being lost with out-of-stock products at certain locations?
---- Lost sales can be at location-month level, or location-day level.
-- At month level, we have 187 occations where the stock wasn't available for the next client.
WITH stock_monthly AS(
	SELECT store.Store_Location
		, sales.Sale_ID
		, prods.Product_Name
		, inven.Stock_On_Hand
		, sales.Units
		, sales.Date
		, store.Store_City
		, YEAR(sales.Date) Year
		, MONTH(sales.Date) Month
		, DAY(sales.Date) Day
	FROM mx_toys_inventory inven LEFT JOIN mx_toys_stores store
	ON inven.Store_ID = store.Store_ID 
	LEFT JOIN mx_toys_sales sales
	ON inven.Store_ID = sales.Store_ID AND inven.Product_ID = sales.Product_ID
	LEFT JOIN mx_toys_products prods
	ON inven.Product_ID = prods.Product_ID
)
SELECT Store_Location
	, Product_Name
	, Store_City
	, Month
	, Year
	, SUM(Stock_On_Hand) stock_available
	, SUM(Units) units_sold
	, SUM(Stock_On_Hand) - SUM(Units) stock_left
FROM stock_monthly
GROUP BY Store_Location, Store_City, Product_Name, Year, Month
HAVING SUM(Stock_On_Hand) - SUM(Units) = 0
ORDER BY Store_Location, Store_City, Product_Name, Year, Month, SUM(Stock_On_Hand) - SUM(Units);

-- At daily level, we got 473 days/occations where the stock level of a certain product was 0.
-- Daily stock as a temporary table, as it will be used from now on.
SELECT store.Store_Location
	, sales.Sale_ID
	, prods.Product_Name
	, inven.Stock_On_Hand
	, sales.Units
	, sales.Date
	, store.Store_City
	, YEAR(sales.Date) Year
	, MONTH(sales.Date) Month
	, DAY(sales.Date) Day
INTO #stock_daily
FROM mx_toys_inventory inven LEFT JOIN mx_toys_stores store
ON inven.Store_ID = store.Store_ID 
LEFT JOIN mx_toys_sales sales
ON inven.Store_ID = sales.Store_ID AND inven.Product_ID = sales.Product_ID
LEFT JOIN mx_toys_products prods
ON inven.Product_ID = prods.Product_ID;

SELECT Store_Location
	, Product_Name
	, Store_City
	, Day
	, Month
	, Year
	, SUM(Stock_On_Hand) stock_available
	, SUM(Units) units_sold
	, SUM(Stock_On_Hand) - SUM(Units) stock_left
FROM #stock_daily
GROUP BY Store_Location, Store_City, Product_Name, Year, Month, Day
HAVING SUM(Stock_On_Hand) - SUM(Units) = 0
ORDER BY Store_Location, Store_City, Product_Name, Year, Month, Day, SUM(Stock_On_Hand) - SUM(Units);

-- How many days does the store gets out of stock since the last time?
-- days_diff_nostock is the column that tells us how many days passed since the last time that certain product was out of stock.
WITH nostock_days AS(
	SELECT Store_Location
		, Product_Name
		, Store_City
		, Date
		, LAG(Date) OVER (PARTITION BY Store_Location, Product_Name, Store_City ORDER BY Date) lagged_Date
		, SUM(Stock_On_Hand) stock_available
		, SUM(Units) units_sold
		, SUM(Stock_On_Hand) - SUM(Units) stock_left
	FROM #stock_daily
	GROUP BY Store_Location, Store_City, Product_Name, Date
	HAVING SUM(Stock_On_Hand) - SUM(Units) = 0
)
SELECT Store_Location
	, Product_Name
	, Store_City, Date
	, lagged_Date
	, DATEDIFF(DAY, lagged_Date, Date) days_diff_nostock
FROM nostock_days;

-- Taking the previous query, we can now filter the difference between no stock.
-- A difference between days can mean two things: 
---- It can be that it was restocked the next day and went out of stock that same day, or 
---- There was no restock for several days in a row.

-- Setting the difference for products with less than 7 days to run out of stock.
-- This can help to know which ones weren't restock on time, or sold out too quickly.
-- I set it to 7 thinking that restock of products is done weekly.
WITH nostock_days AS(
	SELECT Store_Location
		, Product_Name
		, Store_City
		, Date
		, LAG(Date) OVER (PARTITION BY Store_Location, Product_Name, Store_City ORDER BY Date) lagged_Date
		, SUM(Stock_On_Hand) stock_available
		, SUM(Units) units_sold
		, SUM(Stock_On_Hand) - SUM(Units) stock_left
	FROM #stock_daily
	GROUP BY Store_Location, Store_City, Product_Name, Date
	HAVING SUM(Stock_On_Hand) - SUM(Units) = 0
)
SELECT Store_Location
	, Product_Name
	, Store_City, Date
	, lagged_Date
	, DATEDIFF(DAY, lagged_Date, Date) days_diff_nostock
FROM nostock_days
WHERE DATEDIFF(DAY, lagged_Date, Date) <= 7;

-- We can calculate the average time between the days that a product runs out of stock.
-- This can help to predict how much time we can expect before running out of stock.
-- NULL means that it was just a one time occation where we ran out of stock.
WITH nostock_days AS(
	SELECT Store_Location
		, Product_Name
		, Store_City
		, Date
		, LAG(Date) OVER (PARTITION BY Store_Location, Product_Name, Store_City ORDER BY Date) lagged_Date
		, SUM(Stock_On_Hand) stock_available
		, SUM(Units) units_sold
		, SUM(Stock_On_Hand) - SUM(Units) stock_left
	FROM #stock_daily
	GROUP BY Store_Location, Store_City, Product_Name, Date
	HAVING SUM(Stock_On_Hand) - SUM(Units) = 0
), diff_nostock_calc AS(
	SELECT Store_Location
	, Product_Name
	, Store_City, Date
	, lagged_Date
	, DATEDIFF(DAY, lagged_Date, Date) days_diff_nostock
	FROM nostock_days
)
SELECT Store_Location
	, Product_Name
	, Store_City
	, AVG(days_diff_nostock) avg_time_to_nostock
FROM diff_nostock_calc
GROUP BY Store_Location, Product_Name, Store_City
ORDER BY AVG(days_diff_nostock);

---- 4. How much money is tied up in inventory at the toy stores? How long will it last?
-- This question can be interpreted in many ways, for me it can be rewritten as: how much cash on inventory we have at the end of month?
-- I will use only the at a Store_City and Store_Location combination, can be extended with a join for the Store_Name.
WITH left_stock AS(
	SELECT store.Store_Location
		, sales.Sale_ID
		, prods.Product_Name
		, inven.Stock_On_Hand
		, sales.Units
		, sales.Date
		, store.Store_City
	FROM mx_toys_inventory inven LEFT JOIN mx_toys_stores store
	ON inven.Store_ID = store.Store_ID 
	LEFT JOIN mx_toys_sales sales
	ON inven.Store_ID = sales.Store_ID AND inven.Product_ID = sales.Product_ID
	LEFT JOIN mx_toys_products prods
	ON inven.Product_ID = prods.Product_ID
), stock_left_days AS(
	SELECT Store_Location
		, Product_Name
		, Store_City
		, Date
		, SUM(Stock_On_Hand) stock_available
		, SUM(Units) units_sold
		, SUM(Stock_On_Hand) - SUM(Units) stock_left
	FROM left_stock
	GROUP BY Store_Location, Store_City, Product_Name, Date
	HAVING SUM(Stock_On_Hand) - SUM(Units) <> 0
), last_stock_month AS(
	SELECT Store_Location
			, Product_Name
			, Store_City
			, stock_left
			, Date
			, FIRST_VALUE(Date) OVER (PARTITION BY YEAR(Date), MONTH(Date), Store_Location, Product_Name, Store_City ORDER BY Date DESC) lastest_day_stock
		FROM stock_left_days
)
SELECT Store_Location
		, Store_City
		, lastk.Product_Name
		, stock_left * Product_Price money_left_store
		, Date
FROM last_stock_month lastk LEFT JOIN mx_toys_products prods
ON lastk.Product_Name = prods.Product_Name
WHERE Date = lastest_day_stock
ORDER BY Store_City, Store_Location, Date;