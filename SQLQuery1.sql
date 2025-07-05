-- ================================================================
-- PHARMACY MANAGEMENT SYSTEM - FULL DATABASE SCHEMA
-- ================================================================

-- Create Database if not exists
IF DB_ID('PharmacyManagementSystem2') IS NULL
BEGIN
    CREATE DATABASE PharmacyManagementSystem2;
END;
GO

USE PharmacyManagementSystem2;
GO

-- ===========================
-- ROLE AND USER AUTHENTICATION TABLES
-- ===========================

CREATE TABLE Role (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) UNIQUE NOT NULL,
    Description NVARCHAR(200),
    Created_Date DATETIME2 DEFAULT GETDATE()
);
GO

CREATE TABLE [User] (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) UNIQUE NOT NULL,
    PasswordHash VARBINARY(MAX) NOT NULL,
    PasswordSalt VARBINARY(64) NULL,
    RoleID INT NOT NULL,
    FullName NVARCHAR(100),
    Email NVARCHAR(100),
    IsActive BIT DEFAULT 1,
    LastLogin DATETIME2,
    Created_Date DATETIME2 DEFAULT GETDATE(),
    Modified_Date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_User_Role FOREIGN KEY (RoleID) REFERENCES Role(RoleID)
);
GO

-- ===========================
-- PATIENT TABLE
-- ===========================

CREATE TABLE Patient (
    Patient_ID NVARCHAR(10) PRIMARY KEY,
    First_Name NVARCHAR(50) NOT NULL,
    Last_Name NVARCHAR(50) NOT NULL,
    Date_of_Birth DATE NOT NULL,
    Gender CHAR(1) NOT NULL CHECK (Gender IN ('M', 'F', 'O')),
    Email NVARCHAR(100) UNIQUE NOT NULL CHECK (Email LIKE '%_@_%._%'),
    Is_Active BIT DEFAULT 1,
    Created_Date DATETIME2 DEFAULT GETDATE(),
    Modified_Date DATETIME2 DEFAULT GETDATE()
);
GO

-- ===========================
-- MEDICATION TABLE
-- ===========================

CREATE TABLE Medication (
    Medication_ID NVARCHAR(10) PRIMARY KEY,
    Generic_Name NVARCHAR(100) NOT NULL,
    Brand_Name NVARCHAR(100) NOT NULL,
    Is_Active BIT DEFAULT 1,
    Created_Date DATETIME2 DEFAULT GETDATE(),
    Modified_Date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_Med_GenericBrand UNIQUE(Generic_Name, Brand_Name)
);
GO

-- ===========================
-- PRESCRIPTION TABLE
-- ===========================

CREATE TABLE Prescription (
    Prescription_ID NVARCHAR(10) PRIMARY KEY,
    Patient_ID NVARCHAR(10) NOT NULL,
    Medication_ID NVARCHAR(10) NOT NULL,
    Prescription_Date DATE NOT NULL,
    Dosage NVARCHAR(100) NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Days_Supply INT NOT NULL CHECK (Days_Supply > 0),
    Refills_Authorized INT DEFAULT 0 CHECK (Refills_Authorized >= 0),
    Refills_Remaining INT DEFAULT 0 CHECK (Refills_Remaining >= 0),
    Instructions NVARCHAR(500) NULL,
    Status NVARCHAR(20) DEFAULT 'Active' CHECK (Status IN ('Active', 'Completed', 'Cancelled')),
    Created_Date DATETIME2 DEFAULT GETDATE(),
    Modified_Date DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID),
    FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID)
);
GO

-- ===========================
-- MEDICATION INVENTORY TABLE
-- ===========================

CREATE TABLE Medication_Inventory (
    Medication_ID NVARCHAR(10) NOT NULL,
    Quantity INT NOT NULL CHECK(Quantity >= 0),
    Unit_Price DECIMAL(10,2) NOT NULL CHECK(Unit_Price >= 0),
    Modified_Date DATETIME2 DEFAULT SYSDATETIME(),
    PRIMARY KEY (Medication_ID),
    FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID)
);
GO

-- ===========================
-- PATIENT HISTORY TABLE
-- ===========================

CREATE TABLE Patient_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Patient_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_First_Name NVARCHAR(50),
    Old_Last_Name NVARCHAR(50),
    Old_Date_of_Birth DATE,
    Old_Gender CHAR(1),
    Old_Email NVARCHAR(100),
    New_First_Name NVARCHAR(50),
    New_Last_Name NVARCHAR(50),
    New_Date_of_Birth DATE,
    New_Gender CHAR(1),
    New_Email NVARCHAR(100)
);
GO

-- ===========================
-- MEDICATION HISTORY TABLE
-- ===========================

CREATE TABLE Medication_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Medication_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL,
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_Generic_Name NVARCHAR(100),
    Old_Brand_Name NVARCHAR(100),
    New_Generic_Name NVARCHAR(100),
    New_Brand_Name NVARCHAR(100)
);
GO

-- ===========================
-- PRESCRIPTION HISTORY TABLE
-- ===========================

CREATE TABLE Prescription_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Prescription_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL,
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_Patient_ID NVARCHAR(10),
    Old_Medication_ID NVARCHAR(10),
    Old_Prescription_Date DATE,
    Old_Dosage NVARCHAR(100),
    Old_Quantity INT,
    Old_Days_Supply INT,
    Old_Refills_Authorized INT,
    Old_Refills_Remaining INT,
    Old_Status NVARCHAR(20),
    Old_Instructions NVARCHAR(500),
    New_Patient_ID NVARCHAR(10),
    New_Medication_ID NVARCHAR(10),
    New_Prescription_Date DATE,
    New_Dosage NVARCHAR(100),
    New_Quantity INT,
    New_Days_Supply INT,
    New_Refills_Authorized INT,
    New_Refills_Remaining INT,
    New_Status NVARCHAR(20),
    New_Instructions NVARCHAR(500)
);
GO

