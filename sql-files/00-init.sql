USE [master];
GO

IF NOT EXISTS (SELECT NULL FROM sys.sql_logins WHERE name = 'develop')
BEGIN
    CREATE LOGIN [develop] WITH PASSWORD = 'Password123', CHECK_POLICY = OFF;
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [develop];
END
GO

IF NOT EXISTS(SELECT NULL FROM sys.databases WHERE name = 'yadb')
BEGIN
    CREATE DATABASE yadb
END
GO

USE yadb;
GO
--------------- Post Body table -------------------------------------
IF NOT EXISTS(SELECT NULL FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE t.name = 'PostBody' AND s.name='dbo')
BEGIN
    CREATE TABLE dbo.PostBody (
        BodyID INT NOT NULL IDENTITY(1, 1),
        BodyText TEXT
    )

    ALTER TABLE dbo.PostBody
        ADD CONSTRAINT [pk_PostBody_BodyID] PRIMARY KEY CLUSTERED (BodyID);
END
GO

-------------- Post Category table ----------------------------------
IF NOT EXISTS(SELECT NULL FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE t.name = 'PostCategory' AND s.name='dbo')
BEGIN
    CREATE TABLE dbo.PostCategory (
        CategoryID INT NOT NULL IDENTITY(1, 1),
        ShortName VARCHAR(25) NOT NULL
            CONSTRAINT ixu_PostCategory_ShortName UNIQUE (ShortName)
    )

    ALTER TABLE dbo.PostCategory
        ADD CONSTRAINT [pk_PostCategory_CategoryID] PRIMARY KEY CLUSTERED (CategoryID);

END
GO

-------------- Post table -------------------------------------------
IF NOT EXISTS(SELECT NULL FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id=s.schema_id
WHERE t.name = 'Posts' AND s.name='dbo')
BEGIN
    CREATE TABLE dbo.Posts(
        PostID INT NOT NULL IDENTITY(1, 1),
        CreateDate DATETIME NOT NULL DEFAULT GETDATE(),
        Title VARCHAR(200) NOT NULL,
        Summary VARCHAR(200) NULL,
        CategoryID INT NOT NULL,
        BodyID INT NOT NULL
    )

    ALTER TABLE dbo.Posts
        ADD CONSTRAINT [pk_Posts_PostID] PRIMARY KEY CLUSTERED (PostID);

    ALTER TABLE dbo.Posts
        ADD CONSTRAINT [fk_Posts_PostBody] FOREIGN KEY ([BodyID]) REFERENCES dbo.PostBody ([BodyID]);

    ALTER TABLE dbo.Posts
        ADD CONSTRAINT [fk_Posts_PostCategory] FOREIGN KEY ([CategoryID]) REFERENCES dbo.PostCategory ([CategoryID]);

    CREATE NONCLUSTERED INDEX ix_Posts_CreateDate ON dbo.Posts (CreateDate DESC)

END
GO

----------- Populate Post Category ----------------------------------
IF NOT EXISTS (SELECT NULL FROM dbo.PostCategory pc WHERE pc.ShortName = 'Developer')
    INSERT INTO dbo.PostCategory (ShortName) VALUES ('Developer');
GO

IF NOT EXISTS (SELECT NULL FROM dbo.PostCategory pc WHERE pc.ShortName = 'Disney')
    INSERT INTO dbo.PostCategory (ShortName) VALUES ('Disney');
GO


---------- Stored Proc Insert new post ------------------------------
CREATE OR ALTER PROCEDURE dbo.InsertPost
    @title VARCHAR(200),
    @category VARCHAR(25),
    @body TEXT,
    @summary VARCHAR(200) = NULL,
    @create_date DATETIME = NULL
AS
BEGIN
    INSERT INTO dbo.PostBody (BodyText) VALUES (@body);

    DECLARE @body_id INT = (SELECT SCOPE_IDENTITY());
    DECLARE @category_id INT = (SELECT c.CategoryID FROM dbo.PostCategory AS c WHERE c.ShortName = @category)

    IF @category_id IS NULL
    BEGIN
        INSERT INTO dbo.PostCategory (ShortName) VALUES (@category);
        SET @category_id = (SELECT SCOPE_IDENTITY());
    END

    IF @create_date IS NULL
        SET @create_date = GETDATE();

    INSERT INTO dbo.Posts(CreateDate, Title, Summary, CategoryID, BodyID) VALUES (@create_date, @title, @summary, @category_id, @body_id)
END
GO
------------ Stored Proc Get Category -------------------------------
CREATE OR ALTER PROCEDURE dbo.GetCategories
AS
BEGIN
    SELECT c.CategoryID, ShortName FROM dbo.PostCategory AS c;
END
GO

------------ Stored Proc Get Posts ----------------------------------
CREATE OR ALTER PROCEDURE dbo.GetPosts
    @category VARCHAR(25) = NULL
AS
BEGIN
    SELECT p.*, pc.ShortName FROM dbo.Posts AS p
        INNER JOIN dbo.PostCategory pc ON pc.CategoryID = p.CategoryID
    WHERE (@category IS NULL OR pc.ShortName = @category)
    ORDER BY p.CreateDate DESC
END
GO

------------ Stored Proc Get Post ----------------------------------
CREATE OR ALTER PROCEDURE dbo.GetPost
    @post_id INT
AS
BEGIN
    SELECT p.*, pc.ShortName, pb.BodyText FROM dbo.Posts AS p
        INNER JOIN dbo.PostBody pb ON p.BodyID = pb.BodyID
        INNER JOIN dbo.PostCategory pc ON pc.CategoryID = p.CategoryID
    WHERE p.PostID = @post_id
END
GO

------------ Stored Proc Update Category ----------------------------
CREATE OR ALTER PROCEDURE dbo.UpdateCategory
    @category_id INT,
    @short_name VARCHAR(25)
AS
BEGIN
    UPDATE dbo.PostCategory
    SET ShortName = @short_name
    WHERE CategoryID = @category_id
END
GO

------------- Stored Proc Update Body -------------------------------
CREATE OR ALTER PROCEDURE dbo.UpdateBody
    @body_id INT,
    @body_text TEXT
AS
BEGIN
    UPDATE dbo.PostBody
    SET BodyText = @body_text
    WHERE BodyID = @body_id
END
GO

------------ Stored Proc Update Post --------------------------------
CREATE OR ALTER PROCEDURE dbo.UpdatePost
    @post_id INT,
    @create_date DATETIME = NULL,
    @title VARCHAR(200) = NULL,
    @summary VARCHAR(200) = NULL,
    @category VARCHAR(25) = NULL
AS
BEGIN
    IF EXISTS (SELECT NULL FROM dbo.Posts p WHERE p.PostID = @post_id)
    BEGIN
        DECLARE @category_id INT = (SELECT pc.CategoryID FROM dbo.PostCategory pc WHERE pc.ShortName = @category)

        UPDATE dbo.Post
        SET CreateDate = ISNULL(@create_date, CreateDate),
            Title = ISNULL(@title, Title),
            Summary = ISNULL(@summary, Summary),
            CategoryID = ISNULL(@category_id,  CategoryID)
        WHERE PostID = @post_id
    END
END
GO
