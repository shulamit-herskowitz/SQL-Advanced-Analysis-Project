-- Part D
USE [LogicalProject];
GO

-- Custom String Reversal Function
-- Logic: Iterates through the input string from last character to first to build a reversed string.
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

-- Usage Demonstration
-- Applying the custom function to the SalesPersonName column
SELECT 
    SalesPersonName, 
    dbo.MyCustomReverse(SalesPersonName) AS ReversedName
FROM [dbo].[SalesPerson];