-- ===========================
-- SALE HEADER TABLE
-- ===========================

CREATE TABLE Sale_Header (
    SaleID INT IDENTITY(1,1) PRIMARY KEY,
    Patient_ID NVARCHAR(10) NULL,
    Cashier NVARCHAR(100),
    Total DECIMAL(10,2),
    SaleDate DATETIME2 DEFAULT SYSDATETIME()
);
GO

-- ===========================
-- SALE ITEM TABLE
-- ===========================

CREATE TABLE Sale_Item (
    SaleItemID INT IDENTITY(1,1) PRIMARY KEY,
    SaleID INT CONSTRAINT FK_SaleItem_Header
            REFERENCES Sale_Header(SaleID) ON DELETE CASCADE,
    Medication_ID NVARCHAR(10),
    Qty INT,
    UnitPrice DECIMAL(10,2)
);
GO

-- ===========================
-- DOCTOR TABLE
-- ===========================

CREATE TABLE Doctor (
    Doctor_ID NVARCHAR(10) PRIMARY KEY,
    Full_Name NVARCHAR(100),
    Specialization NVARCHAR(100),
    Room_No NVARCHAR(10),
    Email NVARCHAR(100),
    Phone NVARCHAR(15),
    Is_Active BIT DEFAULT 1
);
GO




-- ===========================
-- User_actions TABLE
-- ===========================

CREATE TABLE User_Actions (
    Action_ID INT IDENTITY(1,1) PRIMARY KEY,
    [User] VARCHAR(50),
    Action VARCHAR(50),
    Table_Name VARCHAR(50),
    Record_ID INT,
    Action_Date DATETIME
);
ALTER TABLE User_Actions
ALTER COLUMN Record_ID VARCHAR(50);



--test cases 
select * from User_Actions

INSERT INTO Patient (Patient_ID, First_Name, Last_Name, Date_of_Birth, Gender, Email)
VALUES ('P007', 'Mary', 'Jon', '1995-07-01', 'F', 'mary.jane@example.com');

INSERT INTO Patient (Patient_ID, First_Name, Last_Name, Date_of_Birth, Gender, Email)
VALUES ('P008', 'Alice', 'Smith', '1995-06-01', 'F', 'alice.smith@example.com');


INSERT INTO Patient (Patient_ID, First_Name, Last_Name, Date_of_Birth, Gender, Email)
VALUES ('P009', 'scarlette', 'Smith', '1995-06-01', 'F', 'scar.smith@example.com');


EXEC sp_help 'User_Actions'; 



-- ===========================
-- Stock_Alerts Table
-- ===========================

CREATE TABLE Stock_Alerts (
    Alert_ID INT IDENTITY(1,1) PRIMARY KEY,
    Medication_ID VARCHAR(50),
    Alert_Type VARCHAR(50),
    Alert_Date DATETIME
);

--test cases
 select * from Stock_Alerts
UPDATE Medication_Inventory
SET Quantity = 5
WHERE Medication_ID = 'M001';



select * from Medication_Inventory
select * from Medication



-- AUDIT TABLES
-- ===========================

CREATE TABLE Patient_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Patient_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_First_Name NVARCHAR(50),
    Old_Last_Name NVARCHAR(50),
    Old_Date_of_Birth DATE,
    Old_Gender CHAR(1),
    Old_Email NVARCHAR(100),
    New_First_Name NVARCHAR(50),
    New_Last_Name NVARCHAR(50),
    New_Date_of_Birth DATE,
    New_Gender CHAR(1),
    New_Email NVARCHAR(100)
);
GO

CREATE TABLE Medication_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Medication_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL,
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_Generic_Name NVARCHAR(100),
    Old_Brand_Name NVARCHAR(100),
    New_Generic_Name NVARCHAR(100),
    New_Brand_Name NVARCHAR(100)
);
GO

CREATE TABLE Prescription_History (
    History_ID INT IDENTITY(1,1) PRIMARY KEY,
    Prescription_ID NVARCHAR(10) NOT NULL,
    Operation_Type NVARCHAR(10) NOT NULL,
    Operation_Date DATETIME2 DEFAULT GETDATE(),
    Operation_User NVARCHAR(100) DEFAULT SYSTEM_USER,
    Old_Patient_ID NVARCHAR(10),
    Old_Medication_ID NVARCHAR(10),
    Old_Prescription_Date DATE,
    Old_Dosage NVARCHAR(100),
    Old_Quantity INT,
    Old_Days_Supply INT,
    Old_Refills_Authorized INT,
    Old_Refills_Remaining INT,
    Old_Status NVARCHAR(20),
    Old_Instructions NVARCHAR(500),
    New_Patient_ID NVARCHAR(10),
    New_Medication_ID NVARCHAR(10),
    New_Prescription_Date DATE,
    New_Dosage NVARCHAR(100),
    New_Quantity INT,
    New_Days_Supply INT,
    New_Refills_Authorized INT,
    New_Refills_Remaining INT,
    New_Status NVARCHAR(20),
    New_Instructions NVARCHAR(500)
);
GO



-- =============================================
-- Stored Procedures for Database Operations
-- =============================================

-- =============================================
-- Stored Procedures for Database Operations
-- =============================================

