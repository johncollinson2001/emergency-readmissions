/*
 * Create Test Data:
 *
 * This script seeds the schema with a number of hospital admissions, the attributes of
 * which are randomly generated with various biases in order to simulate a real world
 * population demographic.
 *
 * The script handles a set number of current patients based on the capacity of the 
 * hospital.
 *
 **************************************************************************************/

-- Flush table
TRUNCATE TABLE dbo.HospitalAdmissions;

-- The number of patients we need to generate
DECLARE @NumberOfPatients INT = 100000;

-- The earliest admission date that will be seen in the data
DECLARE @EarliestAdmissionDate DATE = '20010101';

-- The capacity of the hospital, which limits the number of current inpatients that can be generated
DECLARE @BedCapacity INT = 500, @BedsFilled INT = 0;

-- Stores the admissions during iteration, to avoid querying physical table to ensure no overlapping dates
DECLARE @PatientAdmissions TABLE (AdmissionDate DATE, DischargeDate DATE);

-- Iterate patients
DECLARE @PatientNumber INT = 1;

WHILE @PatientNumber <= @NumberOfPatients
BEGIN
	-- Random between 0 and 100, biased toward older PatientAges
	DECLARE @PatientAge FLOAT = ROUND(POWER(RAND(), 0.5) * 100, 0);
	
	-- A random string in the format of "(DT|BH)([1-5]) ([1-10])"
	DECLARE @PatientPostcodeSector CHAR(6) = SUBSTRING('DTBH', CAST((ROUND(RAND(), 0) * 2) + 1 AS INT), 2) + CAST(CEILING(RAND() * 5) AS CHAR(1)) + ' ' + CAST(CEILING(RAND() * 10) AS CHAR(2));
	
	-- Calculate illness bias based on age and postcode, bias will range from 0-1, 0 being less likely to be ill
	-- ...
	
	-- Postcode bias = ([DT=20|BH=10] * district) / sector, e.g. "DT3 4" = (20 * 3) / 4 = 15, "DT5 1" = (20 * 5) / 1 = 100
	DECLARE @PostcodeIllnessBias FLOAT = 
		(CASE WHEN LEFT(@PatientPostcodeSector, 2) = 'BH' THEN 10.0 ELSE 20.0 END
		* CAST(SUBSTRING(@PatientPostcodeSector, 3, 1) AS FLOAT)) 
		/ CAST(SUBSTRING(@PatientPostcodeSector, 5, 2) AS FLOAT);	
	
	-- Illness bias = ((Age + Postcode bias) / 2) / 100
	DECLARE @IllnessBias FLOAT = ((@PatientAge + @PostcodeIllnessBias) / 2) / 100;

	-- Random number of admissions, by bias
	DECLARE @NumberOfAdmissions INT = POWER(RAND() * 25, @IllnessBias * 1.5);
	
	SET @NumberOfAdmissions = CASE WHEN @NumberOfAdmissions = 0 THEN 1 ELSE @NumberOfAdmissions END;
	
	-- Reset admissions table
	DELETE FROM @PatientAdmissions;

	-- Iterate admissions
	DECLARE @AdmissionNumber INT = 1;
	
	WHILE @AdmissionNumber <= @NumberOfAdmissions
	BEGIN
		-- Random between min admission date the current date
		DECLARE @AdmissionDate DATE = DATEADD(DAY, RAND(CHECKSUM(NEWID())) * (1 + DATEDIFF(DAY, @EarliestAdmissionDate, GETDATE())), @EarliestAdmissionDate);

		-- Random between admission date and 6 months after admission date, or current date if before
		DECLARE @DischargeDate DATE = DATEADD(DAY, RAND(CHECKSUM(NEWID())) * (1 + DATEDIFF(DAY, @AdmissionDate, DATEADD(MONTH, 6, @AdmissionDate))), @AdmissionDate);
		
		-- Identify if discharge is in the future and nullify if there's capacity in the hospital, making
		-- this stay a current inpatient admission. If no capacity, default to the current date.
		IF (@DischargeDate > GETDATE() AND @BedsFilled < @BedCapacity AND NOT EXISTS (SELECT NULL FROM @PatientAdmissions WHERE DischargeDate IS NULL))
		BEGIN
			SET @DischargeDate = NULL;
			SET @BedsFilled = @BedsFilled + 1;
		END
		ELSE IF (@DischargeDate > GETDATE())
			SET @DischargeDate = CAST(GETDATE() AS DATE);

		-- Ensure no overlapping admissions
		IF EXISTS (
			SELECT NULL 
			FROM @PatientAdmissions 
			WHERE 
				AdmissionDate BETWEEN @AdmissionDate AND @DischargeDate
				OR DischargeDate BETWEEN @AdmissionDate AND @DischargeDate
		)
			CONTINUE;		
		
		-- Insert admission record
		INSERT INTO dbo.HospitalAdmissions 
			SELECT
				@PatientNumber,												-- PatientId	
				@AdmissionDate,												-- AdmissionDate
				@DischargeDate, 											-- DischargeDate
				@PatientAge,												-- PatientAge
				@PatientPostcodeSector,										-- PatientPostcodeSector	
				CAST(ROUND(POWER(RAND(), @IllnessBias * 2), 0) AS BIT),		-- IsEmergencyAdmission
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT), 	-- IsCongestiveHeartFailure
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsPeripheralVascularDisease
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsDementia
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsChronicPulmonaryDisease
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsOtherLiverDisease
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsOtherMalignantCancer
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsMetastaticCancerWithSolidTumour
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsModerateOrSevereLiverDisease
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsDiabetesWithChronicComplications
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT),		-- IsHemiplegiaOrParaplegia
				CAST(ROUND(POWER(RAND(), @IllnessBias * 8), 0) AS BIT)		-- IsRenalDisease				
		
		-- Log the stay for the overlap check
		INSERT INTO @PatientAdmissions
			SELECT @AdmissionDate, @DischargeDate;

		SET @AdmissionNumber = @AdmissionNumber + 1;
	END
			
	SET @PatientNumber = @PatientNumber + 1;
END