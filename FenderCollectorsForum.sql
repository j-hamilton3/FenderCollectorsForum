-- Final Project : DBMS 2006, Buck Hothi
-- James Hamilton
-- November 28, 2023

-- Create the Users table.
CREATE TABLE Users (
	userID INT NOT NULL,
	username VARCHAR(20) NOT NULL,
	email VARCHAR(50) NOT NULL,
	password VARCHAR(20) NOT NULL,
	firstName VARCHAR(20) NOT NULL,
	lastName VARCHAR(20) NOT NULL
	CONSTRAINT PK_Users
		PRIMARY KEY (userID),
);

-- Create the Basses table.
CREATE TABLE Basses (
	serialNumber VARCHAR(30) NOT NULL,
	noOfStrings INT NOT NULL,
	modelName VARCHAR(20),
	year INT,
	preamp VARCHAR(30),
	userID INT NOT NULL,
	CONSTRAINT PK_Basses
		PRIMARY KEY (serialNumber),
	CONSTRAINT OwnsFK
		FOREIGN KEY (userID)
		REFERENCES Users
);

-- Create the Posts table.
CREATE TABLE Posts (
	postID INT NOT NULL,
	title VARCHAR(30) NOT NULL,
	content VARCHAR(600) NOT NULL,
	date DATETIME NOT NULL,
	userID INT NOT NULL,
	serialNumber VARCHAR(30) NOT NULL,
	CONSTRAINT PK_Posts
		PRIMARY KEY (postID),
	CONSTRAINT PostsFK
		FOREIGN KEY (userID)
		REFERENCES Users,
	CONSTRAINT BelongsFK
		FOREIGN KEY (serialNumber)
		REFERENCES Basses
);

-- Create the Comments table.
CREATE TABLE Comments (
	commentID INT NOT NULL,
	content VARCHAR(300) NOT NULL,
	date DATETIME NOT NULL,
	userID INT NOT NULL,
	postID INT NOT NULL,
	CONSTRAINT PK_Comments
		PRIMARY KEY (commentID),
	CONSTRAINT CommentsFK
		FOREIGN KEY (userID)
		REFERENCES Users,
	CONSTRAINT AddsFK
		FOREIGN KEY (postID)
		REFERENCES Posts
);

-- Create a CHECK constraint. Makes sure Basses have more than 0 strings.
ALTER TABLE Basses
	ADD CONSTRAINT CK_noOfStrings 
	CHECK (noOfStrings > 0);

-- Create two Indexes. Used for columns frequently involved in search conditions (this case JOIN),
-- speeds up data retrieval by avoiding need to scan entire table. Points to rows location in memory.
CREATE NONCLUSTERED INDEX IX_PostsUserID
	ON Posts (userID);

CREATE NONCLUSTERED INDEX IX_CommentsPostID
	ON Comments (postID);
	GO;

-- A trigger that adds the "Passive" to a bass's preamp column if it is left null.
CREATE OR ALTER TRIGGER TR_Basses_Preamp 
	ON Basses 
	AFTER INSERT 
	AS 
	BEGIN
		UPDATE Basses
		SET preamp = 'Passive'
		WHERE serialNumber IN (SELECT serialNumber FROM inserted WHERE preamp IS NULL);
	END;
	GO

-- Insert a bass into the table to demonstrate trigger.
INSERT INTO Basses (serialNumber, noOfStrings, modelName, year, preamp, userID)
	VALUES ('11111', 4, 'Test Bass', 2023, NULL, 1);
GO

-- Select the inserted bass to demonstrate trigger.
 SELECT * FROM Basses
	WHERE serialNumber = '11111';
	GO

DELETE FROM Basses
	WHERE serialNumber = '11111';
	GO
-- Create two Views that operate or restrict data in some way.

-- View 1: Display users while filtering out sensitive data. (Passwords.)
CREATE OR ALTER VIEW Users_Contact AS
	SELECT u.email, u.username, CONCAT(u.firstName, ' ', u.lastName)  AS "Full Name"
	FROM Users u;
GO

SELECT * FROM Users_Contact;
GO

-- View 2: A view to display basses dated before the year 2000.
CREATE OR ALTER VIEW Vintage_Basses AS
	SELECT *
	FROM Basses
	WHERE year < 2000;
GO

SELECT * FROM Vintage_Basses;
GO

-- Function to get total number of strings for a user.
CREATE OR ALTER FUNCTION dbo.GetTotalStringsForUser(@userID INT)
RETURNS INT
AS
BEGIN
    DECLARE @TotalStrings INT;

    SELECT @TotalStrings = SUM(noOfStrings)
    FROM Basses
    WHERE userID = @userID;

    RETURN ISNULL(@TotalStrings, 0);
END;
GO

-- Demonstrate the use of the function.
DECLARE @UserIDToCheck INT = 1; 