-- 1. Update Patient Stored Procedure
CREATE OR ALTER PROCEDURE SP_UpdatePatient
    @PatientID NVARCHAR(10),
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @DateOfBirth DATE,
    @Gender CHAR(1),
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Patient 
    SET First_Name = @FirstName,
        Last_Name = @LastName,
        Date_of_Birth = @DateOfBirth,
        Gender = @Gender,
        Email = @Email,
        Modified_Date = SYSDATETIME()
    WHERE Patient_ID = @PatientID AND Is_Active = 1;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- 2. Get Patient by ID Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetPatientByID
    @PatientID NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT Patient_ID,
           First_Name,
           Last_Name,
           CONVERT(varchar(10), Date_of_Birth, 23) AS DOB,
           Gender,
           Email
    FROM Patient 
    WHERE Patient_ID = @PatientID AND Is_Active = 1;
END
GO

-- 3. Get All Specializations Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetSpecializations
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT DISTINCT Specialization 
    FROM Doctor 
    WHERE Is_Active = 1
    ORDER BY Specialization;
END
GO

-- 4. Get Doctors by Specialization Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetDoctorsBySpecialization
    @Specialization NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT Doctor_ID,
           Full_Name,
           Room_No
    FROM Doctor
    WHERE Is_Active = 1 AND Specialization = @Specialization
    ORDER BY Full_Name;
END
GO


-- 5. Add New Prescription Stored Procedure
CREATE OR ALTER PROCEDURE SP_AddNewPrescription
    @PrescriptionID NVARCHAR(10),
    @PatientID NVARCHAR(10),
    @MedicationID NVARCHAR(10),
    @PrescriptionDate DATE,
    @Dosage NVARCHAR(50),
    @Quantity INT,
    @DaysSupply INT,
    @RefillsAuthorized INT,
    @Instructions NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO Prescription (
        Prescription_ID,
        Patient_ID,
        Medication_ID,
        Prescription_Date,
        Dosage,
        Quantity,
        Days_Supply,
        Refills_Authorized,
        Refills_Remaining,
        Instructions,
        Status,
        Created_Date
    )
    VALUES (
        @PrescriptionID,
        @PatientID,
        @MedicationID,
        @PrescriptionDate,
        @Dosage,
        @Quantity,
        @DaysSupply,
        @RefillsAuthorized,
        @RefillsAuthorized,
        @Instructions,
        'Active',
        SYSDATETIME()
    );
END
GO

-- 6. Get Prescriptions by Patient ID Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetPrescriptionsByPatientID
    @PatientID NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT p.Prescription_ID,
           p.Medication_ID,
           m.Generic_Name + ' (' + m.Brand_Name + ')' AS MedicationName,
           p.Dosage,
           p.Quantity,
           p.Refills_Remaining
    FROM Prescription p
    JOIN Medication m ON m.Medication_ID = p.Medication_ID
    WHERE p.Patient_ID = @PatientID AND p.Status = 'Active';
END
GO

-- 7. Get Inventory by Medication ID Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetInventoryByMedicationID
    @MedicationID NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT i.Medication_ID,
           m.Generic_Name,
           m.Brand_Name,
           i.Quantity,
           i.Unit_Price
    FROM Medication_Inventory i
    JOIN Medication m ON m.Medication_ID = i.Medication_ID
    WHERE i.Medication_ID = @MedicationID;
END
GO

-- 8. Adjust Inventory Stored Procedure
CREATE OR ALTER PROCEDURE SP_AdjustInventory
    @MedicationID NVARCHAR(10),
    @QuantityChange INT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Medication_Inventory 
    SET Quantity = Quantity + @QuantityChange
    WHERE Medication_ID = @MedicationID;
    
    SELECT @@ROWCOUNT AS RowsAffected;
END
GO

-- 9. Get Inventory List Stored Procedure
CREATE OR ALTER PROCEDURE SP_GetInventoryList
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT i.Medication_ID,
           m.Generic_Name,
           m.Brand_Name,
           i.Quantity,
           i.Unit_Price
    FROM Medication_Inventory i
    JOIN Medication m ON m.Medication_ID = i.Medication_ID
    WHERE (m.Generic_Name LIKE @SearchTerm OR m.Brand_Name LIKE @SearchTerm)
    ORDER BY m.Generic_Name;
END
GO

-- 10. Upsert Medication Stored Procedure
CREATE OR ALTER PROCEDURE SP_UpsertMedication
    @MedicationID NVARCHAR(10),
    @GenericName NVARCHAR(100),
    @BrandName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE Medication AS tgt
    USING (SELECT @MedicationID AS mid, @GenericName AS gen, @BrandName AS br) AS src
      ON tgt.Medication_ID = src.mid
    WHEN MATCHED THEN
      UPDATE SET Generic_Name = src.gen,
                 Brand_Name = src.br
    WHEN NOT MATCHED THEN
      INSERT (Medication_ID, Generic_Name, Brand_Name, Is_Active)
      VALUES (src.mid, src.gen, src.br, 1);
END
GO

-- 11. Upsert Inventory Stored Procedure
CREATE OR ALTER PROCEDURE SP_UpsertInventory
    @MedicationID NVARCHAR(10),
    @Quantity INT,
    @UnitPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE Medication_Inventory AS tgt
    USING (SELECT @MedicationID AS mid, @Quantity AS qty, @UnitPrice AS prc) AS src
      ON tgt.Medication_ID = src.mid
    WHEN MATCHED THEN
      UPDATE SET Quantity = src.qty,
                 Unit_Price = src.prc
    WHEN NOT MATCHED THEN
      INSERT (Medication_ID, Quantity, Unit_Price)
      VALUES (src.mid, src.qty, src.prc);
END
GO

