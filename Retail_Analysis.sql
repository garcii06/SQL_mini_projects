USE mini_projects;

-- Cleansing the Table.
-- InvoiceNo	: [C - transaction cancelled, A - possible Typo, Other is a legit InvoiceNo]
-- StockCode	: Unique item code (0 Nulls)
-- Description	: Item Description (Can be Null)
-- Quantity		: Quantity per transaction, cancelled transactions have a negative quantity.
-- InvoiceDate	: Day and time the transaction was generated
-- UnitPrice	: Price, price can be zero and might be an error.
-- CustomerID	: Customer number. I will filter out this as it is possible a data collection error.
-- Country		: Country where the customer resides.
-- So, the general method I will use to have clean data is to add a column with the type of transaction cancellation/purchase, also
-- filter all the curstomers with NULL ID.

SELECT *
FROM online_retail;

WITH pre_data AS(
	SELECT InvoiceNo
		, CASE WHEN InvoiceNo LIKE 'C%' THEN 1 
			ELSE 0 END is_cancelled
		, StockCode
		, Description
		, Quantity
		, CONVERT(datetime, InvoiceDate) InvoiceDate
		, CONVERT(decimal(10, 2), UnitPrice) UnitPrice
		, SUBSTRING(CustomerID, 0, 6) CustomerID
		, Country
		, ROW_NUMBER() OVER (PARTITION BY InvoiceNo, StockCode, Description, Quantity, UnitPrice, CustomerID, Country ORDER BY InvoiceDate) row_num
	FROM online_retail
	WHERE CustomerID IS NOT NULL
)
SELECT InvoiceNo
	, is_cancelled
	, StockCode
	, Description
	, Quantity
	, InvoiceDate
	, UnitPrice
	, CustomerID
	, Country
INTO #online_retail_clean
FROM pre_data
WHERE UnitPrice <> 0 AND row_num = 1;

DROP TABLE #online_retail_clean;
-- "Clean" version of the table, with UnitPrice different than 0, no duplicate observations.
-- Cancelled transactions appear as a new InvoiceNo.
---- Example: Transaction with InvoiceNo 540170, cancellation within few minutes generate InvoiceNo C540171
---- then the transaction continues with the new InvoiceNo 540172.
SELECT *
FROM #online_retail_clean;

-- Best general product.
-- Defining best product as the one that wasn't cancelled during transaction, and is bought in higest Quantity and by several Customers.
-- product_sales	: aggregated sales by each product
-- all_sales		: total sales of all products
-- sales_pct		: percentage contribution of the product sells into the total sales.
-- cum_sales		: cumulative sum of the sales, ~ 99% due to rounding.
WITH gl_sells AS(
	SELECT StockCode
		, COUNT(StockCode) * SUM(Quantity) product_sales
		, SUM(COUNT(StockCode) * SUM(Quantity)) OVER () all_sales
	FROM #online_retail_clean
	WHERE is_cancelled = 0
	GROUP BY StockCode
)
SELECT StockCode
	, product_sales
	, all_sales
	, CONVERT(decimal(10,5), 100.0 * product_sales / all_sales) sales_ptc
	, SUM(CONVERT(decimal(10,5), 100.0 * product_sales / all_sales)) OVER (ORDER BY product_sales DESC) cum_sales
FROM gl_sells
ORDER BY product_sales DESC;

-- Product that are Cancelled most often.
-- Might be good to have it as a procedure as the only thing that changes is the WHERE clause.
WITH gl_cancelled AS(
	SELECT StockCode
		, COUNT(StockCode) * SUM(Quantity) product_cancelled
		, SUM(COUNT(StockCode) * SUM(Quantity)) OVER () all_cancelled
	FROM #online_retail_clean
	WHERE is_cancelled = 1
	GROUP BY StockCode
)
SELECT StockCode
	, product_cancelled
	, all_cancelled
	, CONVERT(decimal(10,5), 100.0 * product_cancelled / all_cancelled) sales_ptc
	, SUM(CONVERT(decimal(10,5), 100.0 * product_cancelled / all_cancelled)) OVER (ORDER BY product_cancelled) cum_cancellation
FROM gl_cancelled
ORDER BY product_cancelled;

-- Average amount spend Customer.
SELECT CustomerID
	, Country
	, SUM(Quantity) * SUM(UnitPrice) total_Amount
	, CONVERT(decimal(18, 2), 1.0 * (SUM(Quantity) * SUM(UnitPrice)) / COUNT(DISTINCT InvoiceDate)) Avg_Amount
	, COUNT(DISTINCT InvoiceDate) Total_Transactions
FROM #online_retail_clean
GROUP BY CustomerID, Country
ORDER BY Country, AVG(Quantity * UnitPrice) DESC;

-- Days between transactions of each Customer.
-- All the one-time customers are filtered out.
WITH lagged_values AS(
	SELECT CustomerID
		, Country
		, InvoiceNo
		, InvoiceDate
		, LEAD(InvoiceDate) OVER(PARTITION BY CustomerID ORDER BY InvoiceDate) Lagged_InvoiceDate
		, COUNT(InvoiceNo) OVER (PARTITION BY CustomerID, InvoiceDate) Total_Invoices
	FROM #online_retail_clean
	WHERE is_cancelled = 0
), time_diff_calc AS
(
	SELECT CustomerId, Country, InvoiceNo, InvoiceDate, Lagged_InvoiceDate, DATEDIFF(MINUTE, InvoiceDate, Lagged_InvoiceDate) mins_diff, Total_Invoices
	FROM lagged_values
)
SELECT CustomerId, Country, InvoiceNo, Total_Invoices, InvoiceDate, Lagged_InvoiceDate, mins_diff
FROM time_diff_calc
WHERE mins_diff <> 0
ORDER BY CustomerId;

-- One-time customers
WITH get_total_invoices AS(
	SELECT CustomerID
		, Country
		, InvoiceNo
		, COUNT(InvoiceNo) OVER (PARTITION BY CustomerID) Total_Invoices
	FROM #online_retail_clean
	WHERE is_cancelled = 0
)
SELECT CustomerID
	, Country
	, InvoiceNo
FROM get_total_invoices
WHERE Total_Invoices = 1;