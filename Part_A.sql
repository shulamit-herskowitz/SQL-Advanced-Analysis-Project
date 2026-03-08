use LogicalProject;

--1
--לא נתון איך לחלק את ההנחה כיוון שההנחה ברמת חשבונית התיחסתי לזה לפי יחס פרופורציונלי
with CalculatedLines as(
 select l.[DocNum], l.[ItemCode], l.[Qty],
 l.[LineSum]-(
 l.[LineSum]/ cast(nullif(sum(l.[LineSum]) over(partition by l.[DocNum]),0) as money)
 *isnull(h.[DocDiscount],0)
 ) as Line_total_cost
  from [dbo].[SalesLine] l
  join [dbo].[SalesHeader] h on l.[DocNum]=h.[DocNum]
)
select [ItemCode],sum([Qty]) as amount,sum(Line_total_cost)as SalesAmount, count(distinct [DocNum]) as InvoiceCount
from CalculatedLines
group by [ItemCode]

--2
select [DocNum]
from [dbo].[SalesLine]
where [ItemCode] in (3611010,3611600) 
group by [DocNum]
having count(distinct [ItemCode])=2
--option 2
SELECT [DocNum] FROM [dbo].[SalesLine] WHERE [ItemCode] =3611010
INTERSECT
SELECT [DocNum] FROM [dbo].[SalesLine] WHERE [ItemCode] = 3611600

--3
select p.[SalesPersonCode],p.[SalesPersonName],count(distinct l.[ItemCode])
from [dbo].[SalesPerson] p
join [dbo].[SalesHeader] h on p.[SalesPersonCode]=h.[SalesPersonCode]
join [dbo].[SalesLine] l on h.DocNum=l.DocNum
group by p.[SalesPersonCode],p.[SalesPersonName]
having count(distinct [ItemCode])=(select count(distinct [ItemCode]) from [dbo].[Items])

--4
--הערה לוגית: השאילתה מתבססת על אנשי מכירות המופיעים בטבלת המכירות 
--(SalesHeader). במידה ויש צורך להתייחס גם לאנשי מכירות רשומים שטרם ביצעו מכירות כאל "המכירה הנמוכה ביותר" 
;with cte as(
select h.[SalesPersonCode],
RANK() over(order by ISNULL(sum(l.qty),0) DESC) as ItemCountDescD,
RANK() over(order by count(distinct l.[ItemCode]) DESC) as ItemVarietyDescD,
RANK() over(order by  ISNULL(count(distinct l.[ItemCode]),0) ASC) as ItemVarietyAscD
from [dbo].[SalesPerson] p
left join [dbo].[SalesHeader] h on p.[SalesPersonCode]=h.[SalesPersonCode]
left join [dbo].[SalesLine] l on h.[DocNum]=l.[DocNum]
group by  h.[SalesPersonCode]
)
select distinct l.[ItemCode]
from [SalesLine] l
join [dbo].[SalesHeader] h on l.DocNum=h.DocNum   
join cte c on h.SalesPersonCode=c.SalesPersonCode
where c.ItemCountDescD=1 or c.ItemVarietyDescD=1

EXCEPT

select distinct l.[ItemCode]
from [SalesLine] l
join [dbo].[SalesHeader] h on l.DocNum=h.DocNum   
join cte c on h.SalesPersonCode=c.SalesPersonCode
where c.ItemVarietyAscD=1 

--5
;WITH LineNet AS (
    SELECT
        sh.SalesPersonCode,
        sp.SalesPersonName,
        sl.ItemCode,
        sl.Qty,
        sl.LineSum - (
            ISNULL(sh.DocDiscount, 0) * sl.LineSum / 
            NULLIF(SUM(sl.LineSum) OVER (PARTITION BY sh.DocNum), 0)
        ) AS NetLineSum
    FROM [dbo].[SalesHeader] sh
    JOIN [dbo].[SalesLine] sl ON sh.DocNum = sl.DocNum
    JOIN [dbo].[SalesPerson] sp ON sh.SalesPersonCode = sp.SalesPersonCode
),
ItemSales AS (
    SELECT
        SalesPersonCode,
        SalesPersonName,
        ItemCode,
        SUM(NetLineSum) AS TotalSalesPerItem,
        SUM(Qty) AS TotalQtyPerItem,
        SUM(NetLineSum) / NULLIF(SUM(Qty), 0) AS AvgPricePerUnit
    FROM LineNet
    GROUP BY SalesPersonCode, SalesPersonName, ItemCode
),
Comparison AS (
    SELECT
        *,
        AVG(AvgPricePerUnit) OVER (PARTITION BY SalesPersonCode) AS SpAvgPricePerUnit
    FROM ItemSales
)

