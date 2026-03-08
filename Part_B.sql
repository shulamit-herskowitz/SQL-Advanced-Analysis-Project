--part b
use [LogicalProject]

-- בעיה א'-מתוך כל המשתמשים התובעניים לקחתי את מי שממוצע הצפיפות של הבקשות שלו היא הגדולה ביותר
--בעקבות הנתונים שמגדירים משתמש כתובעני שיערתי שהגורם העיקרי שמפריע בתובענות למערכת הוא הצפיפות  

;WITH UserBursts AS (
    -- שלב 1: זיהוי כל חריגה מהרף של 10 פניות ב-5 דקות
    SELECT 
        T1.UserID,
        T1.RequestTime AS WindowStart,
        MAX(T2.RequestTime) AS WindowEnd,
        COUNT(T2.RequestID) AS RequestCount
    FROM UserRequests T1
    JOIN UserRequests T2 ON T1.UserID = T2.UserID 
        AND T2.RequestTime BETWEEN T1.RequestTime AND DATEADD(MINUTE, 5, T1.RequestTime)
    GROUP BY T1.UserID, T1.RequestTime 
    HAVING COUNT(T2.RequestID) > 10
),
BurstsWithMetrics AS (
    --  חישוב רמת התובענות (עצימות RPM) לכל חריגה
    SELECT 
        UserID,
        CAST(RequestCount AS FLOAT) / 
             NULLIF(DATEDIFF(SECOND, WindowStart, WindowEnd) / 60.0, 0) AS RequestsPerMinute
    FROM UserBursts
),
UserPeakIntensity AS (
    --  מציאת שיא התובענות לכל משתמש
    SELECT 
        UserID,
        MAX(RequestsPerMinute) AS MaxRPM
    FROM BurstsWithMetrics
    GROUP BY UserID
)
--  שליפת המשתמש (או המשתמשים) עם רמת התובענות המקסימלית במערכת
SELECT TOP 1 WITH TIES
    UserID
FROM UserPeakIntensity
ORDER BY MaxRPM DESC;

-- בעיה ב
-- פתרון דינמי: בניית טבלת החלטות לפי ציר זמן 

-- 1. נכין טבלה זמנית עם הבקשות מסודרות לפי זמן סיום (קריטי ל-DP)
SELECT 
    ROW_NUMBER() OVER (ORDER BY ResponseTime ASC) AS StepID,
    RequestID, Priority, RequestTime, ResponseTime
INTO #OrderedRequests
FROM UserRequests
WHERE ResponseTime <= ExpirationTime;

-- 2. שימוש ב-CTE כדי לממש את נוסחת הנסיגה של התכנון הדינמי
WITH DP_Table AS (
    -- מקרה בסיס: הבקשה הראשונה
    SELECT 
        StepID,
        Priority AS BestPriority,
        CAST(RequestID AS VARCHAR(MAX)) AS BestPath,
        ResponseTime AS LastEnd
    FROM #OrderedRequests
    WHERE StepID = 1

    UNION ALL

    -- שלב דינמי: האם כדאי להוסיף את הבקשה הנוכחית או להישאר עם מה שיש?
    SELECT 
        R.StepID,
        CASE 
            WHEN R.Priority + Prev.BestPriority > Prev.BestPriority 
                 AND R.RequestTime >= Prev.LastEnd THEN R.Priority + Prev.BestPriority
            ELSE Prev.BestPriority
        END,
        CASE 
            WHEN R.Priority + Prev.BestPriority > Prev.BestPriority 
                 AND R.RequestTime >= Prev.LastEnd THEN Prev.BestPath + ',' + CAST(R.RequestID AS VARCHAR(MAX))
            ELSE Prev.BestPath
        END,
        CASE 
            WHEN R.Priority + Prev.BestPriority > Prev.BestPriority 
                 AND R.RequestTime >= Prev.LastEnd THEN R.ResponseTime
            ELSE Prev.LastEnd
        END
    FROM #OrderedRequests R
    JOIN DP_Table Prev ON R.StepID = Prev.StepID + 1
)
-- 3. התוצאה הסופית היא השורה האחרונה בטבלה הדינמית
SELECT TOP 1 BestPath, BestPriority
FROM DP_Table
ORDER BY StepID DESC;

DROP TABLE #OrderedRequests;

-- בעיה ג
;WITH SortedReqs AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY RequestTime) AS ID,
        RequestTime, 
        ResponseTime,
        CAST(DATEDIFF(SECOND, RequestTime, ResponseTime) AS FLOAT) AS WaitTime
    FROM UserRequests
),
RecursiveBottleneck AS (
    -- חלק העוגן (Anchor)
    SELECT 
        ID,
        RequestTime AS StartTime,
        ResponseTime AS EndTime,
        WaitTime AS TotalWait,
        CAST(1 AS FLOAT) AS RequestCount -- התיקון כאן: הגדרת סוג הנתונים כ-FLOAT
    FROM SortedReqs

    UNION ALL

    -- החלק הרקורסיבי
    SELECT 
        S.ID,
        R.StartTime,
        CASE WHEN S.ResponseTime > R.EndTime THEN S.ResponseTime ELSE R.EndTime END,
        R.TotalWait + S.WaitTime,
        R.RequestCount + 1 
    FROM SortedReqs S
    INNER JOIN RecursiveBottleneck R ON S.ID = R.ID + 1
)
SELECT TOP 1 WITH TIES
    StartTime AS IntervalStart,
    EndTime AS IntervalEnd,
    (TotalWait / RequestCount) AS MaxAverageWaitTime,
    CAST(RequestCount AS INT) AS RequestsInInterval
FROM RecursiveBottleneck
ORDER BY (TotalWait / RequestCount) DESC;