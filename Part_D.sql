use [LogicalProject]
go

--חלק ד
CREATE FUNCTION dbo.MyCustomReverse (@InputString NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @ReversedString NVARCHAR(MAX) = '';
    DECLARE @CurrentPos INT;
    SET @CurrentPos = LEN(@InputString);

    WHILE @CurrentPos > 0
    BEGIN
        SET @ReversedString = @ReversedString + SUBSTRING(@InputString, @CurrentPos, 1);
        SET @CurrentPos = @CurrentPos - 1;
    END

    RETURN @ReversedString;
END;
GO
--הדגמת שימוש
-- שימוש בפונקציה על שם איש המכירות
SELECT 
    SalesPersonName, 
    dbo.MyCustomReverse(SalesPersonName) AS ReversedName
FROM [dbo].[SalesPerson];