-- 12. Save Sale Stored Procedure
CREATE OR ALTER PROCEDURE SP_SaveSale
    @PatientID NVARCHAR(10),
    @Cashier NVARCHAR(50),
    @Total DECIMAL(10,2),
    @SaleItems NVARCHAR(MAX) -- JSON format: [{"mid":"M001","qty":2,"price":15.50}]
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    
    DECLARE @SaleID INT;
    
    -- Insert sale header
    INSERT INTO Sale_Header(Patient_ID, Cashier, Total)
    VALUES(@PatientID, @Cashier, @Total);
    
    SET @SaleID = SCOPE_IDENTITY();
    
    -- Parse JSON and insert sale items
    INSERT INTO Sale_Item(SaleID, Medication_ID, Qty, UnitPrice)
    SELECT @SaleID,
           JSON_VALUE(value, '$.mid'),
           CAST(JSON_VALUE(value, '$.qty') AS INT),
           CAST(JSON_VALUE(value, '$.price') AS DECIMAL(10,2))
    FROM OPENJSON(@SaleItems);
    
    -- Update inventory
    UPDATE Medication_Inventory
    SET Quantity = Quantity - si.Qty
    FROM Medication_Inventory mi
    INNER JOIN (
        SELECT JSON_VALUE(value, '$.mid') AS MedicationID,
               CAST(JSON_VALUE(value, '$.qty') AS INT) AS Qty
        FROM OPENJSON(@SaleItems)
    ) si ON mi.Medication_ID = si.MedicationID;
    
    COMMIT TRANSACTION;
    
    SELECT @SaleID AS SaleID;
END
GO

-- 13. SP_GenerateNextPatientID
-- . using
CREATE OR ALTER PROCEDURE SP_GenerateNextPatientID
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LastID NVARCHAR(10);
    SELECT TOP 1 @LastID = Patient_ID FROM Patient ORDER BY Patient_ID DESC;
    IF @LastID IS NULL
        SET @LastID = 'P000';
    DECLARE @Num INT = CAST(SUBSTRING(@LastID, 2, LEN(@LastID)) AS INT) + 1;
    SELECT 'P' + RIGHT('000' + CAST(@Num AS VARCHAR(3)), 3) AS NextPatientID;
END;
GO




-- 14. SP_GenerateNextMedicationID
--using
CREATE OR ALTER PROCEDURE SP_GenerateNextMedicationID
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LastID NVARCHAR(10);
    SELECT TOP 1 @LastID = Medication_ID FROM Medication ORDER BY Medication_ID DESC;
    IF @LastID IS NULL
        SET @LastID = 'M000';
    DECLARE @Num INT = CAST(SUBSTRING(@LastID, 2, LEN(@LastID)) AS INT) + 1;
    SELECT 'M' + RIGHT('000' + CAST(@Num AS VARCHAR(3)), 3) AS NextMedicationID;
END;
GO

-- 15. SP_GenerateNextPrescriptionID
--using
CREATE OR ALTER PROCEDURE SP_GenerateNextPrescriptionID
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LastID NVARCHAR(10);
    SELECT TOP 1 @LastID = Prescription_ID FROM Prescription ORDER BY Prescription_ID DESC;
    IF @LastID IS NULL
        SET @LastID = 'PR000';
    DECLARE @Num INT = CAST(SUBSTRING(@LastID, 3, LEN(@LastID)) AS INT) + 1;
    SELECT 'PR' + RIGHT('000' + CAST(@Num AS VARCHAR(3)), 3) AS NextPrescriptionID;
END;
GO

-- 16. SP_LoginUser
--using
CREATE OR ALTER PROCEDURE SP_LoginUser
    @Username NVARCHAR(50),
    @PasswordHash VARBINARY(MAX)
AS
BEGIN
    SELECT r.RoleName, u.FullName
    FROM [User] u
    JOIN Role r ON r.RoleID = u.RoleID
    WHERE u.Username = @Username
    AND u.PasswordHash = @PasswordHash
    AND u.IsActive = 1;
END;
GO


-- 17. SP_SearchMedications
--using
CREATE OR ALTER PROCEDURE SP_SearchMedications
    @SearchTerm NVARCHAR(100)
AS
BEGIN
    SELECT m.Generic_Name, m.Brand_Name, m.Medication_ID,
           ISNULL(i.Quantity, 0) AS Stock
    FROM Medication m
    LEFT JOIN Medication_Inventory i ON i.Medication_ID = m.Medication_ID
    WHERE m.Is_Active = 1 AND (m.Generic_Name LIKE '%' + @SearchTerm + '%'
                             OR m.Brand_Name LIKE '%' + @SearchTerm + '%')
    ORDER BY m.Generic_Name, m.Brand_Name;
END;
GO

-- 18. SP_AddNewPatient
--using
CREATE OR ALTER PROCEDURE SP_AddNewPatient
    @First NVARCHAR(50), 
    @Last NVARCHAR(50), 
    @DOB DATE, 
    @Gender CHAR(1), 
    @Email NVARCHAR(100)
AS
BEGIN
    DECLARE @ID NVARCHAR(10);

    -- Capture the generated Patient ID by inserting the output of SP_GenerateNextPatientID into a table variable
    DECLARE @Result TABLE (NextPatientID NVARCHAR(10));
    INSERT INTO @Result
    EXEC SP_GenerateNextPatientID;

    -- Retrieve the generated Patient ID
    SELECT @ID = NextPatientID FROM @Result;

    -- Insert the new patient with the generated ID
    INSERT INTO Patient (Patient_ID, First_Name, Last_Name, Date_of_Birth, Gender, Email, Created_Date, Is_Active)
    VALUES (@ID, @First, @Last, @DOB, @Gender, @Email, SYSDATETIME(), 1);
END;
GO

-- ===========================
-- triggers
-- ===========================


