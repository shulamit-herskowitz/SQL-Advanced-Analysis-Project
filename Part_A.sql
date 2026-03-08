USE LogicalProject;

-- 1
-- Note: Since the discount is at the invoice header level, it is distributed across line items proportionally to their relative sum.
WITH CalculatedLines AS (
    SELECT 
        l.[DocNum], 
        l.[ItemCode], 
        l.[Qty],
        l.[LineSum] - (
            l.[LineSum] / CAST(NULLIF(SUM(l.[LineSum]) OVER(PARTITION BY l.[DocNum]), 0) AS MONEY)
            * ISNULL(h.[DocDiscount], 0)
        ) AS Line_total_cost
    FROM [dbo].[SalesLine] l
    JOIN [dbo].[SalesHeader] h ON l.[DocNum] = h.[DocNum]
)
SELECT 
    [ItemCode],
    SUM([Qty]) AS TotalQuantity,
    SUM(Line_total_cost) AS SalesAmount, 
    COUNT(DISTINCT [DocNum]) AS InvoiceCount
FROM CalculatedLines
GROUP BY [ItemCode];

-- 2
SELECT [DocNum]
FROM [dbo].[SalesLine]
WHERE [ItemCode] IN (3611010, 3611600) 
GROUP BY [DocNum]
HAVING COUNT(DISTINCT [ItemCode]) = 2;

-- Option 2
SELECT [DocNum] FROM [dbo].[SalesLine] WHERE [ItemCode] = 3611010
INTERSECT
SELECT [DocNum] FROM [dbo].[SalesLine] WHERE [ItemCode] = 3611600;

-- 3
SELECT 
    p.[SalesPersonCode],
    p.[SalesPersonName],
    COUNT(DISTINCT l.[ItemCode]) AS DistinctItemsSold
FROM [dbo].[SalesPerson] p
JOIN [dbo].[SalesHeader] h ON p.[SalesPersonCode] = h.[SalesPersonCode]
JOIN [dbo].[SalesLine] l ON h.DocNum = l.DocNum
GROUP BY p.[SalesPersonCode], p.[SalesPersonName]
HAVING COUNT(DISTINCT [ItemCode]) = (SELECT COUNT(DISTINCT [ItemCode]) FROM [dbo].[Items]);

-- 4
-- Logic Note: This query focuses on salespeople present in the SalesHeader table. 
-- To include registered salespeople who haven't made any sales as "lowest performers", use a LEFT JOIN.
WITH cte AS (
    SELECT 
        h.[SalesPersonCode],
        RANK() OVER(ORDER BY ISNULL(SUM(l.qty), 0) DESC) AS ItemCountDescD,
        RANK() OVER(ORDER BY COUNT(DISTINCT l.[ItemCode]) DESC) AS ItemVarietyDescD,
        RANK() OVER(ORDER BY ISNULL(COUNT(DISTINCT l.[ItemCode]), 0) ASC) AS ItemVarietyAscD
    FROM [dbo].[SalesPerson] p
    LEFT JOIN [dbo].[SalesHeader] h ON p.[SalesPersonCode] = h.[SalesPersonCode]
    LEFT JOIN [dbo].[SalesLine] l ON h.[DocNum] = l.[DocNum]
    GROUP BY h.[SalesPersonCode]
)
SELECT DISTINCT l.[ItemCode]
FROM [SalesLine] l
JOIN [dbo].[SalesHeader] h ON l.DocNum = h.DocNum   
JOIN cte c ON h.SalesPersonCode = c.SalesPersonCode
WHERE c.ItemCountDescD = 1 OR c.ItemVarietyDescD = 1

EXCEPT

SELECT DISTINCT l.[ItemCode]
FROM [SalesLine] l
JOIN [dbo].[SalesHeader] h ON l.DocNum = h.DocNum   
JOIN cte c ON h.SalesPersonCode = c.SalesPersonCode
WHERE c.ItemVarietyAscD = 1;

-- 5
WITH LineNet AS (
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
    CAST(AvgPricePerUnit AS MONEY) AS AvgSalesPerUnit,
    CAST(TotalSalesPerItem AS MONEY) AS TotalSalesAmount
FROM Comparison
WHERE AvgPricePerUnit < SpAvgPricePerUnit
ORDER BY SalesPersonName, AvgPricePerUnit ASC;

-- 6
WITH SalesByPerson AS (
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

-- 7
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
