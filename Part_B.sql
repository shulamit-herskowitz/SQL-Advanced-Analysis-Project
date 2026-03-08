-- Part B
USE [LogicalProject];

-- Problem A: Identify the most "demanding" user based on request density (RPM)
-- Logic: Out of all demanding users, selecting the one with the highest average request density.
-- Assumption: Request density is the primary factor impacting system performance.

;WITH UserBursts AS (
    -- Step 1: Identify instances exceeding the threshold of 10 requests within 5 minutes
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
    -- Step 2: Calculate intensity (Requests Per Minute - RPM) for each burst
    SELECT 
        UserID,
        CAST(RequestCount AS FLOAT) / 
             NULLIF(DATEDIFF(SECOND, WindowStart, WindowEnd) / 60.0, 0) AS RequestsPerMinute
    FROM UserBursts
),
UserPeakIntensity AS (
    -- Step 3: Find the peak intensity for each user
    SELECT 
        UserID,
        MAX(RequestsPerMinute) AS MaxRPM
    FROM BurstsWithMetrics
    GROUP BY UserID
)
-- Select the user(s) with the absolute maximum intensity in the system
SELECT TOP 1 WITH TIES
    UserID
FROM UserPeakIntensity
ORDER BY MaxRPM DESC;

-- Problem B: Dynamic Solution - Building a decision table based on the timeline
-- Goal: Maximize total priority while avoiding overlapping requests.

-- 1. Prepare a temporary table with requests ordered by completion time (Essential for DP)
SELECT 
    ROW_NUMBER() OVER (ORDER BY ResponseTime ASC) AS StepID,
    RequestID, Priority, RequestTime, ResponseTime
INTO #OrderedRequests
FROM UserRequests
WHERE ResponseTime <= ExpirationTime;

-- 2. Use CTE to implement the Dynamic Programming (DP) recursion formula
WITH DP_Table AS (
    -- Base Case: The first request
    SELECT 
        StepID,
        Priority AS BestPriority,
        CAST(RequestID AS VARCHAR(MAX)) AS BestPath,
        ResponseTime AS LastEnd
    FROM #OrderedRequests
    WHERE StepID = 1

    UNION ALL

    -- Dynamic Step: Decide whether to include the current request or keep the previous best state
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
-- 3. The final result is the last row in the dynamic table
SELECT TOP 1 BestPath, BestPriority
FROM DP_Table
ORDER BY StepID DESC;

DROP TABLE #OrderedRequests;

-- Problem C: System Bottleneck Analysis
;WITH SortedReqs AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY RequestTime) AS ID,
        RequestTime, 
        ResponseTime,
        CAST(DATEDIFF(SECOND, RequestTime, ResponseTime) AS FLOAT) AS WaitTime
    FROM UserRequests
),
RecursiveBottleneck AS (
    -- Anchor Member
    SELECT 
        ID,
        RequestTime AS StartTime,
        ResponseTime AS EndTime,
        WaitTime AS TotalWait,
        CAST(1 AS FLOAT) AS RequestCount 
    FROM SortedReqs

    UNION ALL

    -- Recursive Member
    SELECT 
        S.ID,
        R.StartTime,
        CASE WHEN S.ResponseTime > R.EndTime THEN S.ResponseTime ELSE R.EndTime END,
        R.TotalWait + S.WaitTime,
        R.RequestCount + 1 
    FROM SortedReqs S
    INNER JOIN RecursiveBottleneck R ON S.ID = R.ID + 1
)
-- Find the interval with the highest average wait time
SELECT TOP 1 WITH TIES
    StartTime AS IntervalStart,
    EndTime AS IntervalEnd,
    (TotalWait / RequestCount) AS MaxAverageWaitTime,
    CAST(RequestCount AS INT) AS RequestsInInterval
FROM RecursiveBottleneck
ORDER BY (TotalWait / RequestCount) DESC;
