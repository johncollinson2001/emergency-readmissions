-- The primary table for our analysis which stores a record of hospital admissions
DROP TABLE IF EXISTS dbo.HospitalAdmissions;
	
CREATE TABLE dbo.HospitalAdmissions (
	PatientId INT NOT NULL,
	AdmissionDate DATE NOT NULL,
	DischargeDate DATE NULL,
	PatientAge INT NOT NULL,
	PatientPostcodeSector VARCHAR(6) NOT NULL,
	IsEmergencyAdmission BIT NOT NULL,
	IsCongestiveHeartFailure BIT NOT NULL,
	IsPeripheralVascularDisease BIT NOT NULL,
	IsDementia BIT NOT NULL,
	IsChronicPulmonaryDisease BIT NOT NULL,
	IsOtherLiverDisease BIT NOT NULL,
	IsOtherMalignantCancer BIT NOT NULL,
	IsMetastaticCancerWithSolidTumour BIT NOT NULL,
	IsModerateOrSevereLiverDisease BIT NOT NULL,
	IsDiabetesWithChronicComplications BIT NOT NULL,
	IsHemiplegiaOrParaplegia BIT NOT NULL,
	IsRenalDisease BIT NOT NULL,
	PRIMARY KEY (PatientId, AdmissionDate)
);

-- The table which will store the predictions of our machine learning algorithm
DROP TABLE IF EXISTS dbo.PredictedReadmissions;
	
CREATE TABLE dbo.PredictedReadmissions (
	Risk FLOAT NOT NULL,
	PatientId INT NOT NULL,
	AdmissionDate DATE NOT NULL,
	PatientAge INT NOT NULL,
	PatientPostcodeSector VARCHAR(6) NOT NULL,
	IsEmergencyAdmission BIT NOT NULL,
	IsEmergencyAdmissionLast30Days BIT NOT NULL,
	NumberOfEmergencyAdmissionsLast12Months INT NOT NULL,
	IsHistoryOfCongestiveHeartFailure BIT NOT NULL,
	IsHistoryOfPeripheralVascularDisease BIT NOT NULL,
	IsHistoryOfDementia BIT NOT NULL,
	IsHistoryOfChronicPulmonaryDisease BIT NOT NULL,
	IsHistoryOfOtherLiverDisease BIT NOT NULL,
	IsHistoryOfOtherMalignantCancer BIT NOT NULL,
	IsHistoryOfMetastaticCancerWithSolidTumour BIT NOT NULL,
	IsHistoryOfModerateOrSevereLiverDisease BIT NOT NULL,
	IsHistoryOfDiabetesWithChronicComplications BIT NOT NULL,
	IsHistoryOfHemiplegiaOrParaplegia BIT NOT NULL,
	IsHistoryOfRenalDisease BIT NOT NULL,
	PRIMARY KEY (PatientId, AdmissionDate)
);

-- The view where the emergency readmission risk is known, which provides training data for our machine learning algorithm
DROP VIEW IF EXISTS dbo.vw_HospitalAdmissions_History;
GO