DECLARE @TotalStringsForUser INT = dbo.GetTotalStringsForUser(@UserIDToCheck);

PRINT 'Total number of strings for User ID ' + CAST(@UserIDToCheck AS VARCHAR) + ': ' + CAST(@TotalStringsForUser AS VARCHAR);

-- Inner join to retrieve data from Users, Basses, and Posts tables.
SELECT
    U.userID,
    U.username,
    U.email,
    B.serialNumber,
    B.noOfStrings,
    B.modelName,
    B.year,
    B.preamp,
    P.postID,
    P.title,
    P.content,
    P.date
FROM
    Users U
JOIN
    Basses B ON U.userID = B.userID
JOIN
    Posts P ON B.serialNumber = P.serialNumber;

-- Outer join to retrieve basses and users that own them but have not been posted about.
SELECT
    U.userID,
    U.username,
    U.email,
    B.serialNumber,
    B.noOfStrings,
    B.modelName,
    B.year,
    B.preamp
FROM
    Users U
JOIN
    Basses B ON U.userID = B.userID
LEFT JOIN
    Posts P ON B.serialNumber = P.serialNumber
WHERE
    P.postID IS NULL;


-- ** START OF SECOND EVAL **

-- Create the BassAuditLog table, not for marks!
CREATE TABLE BassesAuditLog (
    logID INT IDENTITY(1,1) NOT NULL, 
    serialNumber VARCHAR(30) NOT NULL,
    oldModelName VARCHAR(20), 
    newModelName VARCHAR(20), 
    oldYear INT, 
    newYear INT, 
    oldPreamp VARCHAR(30),
    newPreamp VARCHAR(30), 
    updateDate DATETIME NOT NULL, 
);
GO

-- Stored Procedure with use of transaction.

/*
 * James Hamilton
 * December 8, 2023
 * Updates a basses information, and sends the log of the update to the BassAuditLog table.
 */
CREATE OR ALTER PROCEDURE usp_UpdateBassAndLog
    @serialNumber VARCHAR(30),
    @newModelName VARCHAR(20),
    @newYear INT,
    @newPreamp VARCHAR(30)
