CREATE PROCEDURE [reduceColumnWidth]
  @schemaName varchar(MAX),
  @tableName varchar(MAX)
AS
BEGIN

DECLARE @SQL_COMMAND VARCHAR(MAX) = ''

IF OBJECT_ID('tempdb..#TMP') IS NOT NULL DROP TABLE #TMP

SELECT
  IDENTITY(int,1,1) as ID,
  'ALTER TABLE [' + c.TABLE_SCHEMA + '].[' + c.TABLE_NAME + '] ' +
  'ALTER COLUMN [' + c.COLUMN_NAME + '] ' + c.DATA_TYPE +
  '(' P1,
  'MAX(LEN([' + c.COLUMN_NAME + '])' + ') FROM [' + c.TABLE_SCHEMA + '].[' + c.TABLE_NAME + ']' P2,
  ') ' P3,
  '[' + c.TABLE_SCHEMA + ']' P4,
  '[' + c.TABLE_NAME + ']' P5
INTO #TMP
FROM INFORMATION_SCHEMA.Tables t
JOIN INFORMATION_SCHEMA.Columns c
ON c.TABLE_CATALOG = t.TABLE_CATALOG
  AND c.TABLE_SCHEMA = t.TABLE_SCHEMA
  AND c.TABLE_NAME = t.TABLE_NAME
WHERE TABLE_TYPE = 'BASE_TABLE'
  AND DATA_TYPE IN ('nvarchar', 'varchar')
  AND c.TABLE_SCHEMA = @schemaName
  AND c.TABLE_NAME = @tableName

SELECT @SQL_COMMAND=@SQL_COMMAND + 'SELECT' + CAST(ID as varchar(10)) + ', ' + P2 + CHAR(13) FROM #TMP

DECLARE @tbl table (ID Integer, Size Integer)

DECLARE @cmdCursor CURSOR
DECLARE @stmt VARCHAR(MAX) = ''

SET ANSI_WARNINGS OFF
SET NOCOUNT ON

SET @cmdCursor = CURSOR FOR
  SELECT 'SELECT ' + CAST(ID as VARCHAR(10)) + ', ' + P2 + CHAR(13) FROM #TMP

  OPEN @cmdCursor
  FETCH NEXT FROM @cmdCursor
  INTO @stmt

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      BEGIN TRANSACTION
        INSERT INTO @tbl EXEC (@stmt)
      COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
      ROLLBACK TRANSACTION
        SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    FETCH NEXT FROM @cmdCursor INTO @stmt
  END;

  CLOSE @cmdCursor

SET ANSI_WARNINGS ON
SET NOCOUNT OFF

UPDATE @tbl SET Size = 1 WHERE Size IS NULL

UPDATE #TMP SET P2 = CASE WHEN Size < 1 THEN 1 ELSE Size END
FROM @tbl tbl WHERE tbl.ID = #TMP.ID AND tbl.Size IS NOT NULL

DELETE row from #TMP row WHERE row.P2 > 2000

SET @cmdCursor = CURSOR FOR
  SELECT P1 + P2 + P3 + CHAR(13) FROM #TMP

  OPEN @cmdCursor
  FETCH NEXT FROM @cmdCursor
  INTO @stmt

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      BEGIN TRANSACTION
        EXEC (@stmt)
      END TRANSACTION
    END TRY
    BEGIN CATCH
      ROLLBACK TRANSACTION
      SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
    FETCH NEXT FROM @cmdCursor INTO @stmt
  END;

  DEALLOCATE @cmdCursor

DROP TABLE #TMP
