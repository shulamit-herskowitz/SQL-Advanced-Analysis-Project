-- Part E
USE [LogicalProject];

-- Logic: Filling missing header values (KOTERET) based on grouped records.
-- The process identifies the start of a new group and propagates the header value 
-- to all subsequent rows within that group.

;WITH MarkGroupStart AS (
    SELECT
        *,
        -- Identify the first row of each group (where the previous TEUR was NULL)
        CASE 
            WHEN LAG(TEUR) OVER (ORDER BY SHURA) IS NULL THEN 1
            ELSE 0
        END AS IsNewGroup
    FROM dbo.Items
),
AssignGroupID AS (
    SELECT
        *,
        -- Generate a unique ID for each group using a running total of the start flags
        SUM(IsNewGroup) OVER (ORDER BY SHURA ROWS UNBOUNDED PRECEDING) AS GroupID
    FROM MarkGroupStart
),
FillKoteret AS (
    SELECT
        A,
        SHURA,
        TEUR,
        -- Use FIRST_VALUE to grab the header (TEUR) of each group partition
        FIRST_VALUE(TEUR) OVER (PARTITION BY GroupID ORDER BY SHURA) AS KOTERET
    FROM AssignGroupID
)
SELECT
    A,
    SHURA,
    TEUR,
    KOTERET
FROM FillKoteret
ORDER BY SHURA;
