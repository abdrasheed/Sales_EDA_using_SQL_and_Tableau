-- Check the all data
select * from [dbo].[Sales_Data];

-- Check the unique values
select distinct status from [dbo].[Sales_Data]; -- Nice one to plot
select distinct YEAR_ID from [dbo].[Sales_Data];
select distinct PRODUCTLINE from [dbo].[Sales_Data]; -- Nice one to plot
select distinct COUNTRY from [dbo].[Sales_Data]; -- Nice one to plot
select distinct DEALSIZE from [dbo].[Sales_Data]; -- Nice one to plot
select distinct TERRITORY from [dbo].[Sales_Data]; -- Nice one to plot


-- ANALYSIS -- 


-- 1) Grouping sales by product line
select PRODUCTLINE, sum(sales) as Revenue
from [dbo].[Sales_Data]
group by PRODUCTLINE
order by Revenue desc;


-- 2) Grouping sales by Year
select YEAR_ID, sum(sales) as Revenue
from [dbo].[Sales_Data]
group by YEAR_ID
order by Revenue desc;


-- 3) Grouping sales by Deal size
select DEALSIZE, 
	   sum(sales) as Revenue
from [dbo].[Sales_Data]
group by DEALSIZE
order by Revenue desc;



-- 4) What was the best months for sales? How much was earned that month?
select MONTH_ID, 
	   sum(SALES) Revenue, 
	   count(ORDERNUMBER) Frequency
from [dbo].[Sales_Data] 
where YEAR_ID = 2004 -- Specific year
group by MONTH_ID
order by Revenue desc;

-- 4) What was the best month for sales in a specific year? How much was earned that month?
with max_month_year_sales as (
	select YEAR_ID, MONTH_ID, 
		   sum(sales) as Revenue, 
		   count(ORDERNUMBER) Frequency
	from [dbo].[Sales_Data]
	group by YEAR_ID,MONTH_ID
)
SELECT t.YEAR_ID, 
	   t.MONTH_ID, 
	   round(t.Revenue,2), 
	   t.Frequency
FROM max_month_year_sales t
INNER JOIN (
    SELECT YEAR_ID, 
		   max(Revenue) AS max_sales
    FROM max_month_year_sales
    GROUP BY YEAR_ID
) m ON t.YEAR_ID = m.YEAR_ID AND t.Revenue = m.max_sales
order by Revenue desc;


-- 5) November seems to be the month, what products do they sell in november, Classic I believe
select MONTH_ID,PRODUCTLINE, 
	   sum(SALES) Revenue, 
	   count(ORDERNUMBER) Frequency
from [dbo].[Sales_Data] 
where YEAR_ID = 2004 and MONTH_ID = 11 -- Specific year
group by MONTH_ID,PRODUCTLINE
order by Revenue desc;




-- 6) Who is our best customer (this could be best answered with RFM(Recency_Frequency-Monetary))
drop table if exists #RFM; 
with RFM as 
(
	select CUSTOMERNAME, 
		   SUM(SALES) Monetary_Value, 
		   AVG(SALES) Average_Monetary,
		   COUNT(ORDERNUMBER) Frequency, 
		   MAX(ORDERDATE) Last_order_date,
		   (select MAX(ORDERDATE) from [dbo].[Sales_Data]) max_order_date,
		   DATEDIFF(DD, MAX(ORDERDATE),(select MAX(ORDERDATE) from [dbo].[Sales_Data])) Recency
	from [dbo].[Sales_Data] 
	group by CUSTOMERNAME
),
RFM_calc as (
	select r.*,
		   NTILE(4) over (order by Recency desc) RFM_Recency,
		   NTILE(4) over (order by Frequency) RFM_Frequency,
		   NTILE(4) over (order by Monetary_Value) RFM_Monetary	
	from RFM r
)

select c.*,
	   RFM_Recency + RFM_Frequency + RFM_Monetary as RFM_Cell,
	   cast(RFM_Recency as varchar) + cast(RFM_Frequency as varchar) + cast(RFM_Monetary as varchar) as RFM_Cell_String
into #RFM
from RFM_calc c

select CUSTOMERNAME, RFM_Recency, RFM_Frequency, RFM_Monetary,
	   case
			when RFM_Cell_String in (111,112,121,122,123,132,211,212,114,141) then 'Lost Customers'
			when RFM_Cell_String in (133,134,143,244,334,343,344) then 'Slipping away, cannot lose'
			when RFM_Cell_String in (311,411,331) then 'New Customers'
			when RFM_Cell_String in (222,223,233,322) then 'Potential Churners'
			when RFM_Cell_String in (323,333,321,422,332,432) then 'Active'
			when RFM_Cell_String in (433,434,443,444) then 'Loyal'
	   end RFM_Segment
from #RFM;

-- 7) What products are most often sold together?
select distinct ORDERNUMBER, stuff(
	(select ',' + PRODUCTCODE
	from [dbo].[Sales_Data] p
	where ORDERNUMBER in 
		(
			select ORDERNUMBER 
			from (
				select ORDERNUMBER, count(*) rn
				from [dbo].[Sales_Data]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
				) m
				where rn = 3
		) 
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path(''))
		, 1, 1,'') Product_code
from [dbo].[Sales_Data] s
order by Product_code desc
