use [LogicalProject]

;WITH MarkGroupStart AS (
    SELECT
        *,
        CASE 
            WHEN LAG(TEUR) OVER (ORDER BY SHURA) IS NULL THEN 1
            ELSE 0
        END AS IsNewGroup
    FROM dbo.Items
),
AssignGroupID AS (
    SELECT
        *,
        SUM(IsNewGroup) OVER (ORDER BY SHURA ROWS UNBOUNDED PRECEDING) AS GroupID
    FROM MarkGroupStart
),
FillKoteret AS (
    SELECT
        A,
        SHURA,
        TEUR,
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