CREATE VIEW dbo.vw_HospitalAdmissions_History AS
	SELECT
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcodeSector,
		admissions.IsEmergencyAdmission,
		MAX(CASE WHEN previousAdmissions.IsEmergencyAdmission = 1 AND previousAdmissions.AdmissionDate >= DATEADD(DAY, -30, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsEmergencyAdmissionLast30Days,
		SUM(CASE WHEN previousAdmissions.IsEmergencyAdmission = 1 AND previousAdmissions.AdmissionDate >= DATEADD(MONTH, -12, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS NumberOfEmergencyAdmissionsLast12Months,
		MAX(CASE WHEN previousAdmissions.IsCongestiveHeartFailure = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfCongestiveHeartFailure,
		MAX(CASE WHEN previousAdmissions.IsPeripheralVascularDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfPeripheralVascularDisease,
		MAX(CASE WHEN previousAdmissions.IsDementia = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDementia, 
		MAX(CASE WHEN previousAdmissions.IsChronicPulmonaryDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfChronicPulmonaryDisease,
		MAX(CASE WHEN previousAdmissions.IsOtherLiverDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherLiverDisease,
		MAX(CASE WHEN previousAdmissions.IsOtherMalignantCancer = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherMalignantCancer,
		MAX(CASE WHEN previousAdmissions.IsMetastaticCancerWithSolidTumour = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
		MAX(CASE WHEN previousAdmissions.IsModerateOrSevereLiverDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfModerateOrSevereLiverDisease,
		MAX(CASE WHEN previousAdmissions.IsDiabetesWithChronicComplications = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDiabetesWithChronicComplications,
		MAX(CASE WHEN previousAdmissions.IsHemiplegiaOrParaplegia = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfHemiplegiaOrParaplegia,
		MAX(CASE WHEN previousAdmissions.IsRenalDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfRenalDisease,
		MAX(CASE WHEN futureAdmissions.IsEmergencyAdmission = 1 AND futureAdmissions.AdmissionDate <= DATEADD(DAY, 30, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsEmergencyReadmissionWithin30Days
	FROM 
		dbo.HospitalAdmissions admissions
		LEFT OUTER JOIN dbo.HospitalAdmissions previousAdmissions
			ON previousAdmissions.PatientId = admissions.PatientId
			AND previousAdmissions.AdmissionDate < admissions.AdmissionDate
		LEFT OUTER JOIN dbo.HospitalAdmissions futureAdmissions
			ON futureAdmissions.PatientId = admissions.PatientId
			AND futureAdmissions.AdmissionDate > admissions.AdmissionDate
	WHERE 
		admissions.DischargeDate IS NOT NULL
	GROUP BY 
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcodeSector,
		admissions.IsEmergencyAdmission;
GO

-- The view which we require predictions for
DROP VIEW IF EXISTS dbo.vw_HospitalAdmissions_Current;	
GO

CREATE VIEW dbo.vw_HospitalAdmissions_Current AS
	SELECT
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcodeSector,
		admissions.IsEmergencyAdmission,
		MAX(CASE WHEN previousAdmissions.IsEmergencyAdmission = 1 AND previousAdmissions.AdmissionDate >= DATEADD(DAY, -30, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsEmergencyAdmissionLast30Days,
		SUM(CASE WHEN previousAdmissions.IsEmergencyAdmission = 1 AND previousAdmissions.AdmissionDate >= DATEADD(MONTH, -12, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS NumberOfEmergencyAdmissionsLast12Months,
		MAX(CASE WHEN previousAdmissions.IsCongestiveHeartFailure = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfCongestiveHeartFailure,
		MAX(CASE WHEN previousAdmissions.IsPeripheralVascularDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfPeripheralVascularDisease,
		MAX(CASE WHEN previousAdmissions.IsDementia = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDementia, 
		MAX(CASE WHEN previousAdmissions.IsChronicPulmonaryDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfChronicPulmonaryDisease,
		MAX(CASE WHEN previousAdmissions.IsOtherLiverDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherLiverDisease,
		MAX(CASE WHEN previousAdmissions.IsOtherMalignantCancer = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherMalignantCancer,
		MAX(CASE WHEN previousAdmissions.IsMetastaticCancerWithSolidTumour = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
		MAX(CASE WHEN previousAdmissions.IsModerateOrSevereLiverDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfModerateOrSevereLiverDisease,
		MAX(CASE WHEN previousAdmissions.IsDiabetesWithChronicComplications = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDiabetesWithChronicComplications,
		MAX(CASE WHEN previousAdmissions.IsHemiplegiaOrParaplegia = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfHemiplegiaOrParaplegia,
		MAX(CASE WHEN previousAdmissions.IsRenalDisease = 1 AND previousAdmissions.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfRenalDisease
	FROM 
		dbo.HospitalAdmissions admissions
		LEFT OUTER JOIN dbo.HospitalAdmissions previousAdmissions
			ON previousAdmissions.PatientId = admissions.PatientId
			AND previousAdmissions.AdmissionDate < admissions.AdmissionDate
	WHERE 
		admissions.DischargeDate IS NULL
	GROUP BY 
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcodeSector,
		admissions.IsEmergencyAdmission;
GO

-- The view which pulls a subset of data for training
DROP VIEW IF EXISTS dbo.vw_PredictedReadmissions_TrainingData;	
GO

CREATE VIEW dbo.vw_PredictedReadmissions_TrainingData AS
	SELECT TOP(2500) * 
	FROM dbo.vw_HospitalAdmissions_History
	WHERE 
		IsEmergencyReadmissionWithin30Days = 1 
		AND PatientPostcodeSector IN (SELECT DISTINCT PatientPostcodeSector FROM dbo.vw_HospitalAdmissions_Current)

	UNION ALL 

	SELECT TOP(2500) * 
	FROM dbo.vw_HospitalAdmissions_History 
	WHERE 
		IsEmergencyReadmissionWithin30Days = 0
		AND PatientPostcodeSector IN (SELECT DISTINCT PatientPostcodeSector FROM dbo.vw_HospitalAdmissions_Current)
GO