CREATE TRIGGER trg_Inv_NoNegative
ON dbo.Medication_Inventory
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE Quantity < 0)
    BEGIN
        RAISERROR ('Inventory quantity cannot be negative', 16, 1);
        ROLLBACK;
    END
END;
GO

CREATE OR ALTER TRIGGER trg_AfterSaleItem_Insert
ON dbo.Sale_Item
AFTER INSERT
AS
BEGIN
    UPDATE inv
    SET inv.Quantity = inv.Quantity - i.Qty
    FROM dbo.Medication_Inventory inv
    JOIN inserted i ON inv.Medication_ID = i.Medication_ID;
END;
GO



CREATE TRIGGER trg_log_user_action
ON Patient
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @user VARCHAR(50), @action VARCHAR(50), @patient_id VARCHAR(50);

 
    SET @user = SUSER_NAME();  

    SET @action = CASE 
                     WHEN EXISTS (SELECT * FROM inserted) THEN 'Created' 
                     ELSE 'Updated'
                 END;

    -- Convert Patient_ID (which is INT) to VARCHAR and store it in @patient_id
    SELECT @patient_id = CAST(Patient_ID AS VARCHAR(50)) FROM inserted;

    -- Log the action in the User_Actions table
    INSERT INTO User_Actions ([User], Action, Table_Name, Record_ID, Action_Date)
    VALUES (@user, @action, 'Patient', @patient_id, GETDATE());
END




CREATE TRIGGER trg_log_inventory_changes
ON Medication_Inventory
AFTER UPDATE
AS
BEGIN
    DECLARE @med_id VARCHAR(50), @old_qty INT, @new_qty INT, @change INT, @date DATETIME;

    -- Get the medication ID and quantity changes
    SELECT @med_id = i.Medication_ID, 
           @old_qty = d.Quantity, 
           @new_qty = i.Quantity, 
           @change = i.Quantity - d.Quantity,
           @date = GETDATE()
    FROM inserted i
    INNER JOIN deleted d ON i.Medication_ID = d.Medication_ID;

    -- Insert a record into the Medication_Inventory_Log table
    INSERT INTO Medication_Inventory_Log (Medication_ID, Old_Quantity, New_Quantity, Quantity_Change, Change_Date)
    VALUES (@med_id, @old_qty, @new_qty, @change, @date);
END;





CREATE TRIGGER trg_low_stock_alert
ON Medication_Inventory
AFTER UPDATE
AS
BEGIN
    DECLARE @med_id VARCHAR(50), @new_qty INT;

    -- Capture the new quantity
    SELECT @med_id = Medication_ID, @new_qty = inserted.Quantity
    FROM inserted;

    -- If quantity is below the threshold (e.g., 10)
    IF @new_qty < 10
    BEGIN
        PRINT 'ALERT: Low stock for Medication ID ' + @med_id;
        -- Here you can also insert into an Alerts table for further handling
        INSERT INTO Stock_Alerts (Medication_ID, Alert_Type, Alert_Date)
        VALUES (@med_id, 'Low Stock', GETDATE());
    END
END

SELECT * FROM sys.triggers;



-- ===========================
-- VIEWS
-- ===========================

CREATE OR ALTER VIEW vw_InventorySummary
WITH SCHEMABINDING
AS
SELECT 
    m.Medication_ID,
    m.Generic_Name,
    m.Brand_Name,
    i.Quantity,
    i.Unit_Price,
    (i.Quantity * i.Unit_Price) AS TotalValue
FROM dbo.Medication m
JOIN dbo.Medication_Inventory i ON m.Medication_ID = i.Medication_ID
WHERE m.Is_Active = 1;
GO

-- Create the index on the view
CREATE UNIQUE CLUSTERED INDEX IX_InventorySummary_MedID
ON vw_InventorySummary(Medication_ID);
GO



--working
CREATE OR ALTER VIEW vw_VisitSlip AS
SELECT 
    p.Patient_ID,
    p.First_Name + ' ' + p.Last_Name AS PatientName,
    d.Specialization,
    d.Full_Name AS DoctorName,
    d.Room_No,
    GETDATE() AS VisitDate
FROM Patient p
CROSS JOIN Doctor d
WHERE p.Is_Active = 1;


-- ===========================
-- INDEXES
-- ===========================

CREATE NONCLUSTERED INDEX IX_User_Username ON [User](Username);
CREATE NONCLUSTERED INDEX IX_User_Role ON [User](RoleID);
CREATE NONCLUSTERED INDEX IX_User_Active ON [User](IsActive);

CREATE NONCLUSTERED INDEX IX_Patient_Email ON Patient(Email);
CREATE NONCLUSTERED INDEX IX_Medication_Generic ON Medication(Generic_Name);
CREATE NONCLUSTERED INDEX IX_Medication_Brand ON Medication(Brand_Name);
CREATE NONCLUSTERED INDEX IX_Prescription_Patient ON Prescription(Patient_ID);
CREATE NONCLUSTERED INDEX IX_Prescription_Medication ON Prescription(Medication_ID);
CREATE NONCLUSTERED INDEX IX_Prescription_Status ON Prescription(Status);
GO





-- ===========================
-- AUDIT TRIGGERS
-- ===========================