AS
BEGIN
    -- Start the transaction.
    BEGIN TRANSACTION;

    BEGIN TRY -- Try of try/catch block.
        DECLARE 
        @oldModelName VARCHAR(20),
        @oldYear INT,
        @oldPreamp VARCHAR(30)

        SELECT @oldModelName = modelName, @oldYear = year, @oldPreamp = preamp
        FROM Basses
        WHERE serialNumber = @serialNumber;

        -- Update the new specs for the bass.
        UPDATE Basses
        SET modelName = @newModelName,
            year = @newYear,
            preamp = @newPreamp
        WHERE serialNumber = @serialNumber;

        -- Log the changes into the BassesAuditLog table.
        INSERT INTO BassesAuditLog (serialNumber, oldModelName, newModelName, oldYear, newYear, oldPreamp, newPreamp, updateDate)
        VALUES (@serialNumber, @oldModelName, @newModelName, @oldYear, @newYear, @oldPreamp, @newPreamp, GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- If an error occurs, rollback the changes.
        ROLLBACK TRANSACTION;
    END CATCH
END;
GO

-- Demonstrate the stored procedure.

-- Drop the bass if it exists.
DELETE FROM Basses WHERE serialNumber = 'Test123';

-- Add record for testing to Basses.
INSERT INTO Basses (serialNumber, noOfStrings, modelName, year, preamp, userID)
VALUES ('Test123', 4, 'TestModel', 2020, 'Testpreamp', 1);
GO

-- Execute the stored procedure to update the bass and log the update
EXEC usp_UpdateBassAndLog 
    @serialNumber = 'Test123',
    @newModelName = 'WorkingModel',
    @newYear = 2021,
    @newPreamp = 'WorkingPreamp';
GO

-- Verify the update in the Basses table
SELECT * FROM Basses WHERE serialNumber = 'Test123';
GO

-- Check the audit log in the BassesAuditLog table
SELECT * FROM BassesAuditLog WHERE serialNumber = 'Test123';
GO

-- A non-correlated subquery, selects users who own a bass with more than 5 strings.
SELECT U.username, U.email 
FROM Users U
WHERE U.userID IN (
    SELECT B.userID
    FROM Basses B
    WHERE B.noOfStrings > 5
);
GO

-- A correlated subquery, selects users that have no basses registered.
SELECT U.userID, U.username, U.email 
FROM Users U
WHERE (
    SELECT COUNT(*)
    FROM Basses B
    WHERE B.userID = U.userID
) < 1; 
GO

-- Aggregate the data, display number of posts for each user.
SELECT userID As "User ID", 
	   COUNT(*) AS "Number of Posts"
FROM Posts
GROUP BY userID;

-- Create logins and users for the roles.
CREATE LOGIN RestrictedUser WITH password='Secret555', DEFAULT_DATABASE=FenderCollectorsForum, CHECK_POLICY=OFF;
CREATE USER RestUser FOR LOGIN RestrictedUser WITH Default_Schema= [DBO];

CREATE LOGIN RegularUser WITH password='Secret555', DEFAULT_DATABASE=FenderCollectorsForum, CHECK_POLICY=OFF;
CREATE USER RUser FOR LOGIN RegularUser WITH Default_Schema= [DBO];

CREATE LOGIN ModeratorUser WITH password='Secret555', DEFAULT_DATABASE=FenderCollectorsForum, CHECK_POLICY=OFF;
CREATE USER MUser FOR LOGIN ModeratorUser WITH Default_Schema= [DBO];

-- Create the three roles.
CREATE ROLE restricted_role;
CREATE ROLE regular_role;
CREATE ROLE moderator_role;

-- Grant permissions to the roles.
GRANT SELECT ON Basses TO restricted_role;
GRANT SELECT ON Posts TO restricted_role;
GRANT SELECT ON Comments TO restricted_role;

GRANT SELECT, INSERT ON Basses TO regular_role;
GRANT SELECT, INSERT ON Posts TO regular_role;
GRANT SELECT, INSERT ON Comments TO regular_role;

GRANT SELECT ON Users TO moderator_role;
GRANT SELECT, INSERT, DELETE ON Basses TO moderator_role;
GRANT SELECT, INSERT, DELETE ON Posts TO moderator_role;
GRANT SELECT, INSERT, DELETE ON Comments TO moderator_role;

-- Assign users to the roles.
EXEC sp_addrolemember 'restricted_role', 'RestUser';
EXEC sp_addrolemember 'regular_role', 'RUser';
EXEC sp_addrolemember 'moderator_role', 'MUser';

-- Demonstrate the roles.

-- Restricted role.
REVERT;
EXECUTE AS user='RestUser';
SELECT user;

SELECT * FROM Users; -- Permission Denied, can't access users.
SELECT * FROM Basses; -- Has permission.
SELECT * FROM Posts; -- Has permission.
SELECT * FROM Comments; -- Has permission.

-- Regular role.
REVERT;
EXECUTE AS user='RUser';
SELECT user;

SELECT * FROM Users; -- Permission Denied, can't access users.
SELECT * FROM Basses; -- Has permission.
SELECT * FROM Posts; -- Has permission.
SELECT * FROM Comments; -- Has permission.

INSERT INTO Basses(serialNumber, noOfStrings, modelName, year, preamp, userID)
	VALUES ('RUSER123', 4, 'Test Model', 2000, 'Passive', 1); -- Has Permission

INSERT INTO Posts(postID, title, content, date, userID, serialNumber)
	VALUES (101, 'RUSER', 'RUSERTEST', GETDATE(), 1, 'RUSER123'); --Has Permission

INSERT INTO Comments(commentID, content, date, userID, postID)
	VALUES (101, 'RUSERTEST', GETDATE(), 1, 101); --Has Permission

DELETE FROM Comments WHERE commentID = 101; -- Permission denied.

-- Moderator Role
REVERT;
EXECUTE AS user='MUser';
SELECT user;

SELECT * FROM Users; -- Has permission.
SELECT * FROM Basses; -- Has permission.
SELECT * FROM Posts; -- Has permission.
SELECT * FROM Comments; -- Has permission.

INSERT INTO Basses(serialNumber, noOfStrings, modelName, year, preamp, userID)
	VALUES ('MUSER123', 4, 'Test Model', 2000, 'Passive', 1); -- Has Permission

INSERT INTO Posts(postID, title, content, date, userID, serialNumber)
	VALUES (102, 'MUSER', 'MUSERTEST', GETDATE(), 1, 'MUSER123'); --Has Permission

INSERT INTO Comments(commentID, content, date, userID, postID)
	VALUES (102, 'MUSERTEST', GETDATE(), 1, 101); --Has Permission

INSERT INTO Users(userID, username, email, password, firstName, lastName)
	VALUES ('101', 'MUSER', 'MUSER@email.com', 'password', 'M', 'USER'); -- Permission denied.

DELETE FROM Comments WHERE commentID = 101;
DELETE FROM Comments WHERE commentID = 102;
DELETE FROM Posts WHERE postID = 101;
DELETE FROM Posts WHERE postID = 102;
DELETE FROM Basses WHERE serialNumber = 'RUSER123';
DELETE FROM Basses WHERE serialNumber = 'MUSER123'; -- Has Permission for all deletes, except users.

-- Go back to admin role.
REVERT;
Select user;

-- Gets row count of all tables, used to verify that data is successfully migrated to PostgreSQL. Used Open Source scripts to transfer data -> https://github.com/yogimehla/SQLtoPostgresMigrationScript
SELECT * FROM Basses;
SELECT * FROM Users;
SELECT * FROM Posts;
SELECT * FROM Comments;

