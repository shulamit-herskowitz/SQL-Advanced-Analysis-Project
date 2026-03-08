use [LogicalProject]
--חלק ג
--סעיף א
/* פתרון לחלק ג' - מציאת שלשות בטבלה A שסכומן X */

DECLARE @X INT = 32;

SELECT 
    T1.Val AS Num1, 
    T2.Val AS Num2, 
    T3.Val AS Num3,
    (T1.Val + T2.Val + T3.Val) AS TotalSum
FROM TableA T1
CROSS JOIN TableA T2
CROSS JOIN TableA T3
WHERE (T1.Val + T2.Val + T3.Val) = @X
ORDER BY Num1, Num2, Num3;

--סעיף ב
SELECT 
    T1.Val AS num1, 
    T2.Val AS num2, 
    T3.Val AS num3
INTO #temp_table
FROM TableA T1
JOIN TableA T2 ON T1.Val < T2.Val  
JOIN TableA T3 ON T2.Val < T3.Val  
WHERE (T1.Val + T2.Val + T3.Val) = @x;

--סעיף ג
SELECT TOP 1 
    num1, 
    num2, 
    num3,
    (num1 * num2 * num3) AS MaxProduct
FROM #temp_table
ORDER BY (num1 * num2 * num3) DESC;
DROP TABLE #temp_table;