-- Patient Audit Trigger
CREATE OR ALTER TRIGGER TR_Patient_Audit
ON Patient
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @User SYSNAME = SYSTEM_USER;

    -- INSERT
    INSERT INTO Patient_History (Patient_ID, Operation_Type, Operation_User, 
        New_First_Name, New_Last_Name, New_Date_of_Birth, New_Gender, New_Email)
    SELECT i.Patient_ID, 'INSERT', @User, i.First_Name, i.Last_Name, i.Date_of_Birth, i.Gender, i.Email
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.Patient_ID = i.Patient_ID);

    -- UPDATE
    INSERT INTO Patient_History (Patient_ID, Operation_Type, Operation_User,
        Old_First_Name, Old_Last_Name, Old_Date_of_Birth, Old_Gender, Old_Email,
        New_First_Name, New_Last_Name, New_Date_of_Birth, New_Gender, New_Email)
    SELECT i.Patient_ID, 'UPDATE', @User,
        d.First_Name, d.Last_Name, d.Date_of_Birth, d.Gender, d.Email,
        i.First_Name, i.Last_Name, i.Date_of_Birth, i.Gender, i.Email
    FROM inserted i
    JOIN deleted d ON i.Patient_ID = d.Patient_ID;

    -- DELETE
    INSERT INTO Patient_History (Patient_ID, Operation_Type, Operation_User,
        Old_First_Name, Old_Last_Name, Old_Date_of_Birth, Old_Gender, Old_Email)
    SELECT d.Patient_ID, 'DELETE', @User, d.First_Name, d.Last_Name, d.Date_of_Birth, d.Gender, d.Email
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.Patient_ID = d.Patient_ID);
END;
GO

-- Medication Audit Trigger
CREATE OR ALTER TRIGGER TR_Medication_Audit
ON Medication
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @User SYSNAME = SYSTEM_USER;

    -- INSERT
    INSERT INTO Medication_History (Medication_ID, Operation_Type, Operation_User, 
        New_Generic_Name, New_Brand_Name)
    SELECT i.Medication_ID, 'INSERT', @User, i.Generic_Name, i.Brand_Name
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.Medication_ID = i.Medication_ID);

    -- UPDATE
    INSERT INTO Medication_History (Medication_ID, Operation_Type, Operation_User,
        Old_Generic_Name, Old_Brand_Name, New_Generic_Name, New_Brand_Name)
    SELECT i.Medication_ID, 'UPDATE', @User,
        d.Generic_Name, d.Brand_Name, i.Generic_Name, i.Brand_Name
    FROM inserted i
    JOIN deleted d ON i.Medication_ID = d.Medication_ID;

    -- DELETE
    INSERT INTO Medication_History (Medication_ID, Operation_Type, Operation_User,
        Old_Generic_Name, Old_Brand_Name)
    SELECT d.Medication_ID, 'DELETE', @User, d.Generic_Name, d.Brand_Name
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.Medication_ID = d.Medication_ID);
END;
GO

-- Prescription Audit Trigger
CREATE OR ALTER TRIGGER TR_Prescription_Audit
ON Prescription
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @User SYSNAME = SYSTEM_USER;

    -- INSERT
    INSERT INTO Prescription_History (Prescription_ID, Operation_Type, Operation_User,
        New_Patient_ID, New_Medication_ID, New_Prescription_Date, New_Dosage,
        New_Quantity, New_Days_Supply, New_Refills_Authorized, New_Refills_Remaining,
        New_Status, New_Instructions)
    SELECT i.Prescription_ID, 'INSERT', @User,
        i.Patient_ID, i.Medication_ID, i.Prescription_Date, i.Dosage,
        i.Quantity, i.Days_Supply, i.Refills_Authorized, i.Refills_Remaining,
        i.Status, i.Instructions
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.Prescription_ID = i.Prescription_ID);

    -- UPDATE
    INSERT INTO Prescription_History (Prescription_ID, Operation_Type, Operation_User,
        Old_Patient_ID, Old_Medication_ID, Old_Prescription_Date, Old_Dosage,
        Old_Quantity, Old_Days_Supply, Old_Refills_Authorized, Old_Refills_Remaining,
        Old_Status, Old_Instructions,
        New_Patient_ID, New_Medication_ID, New_Prescription_Date, New_Dosage,
        New_Quantity, New_Days_Supply, New_Refills_Authorized, New_Refills_Remaining,
        New_Status, New_Instructions)
    SELECT i.Prescription_ID, 'UPDATE', @User,
        d.Patient_ID, d.Medication_ID, d.Prescription_Date, d.Dosage,
        d.Quantity, d.Days_Supply, d.Refills_Authorized, d.Refills_Remaining,
        d.Status, d.Instructions,
        i.Patient_ID, i.Medication_ID, i.Prescription_Date, i.Dosage,
        i.Quantity, i.Days_Supply, i.Refills_Authorized, i.Refills_Remaining,
        i.Status, i.Instructions
    FROM inserted i
    JOIN deleted d ON i.Prescription_ID = d.Prescription_ID;

    -- DELETE
    INSERT INTO Prescription_History (Prescription_ID, Operation_Type, Operation_User,
        Old_Patient_ID, Old_Medication_ID, Old_Prescription_Date, Old_Dosage,
        Old_Quantity, Old_Days_Supply, Old_Refills_Authorized, Old_Refills_Remaining,
        Old_Status, Old_Instructions)
    SELECT d.Prescription_ID, 'DELETE', @User,
        d.Patient_ID, d.Medication_ID, d.Prescription_Date, d.Dosage,
        d.Quantity, d.Days_Supply, d.Refills_Authorized, d.Refills_Remaining,
        d.Status, d.Instructions
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.Prescription_ID = d.Prescription_ID);
END;
GO

-- ===========================
-- FOREIGN KEY CONSTRAINTS WITH CASCADE OPTIONS
-- ===========================

ALTER TABLE Prescription
DROP CONSTRAINT IF EXISTS FK_Prescription_Patient;
ALTER TABLE Prescription
ADD CONSTRAINT FK_Prescription_Patient FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO

ALTER TABLE Prescription
DROP CONSTRAINT IF EXISTS FK_Prescription_Medication;
ALTER TABLE Prescription
ADD CONSTRAINT FK_Prescription_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for Prescription.Patient_ID referencing Patient.Patient_ID
ALTER TABLE Prescription
DROP CONSTRAINT IF EXISTS FK_Prescription_Patient;
ALTER TABLE Prescription
ADD CONSTRAINT FK_Prescription_Patient FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO

-- Foreign Key for Prescription.Medication_ID referencing Medication.Medication_ID
ALTER TABLE Prescription
DROP CONSTRAINT IF EXISTS FK_Prescription_Medication;
ALTER TABLE Prescription
ADD CONSTRAINT FK_Prescription_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for Medication_Inventory.Medication_ID referencing Medication.Medication_ID
ALTER TABLE Medication_Inventory
DROP CONSTRAINT IF EXISTS FK_Medication_Inventory_Medication;
ALTER TABLE Medication_Inventory
ADD CONSTRAINT FK_Medication_Inventory_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for Sale_Item.Medication_ID referencing Medication.Medication_ID
ALTER TABLE Sale_Item
DROP CONSTRAINT IF EXISTS FK_SaleItem_Medication;
ALTER TABLE Sale_Item
ADD CONSTRAINT FK_SaleItem_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO

-- Foreign Key for Sale_Item.SaleID referencing Sale_Header.SaleID
ALTER TABLE Sale_Item
DROP CONSTRAINT IF EXISTS FK_SaleItem_Header;
ALTER TABLE Sale_Item
ADD CONSTRAINT FK_SaleItem_Header FOREIGN KEY (SaleID) REFERENCES Sale_Header(SaleID) ON DELETE CASCADE ON UPDATE CASCADE;
GO



