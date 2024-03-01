/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (10) *
  FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]

  -- Range of dates
  Select 
	MAX(OrderDate) AS MAX, 
	MIN(OrderDate) AS MIN  
FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]
DECLARE @today_date AS DATE = '2021-02-28';

--Calculating the RFM
SELECT 
     CustomerID AS CustomerID
	,Datediff(day,MAX(OrderDate),@today_date) AS Recency
	,Count(OrderNumber) AS Frequency
	,Sum([Unit_Price]* (1 - [Discount_Applied]) - [Unit_Cost]) AS Monetary_Value
FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]
GROUP BY CustomerID;


-- Distribution of RFM Values by Five Number Summary

With a as (

SELECT 
     CustomerID AS CustomerID
	,Datediff(day,MAX(OrderDate),'2021-02-28') AS Recency
	,Count(OrderNumber) AS Frequency
	,cast(Sum([Unit_Price]* (1 - [Discount_Applied]) - [Unit_Cost]) as decimal(16,2)) AS Monetary_Value
FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]
GROUP BY CustomerID

), b as

(
select MIN(Recency) as RMIN,
MAX(Recency) as RMAX,
MIN(Frequency) as FMIN,
MAX(Frequency) as FMAX,
MIN(Monetary_Value) as MMIN,
MAX(Monetary_Value) as MMAX

from a
)

Select Distinct
		'Monetary_Value' as RFM,
		b.MMIN as MIN,
		PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as [25%],
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as [50%],
		PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Monetary_Value) OVER () as [75%],
		b.MMAX as MAX
		from b join a on 1 = 1 

		union

Select Distinct
		'Frequency' as RFM,
		b.FMIN as MIN,
		PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Frequency) OVER () as [25%],
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY Frequency) OVER () as [50%],
		PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Frequency) OVER () as [75%],
		b.FMAX as MAX
		from b join a on 1 = 1 

		union 

Select Distinct
		'Recency' as RFM,
		b.RMIN as MIN,
		PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY Recency) OVER () as [25%],
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY Recency) OVER () as [50%],
		PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY Recency) OVER () as [75%],
		b.RMAX as MAX
		from b join a on 1 = 1;


-- Partition RFM Values on the scale of 1 to 5 scores
		
With a as (

SELECT 
     CustomerID AS CustomerID
	,Datediff(day,MAX(OrderDate),'2021-02-28') AS Recency
	,Count(OrderNumber) AS Frequency
	,cast(Sum([Unit_Price]* (1 - [Discount_Applied]) - [Unit_Cost]) as decimal(16,2)) AS Monetary_Value
FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]
GROUP BY CustomerID

)

select
		*,
		NTILE(5) Over(order by recency Desc) as Recency_Score,
		NTILE(5) Over(order by Frequency) as Frequency_Score,
		NTILE(5) Over(order by Monetary_Value) as Monetary_Value_Score
		from a;

-- Let’s store the above result into a temporary table

With a as (
SELECT 
     CustomerID AS CustomerID
	,Datediff(day,MAX(OrderDate),'2021-02-28') AS Recency
	,Count(OrderNumber) AS Frequency
	,cast(Sum([Unit_Price]* (1 - [Discount_Applied]) - [Unit_Cost]) as decimal(16,2)) AS Monetary_Value
FROM [e-ommercce data ].[dbo].[US_Regional_Sales_Data]
GROUP BY CustomerID

)

select
		*,
		NTILE(5) Over(order by recency DESC) as Recency_Score,
		NTILE(5) Over(order by Frequency) as Frequency_Score,
		NTILE(5) Over(order by Monetary_Value) as Monetary_Value_Score
		into #RFM_segment1
		from a

Select * from #RFM_segment1;

-- Checking the Ranges of RFM by Scores using the temp table 

with a as (

			Select ROW_NUMBER() over(order by Recency_score) as I,
					Recency_score,
					min(Recency) as RMin,
					max(Recency) as RMax
					from #RFM_segment1
					group by Recency_score),

	b as(

		    Select ROW_NUMBER() over(order by Frequency_Score) as I,
					Frequency_Score,
					min(Frequency) as FMin,
					max(Frequency) as FMax
					from #RFM_segment1
					group by Frequency_Score),

	c as(

		    Select ROW_NUMBER() over(order by Monetary_Value_Score) as I,
					Monetary_Value_Score,
					min(Monetary_Value) as MMin,
					max(Monetary_Value) as MMax
					from #RFM_segment1
					group by Monetary_Value_Score)

	select 
			Recency_score, RMin, RMax,
			Frequency_Score, FMin, FMax,
			Monetary_Value_Score, MMin, MMax
	from a join b 
	on a.I = b.I
	join c 
	on a.I = c.I;

-- Create the Value Segments & Customer Segments based on RFM Score & Average RFM Score 