SELECT
    SalesPersonName,
    ItemCode,
    CAST(AvgPricePerUnit AS MONEY) AS [ממוצע מכירות ליחידה],
    CAST(TotalSalesPerItem AS MONEY) AS [סכום המכירות]
FROM Comparison
WHERE AvgPricePerUnit < SpAvgPricePerUnit
ORDER BY SalesPersonName, AvgPricePerUnit ASC;

--6
;WITH SalesByPerson AS (
    SELECT 
        p.SalesPersonCode,
        p.SalesPersonName,
        SUM(ISNULL(l.Qty, 0)) AS TotalQty
    FROM [dbo].[SalesPerson] p
    LEFT JOIN [dbo].[SalesHeader] h ON p.SalesPersonCode = h.SalesPersonCode
    LEFT JOIN [dbo].[SalesLine] l ON h.DocNum = l.DocNum
    GROUP BY p.SalesPersonCode, p.SalesPersonName
),
RunningPercentages AS (
    SELECT 
        SalesPersonCode,
        SalesPersonName,
        TotalQty,
        SUM(TotalQty) OVER(ORDER BY TotalQty DESC) AS RunningTotal,
        SUM(TotalQty) OVER() AS GrandTotal
    FROM SalesByPerson
),
FilteredSalesPeople AS (
    SELECT 
        SalesPersonCode,
        SalesPersonName,
        TotalQty,
        ROUND((CAST(RunningTotal AS FLOAT) / GrandTotal) * 100, 2) AS CumulativePercent
    FROM RunningPercentages
    WHERE (CAST(RunningTotal - TotalQty AS FLOAT) / GrandTotal) < 0.88
)
SELECT 
    f.SalesPersonName,
    h.DocNum,
    h.DocDate,
    SUM(l.Qty) AS InvoiceQty, 
    f.TotalQty AS PersonTotalQty,
    f.CumulativePercent
FROM FilteredSalesPeople f
JOIN [dbo].[SalesHeader] h ON f.SalesPersonCode = h.SalesPersonCode
JOIN [dbo].[SalesLine] l ON h.DocNum = l.DocNum
GROUP BY f.SalesPersonName, h.DocNum, h.DocDate, f.TotalQty, f.CumulativePercent
ORDER BY f.TotalQty DESC, h.DocDate ASC; 

--7
SELECT 
    p.SalesPersonCode,
    p.SalesPersonName,
    
    ISNULL((
        SELECT SUM(l.LineSum - (l.LineSum / CAST(NULLIF(TotalHeader.SumLS, 0) AS MONEY) * ISNULL(h.DocDiscount, 0)))
        FROM SalesHeader h
        JOIN SalesLine l ON h.DocNum = l.DocNum
        CROSS APPLY (
            SELECT SUM(LineSum) AS SumLS 
            FROM SalesLine 
            WHERE DocNum = h.DocNum
        ) AS TotalHeader
        WHERE h.SalesPersonCode = p.SalesPersonCode
    ), 0) AS TotalSalesAmount,

    ISNULL((
        SELECT AVG(InvoiceTotal)
        FROM (
            SELECT h.DocNum, 
                   SUM(l.LineSum - (l.LineSum / CAST(NULLIF(TotalHeader.SumLS, 0) AS MONEY) * ISNULL(h.DocDiscount, 0))) AS InvoiceTotal
            FROM SalesHeader h
            JOIN SalesLine l ON h.DocNum = l.DocNum
            CROSS APPLY (
                SELECT SUM(LineSum) AS SumLS 
                FROM SalesLine 
                WHERE DocNum = h.DocNum
            ) AS TotalHeader
            WHERE h.SalesPersonCode = p.SalesPersonCode
            GROUP BY h.DocNum
        ) AS Invoices
    ), 0) AS AvgInvoiceAmount

FROM SalesPerson p;