-- Foreign Key for Prescription_History.Prescription_ID referencing Prescription.Prescription_ID
ALTER TABLE Prescription_History
DROP CONSTRAINT IF EXISTS FK_Prescription_History_Prescription;
ALTER TABLE Prescription_History
ADD CONSTRAINT FK_Prescription_History_Prescription FOREIGN KEY (Prescription_ID) REFERENCES Prescription(Prescription_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for Patient_History.Patient_ID referencing Patient.Patient_ID
ALTER TABLE Patient_History
DROP CONSTRAINT IF EXISTS FK_Patient_History_Patient;
ALTER TABLE Patient_History
ADD CONSTRAINT FK_Patient_History_Patient FOREIGN KEY (Patient_ID) REFERENCES Patient(Patient_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for Medication_History.Medication_ID referencing Medication.Medication_ID
ALTER TABLE Medication_History
DROP CONSTRAINT IF EXISTS FK_Medication_History_Medication;
ALTER TABLE Medication_History
ADD CONSTRAINT FK_Medication_History_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


--NOT WORKING{
-- Foreign Key for Stock_Alerts.Medication_ID referencing Medication.Medication_ID
ALTER TABLE Stock_Alerts
DROP CONSTRAINT IF EXISTS FK_Stock_Alerts_Medication;
ALTER TABLE Stock_Alerts
ADD CONSTRAINT FK_Stock_Alerts_Medication FOREIGN KEY (Medication_ID) REFERENCES Medication(Medication_ID) ON DELETE NO ACTION ON UPDATE CASCADE;
GO


-- Foreign Key for User_Actions.User referencing User.Username
ALTER TABLE User_Actions
DROP CONSTRAINT IF EXISTS FK_User_Actions_User;
ALTER TABLE User_Actions
ADD CONSTRAINT FK_User_Actions_User FOREIGN KEY ([User]) REFERENCES [User](Username) ON DELETE NO ACTION ON UPDATE CASCADE;

--}


-- Check and add unique constraint on Generic_Name and Brand_Name
IF NOT EXISTS (SELECT 1
               FROM   sys.key_constraints
               WHERE  name = N'UQ_Med_GenericBrand'
                 AND  parent_object_id = OBJECT_ID(N'dbo.Medication'))
BEGIN
    ALTER TABLE dbo.Medication
          ADD CONSTRAINT UQ_Med_GenericBrand
              UNIQUE (Generic_Name, Brand_Name);
END
GO

-- Check and create unique filtered index for active prescriptions
IF NOT EXISTS ( SELECT 1
                FROM   sys.indexes
                WHERE  name = N'UX_Prescription_Active_PM' )
BEGIN
    CREATE UNIQUE INDEX UX_Prescription_Active_PM
        ON dbo.Prescription (Patient_ID, Medication_ID)
        WHERE Status = 'Active';     
END
GO



MERGE dbo.[User] AS tgt
USING (VALUES
   ('intern1' , (SELECT RoleID FROM dbo.Role WHERE RoleName='Intern')    , 'Intern User' , 'intern@demo.com' , 'intern123' ),
   ('doctor1' , (SELECT RoleID FROM dbo.Role WHERE RoleName='Doctor')    , 'Dr. Demo'    , 'doctor@demo.com' , 'doc123'    ),
   ('pharm1'  , (SELECT RoleID FROM dbo.Role WHERE RoleName='Pharmacist'), 'Pharma Demo' , 'pharm@demo.com'  , 'pharm123'  ),
   ('manager1', (SELECT RoleID FROM dbo.Role WHERE RoleName='Manager')   , 'Inv Manager' , 'inv@demo.com'    , 'inv123'    )
) AS src(Username,RoleID,FullName,Email,PlainPwd)
ON  tgt.Username = src.Username
WHEN MATCHED THEN                         -- update password / role if you change it
   UPDATE SET RoleID = src.RoleID,
              FullName = src.FullName,
              Email = src.Email,
              PasswordHash = HASHBYTES('SHA2_256', src.PlainPwd),
              IsActive = 1,
              Modified_Date = SYSDATETIME()
WHEN NOT MATCHED THEN
   INSERT (Username,RoleID,FullName,Email,PasswordHash)
   VALUES (src.Username,src.RoleID,src.FullName,src.Email,
           HASHBYTES('SHA2_256', src.PlainPwd));
GO

---USER LOGIN AND PASS
PRINT N'✅  Test accounts ready – use the credentials below:';
PRINT N'   • intern1   /  intern123     (Intern / Reception)';
PRINT N'   • doctor1   /  doc123        (Doctor)';
PRINT N'   • pharm1    /  pharm123      (Pharmacist)';
PRINT N'   • manager1  /  inv123        (Inventory Manager)';
GO
--TEST VALUES
INSERT INTO Role (RoleName, Description, Created_Date)
VALUES
    ('Intern', 'Limited access to assigned patients only', '2025-06-09 16:51:36.6300000'),
    ('Pharmacist', 'Access to assigned patients and medication management', '2025-06-09 16:51:36.6300000'),
    ('Manager', 'Broader access including reporting and user management', '2025-06-09 16:51:36.6300000'),
    ('CEO', 'Full system access', '2025-06-09 16:51:36.6300000'),
    ('Other', 'Custom role with specific permissions', '2025-06-09 16:51:36.6300000'),
    ('Doctor', 'Writes prescriptions; sees own patients', '2025-06-09 18:27:35.5933333');

	INSERT INTO Doctor (Doctor_ID, Full_Name, Specialization, Room_No, Email, Phone, Is_Active)
VALUES
    -- Skin doctors
    ('D001', 'Dr. Skin Expert 1', 'Skin', '101', 'skin1@demo.com', '1234567890', 1),
    ('D002', 'Dr. Skin Expert 2', 'Skin', '102', 'skin2@demo.com', '1234567891', 1),
    ('D003', 'Dr. Skin Expert 3', 'Skin', '103', 'skin3@demo.com', '1234567892', 1),
    ('D004', 'Dr. Dermatologist', 'Skin', '104', 'derma@demo.com', '1234567893', 1),
    
    -- General doctors
    ('D005', 'Dr. Generalist 1', 'General', '201', 'gen1@demo.com', '1234567894', 1),
    ('D006', 'Dr. Generalist 2', 'General', '202', 'gen2@demo.com', '1234567895', 1),
    ('D007', 'Dr. Family Care', 'General', '203', 'famcare@demo.com', '1234567896', 1),
    ('D008', 'Dr. General Care 1', 'General', '204', 'gen3@demo.com', '1234567897', 1);
GO

-- Insert patients
INSERT INTO Patient (Patient_ID, First_Name, Last_Name, Date_of_Birth, Gender, Email, Is_Active, Created_Date, Modified_Date)
VALUES
    
    ('P002', 'Jane', 'Smith', '1990-09-25', 'F', 'jane.smith@demo.com', 1, SYSDATETIME(), SYSDATETIME()),
    ('P003', 'Michael', 'Johnson', '1978-11-30', 'M', 'michael.johnson@demo.com', 1, SYSDATETIME(), SYSDATETIME()),
    ('P004', 'Emily', 'Davis', '2000-02-20', 'F', 'emily.davis@demo.com', 1, SYSDATETIME(), SYSDATETIME());
GO

-- Insert medications
INSERT INTO Medication (Medication_ID, Generic_Name, Brand_Name, Is_Active, Created_Date, Modified_Date)
VALUES
    ('M001', 'Aspirin', 'Bayer', 1, SYSDATETIME(), SYSDATETIME()),
    ('M002', 'Paracetamol', 'Tylenol', 1, SYSDATETIME(), SYSDATETIME()),
    ('M003', 'Ibuprofen', 'Advil', 1, SYSDATETIME(), SYSDATETIME()),
    ('M004', 'Amoxicillin', 'Amoxil', 1, SYSDATETIME(), SYSDATETIME());
GO

-- Insert prescriptions
INSERT INTO Prescription (Prescription_ID, Patient_ID, Medication_ID, Prescription_Date, Dosage, Quantity, Days_Supply, Refills_Authorized, Refills_Remaining, Instructions, Status, Created_Date, Modified_Date)
VALUES
    ('PR001', 'P001', 'M001', '2025-06-01', '500mg', 30, 10, 2, 2, 'Take 1 tablet every 4 hours', 'Active', SYSDATETIME(), SYSDATETIME()),
    ('PR002', 'P002', 'M002', '2025-06-02', '250mg', 20, 7, 1, 1, 'Take 1 tablet every 6 hours', 'Active', SYSDATETIME(), SYSDATETIME()),
    ('PR003', 'P003', 'M003', '2025-06-03', '400mg', 15, 5, 0, 0, 'Take 1 tablet twice a day', 'Active', SYSDATETIME(), SYSDATETIME()),
    ('PR004', 'P004', 'M004', '2025-06-04', '500mg', 30, 10, 1, 1, 'Take 1 tablet every 8 hours', 'Active', SYSDATETIME(), SYSDATETIME());
GO

-- Insert medication inventory
INSERT INTO Medication_Inventory (Medication_ID, Quantity, Unit_Price, Modified_Date)
VALUES
    ('M001', 100, 5.50, SYSDATETIME()),
    ('M002', 200, 2.00, SYSDATETIME()),
    ('M003', 150, 7.00, SYSDATETIME()),
    ('M004', 50, 10.00, SYSDATETIME());
GO

select * from Patient



select *  from Medication_History
select * from Medication_Inventory
select * from Prescription_History
select * from 


fgdfdgdgfd