Select *,
		CONCAT_WS('-',Recency_Score,Frequency_Score, Monetary_Value_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Value_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
		from #RFM_segment1
		order by R_F_M

------


with a as(

			Select *,
		CONCAT_WS('-',Recency_Score,Frequency_Score, Monetary_Value_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Value_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
		from #RFM_segment1)

Select *
	, CASE WHEN Avg_RFM_Score >= 4 THEN 'High Value'
			WHEN Avg_RFM_Score >= 2.5 AND Avg_RFM_Score < 4 THEN 'Mid Value'
			WHEN Avg_RFM_Score > 0 AND Avg_RFM_Score < 2.5 THEN 'Low Value'
	END AS Value_Seg --Value Segment
	, CASE WHEN Frequency_Score >= 4 and Recency_Score >= 4 and Monetary_Value_Score >= 4 THEN 'VIP'
			WHEN Frequency_Score >= 3 and Monetary_Value_Score < 4 THEN 'Regular'
			WHEN Recency_Score <= 3 and Recency_Score > 1 THEN 'Inactive'
			WHEN Recency_Score = 1 THEN 'Churned'
			WHEN Recency_Score >= 4 and Frequency_Score <= 4 THEN 'New Customer'
	END AS Cust_Seg --Customer Segment
FROM a order by R_F_M;

---

--Distribution of Customers by Value Segment


with a as(

			Select *,
		CONCAT_WS('-',Recency_Score,Frequency_Score, Monetary_Value_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Value_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
		from #RFM_segment1),
		b as(

Select *
	, CASE WHEN Avg_RFM_Score >= 4 THEN 'High Value'
			WHEN Avg_RFM_Score >= 2.5 AND Avg_RFM_Score < 4 THEN 'Mid Value'
			WHEN Avg_RFM_Score > 0 AND Avg_RFM_Score < 2.5 THEN 'Low Value'
	END AS Value_Seg --Value Segment
	, CASE WHEN Frequency_Score >= 4 and Recency_Score >= 4 and Monetary_Value_Score >= 4 THEN 'VIP'
			WHEN Frequency_Score >= 3 and Monetary_Value_Score < 4 THEN 'Regular'
			WHEN Recency_Score <= 3 and Recency_Score > 1 THEN 'Inactive'
			WHEN Recency_Score = 1 THEN 'Churned'
			WHEN Recency_Score >= 4 and Frequency_Score <= 4 THEN 'New Customer'
	END AS Cust_Seg --Customer Segment
FROM a)


SELECT 
	Value_Seg, 
	COUNT(CustomerID) AS Customer_Count
FROM b 
GROUP BY Value_Seg 
ORDER BY Customer_Count

--We have highest Mid Value Customers (42%)

--Distribution of Customers by Customer Segment




with a as(

			Select *,
		CONCAT_WS('-',Recency_Score,Frequency_Score, Monetary_Value_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Value_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
		from #RFM_segment1),
		b as(

Select *
	, CASE WHEN Avg_RFM_Score >= 4 THEN 'High Value'
			WHEN Avg_RFM_Score >= 2.5 AND Avg_RFM_Score < 4 THEN 'Mid Value'
			WHEN Avg_RFM_Score > 0 AND Avg_RFM_Score < 2.5 THEN 'Low Value'
	END AS Value_Seg --Value Segment
	, CASE WHEN Frequency_Score >= 4 and Recency_Score >= 4 and Monetary_Value_Score >= 4 THEN 'VIP'
			WHEN Frequency_Score >= 3 and Monetary_Value_Score < 4 THEN 'Regular'
			WHEN Recency_Score <= 3 and Recency_Score > 1 THEN 'Inactive'
			WHEN Recency_Score = 1 THEN 'Churned'
			WHEN Recency_Score >= 4 and Frequency_Score <= 4 THEN 'New Customer'
	END AS Cust_Seg --Customer Segment
FROM a)

SELECT 
	Cust_Seg,
	COUNT(CustomerID) AS Customer_Count
FROM b 
GROUP BY Cust_Seg 
ORDER BY Customer_Count			
					

--Company have highest inactive Customers (34%), 20% Regular Customers, 18% New Custoers, 16% Churned Customers & Lowest VIP Customers (12%)



--Distribution of customers across different RFM customer segments within each value segment
										

with a as(

			Select *,
		CONCAT_WS('-',Recency_Score,Frequency_Score, Monetary_Value_Score) AS R_F_M
		,CAST((CAST(Recency_Score AS Float) + Frequency_Score + Monetary_Value_Score)/3 AS DECIMAL(16,2)) AS Avg_RFM_Score
		from #RFM_segment1),
		b as(

Select *
	, CASE WHEN Avg_RFM_Score >= 4 THEN 'High Value'
			WHEN Avg_RFM_Score >= 2.5 AND Avg_RFM_Score < 4 THEN 'Mid Value'
			WHEN Avg_RFM_Score > 0 AND Avg_RFM_Score < 2.5 THEN 'Low Value'
	END AS Value_Seg --Value Segment
	, CASE WHEN Frequency_Score >= 4 and Recency_Score >= 4 and Monetary_Value_Score >= 4 THEN 'VIP'
			WHEN Frequency_Score >= 3 and Monetary_Value_Score < 4 THEN 'Regular'
			WHEN Recency_Score <= 3 and Recency_Score > 1 THEN 'Inactive'
			WHEN Recency_Score = 1 THEN 'Churned'
			WHEN Recency_Score >= 4 and Frequency_Score <= 4 THEN 'New Customer'
	END AS Cust_Seg --Customer Segment
FROM a)
			

SELECT 
	Value_Seg,
	Cust_Seg,
	COUNT(CustomerID) AS Customer_Count
FROM b 
GROUP BY Cust_Seg,Value_Seg
ORDER BY Value_Seg,Customer_Count DESC


--Churned Customers are equally distributed among mid value & low value customers.
--Inactive Customes are distributed across all the value segments, low value segment have the maximum inactive customers.
--Regular Customers are also distributed across all the value segments but majorly the Mid Value segment.
--New Customers are als0 distributed across all the value segments but majorly low value & mid value segment.
--55% of High Value segment customers are the VIP Customer



