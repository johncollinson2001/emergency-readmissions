/*
 * Create Schema:
 *
 * This script creates the database schema containing following objects:
 *
 * HospitalAdmissions (Table): 
 * Contains a historical record of hospital admissions with some basic demographics
 * and a number of flags relating to the patient's condition. If discharge date is null this
 * indicates the patient is currently in hospital.
 *
 * vw_RiskOfReadmission_SubjectData (View):
 * Queries the subject data for which risk of readmission should be calculated.
 *
 * vw_RiskOfReadmission_TrainingData (View):
 * Queries known emergency readmissions which can be used for machine learning training.
 *
 **************************************************************************************/

DROP TABLE IF EXISTS dbo.HospitalAdmissions;
	
CREATE TABLE dbo.HospitalAdmissions (
	PatientId INT NOT NULL,
	AdmissionDate DATE NOT NULL,
	DischargeDate DATE NULL,
	PatientAge INT NOT NULL,
	PatientPostcode VARCHAR(6) NOT NULL,
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
	RiskOfReadmission FLOAT NULL,
	PRIMARY KEY (PatientId, AdmissionDate)
);


DROP VIEW IF EXISTS dbo.vw_RiskOfReadmission_SubjectData;
GO

CREATE VIEW dbo.vw_RiskOfReadmission_SubjectData AS
	SELECT
		a.PatientId,
		a.AdmissionDate,
		a.PatientAge,
		a.PatientPostcode,
		a.IsEmergencyAdmission,
		MAX(CASE WHEN prev.IsEmergencyAdmission = 1 AND prev.AdmissionDate >= DATEADD(DAY, -30, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsEmergencyAdmissionLast30Days,
		SUM(CASE WHEN prev.IsEmergencyAdmission = 1 AND prev.AdmissionDate >= DATEADD(MONTH, -12, a.AdmissionDate) THEN 1 ELSE 0 END) AS NumberOfEmergencyAdmissionsLast12Months,
		MAX(CASE WHEN prev.IsCongestiveHeartFailure = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfCongestiveHeartFailure,
		MAX(CASE WHEN prev.IsPeripheralVascularDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfPeripheralVascularDisease,
		MAX(CASE WHEN prev.IsDementia = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfDementia, 
		MAX(CASE WHEN prev.IsChronicPulmonaryDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfChronicPulmonaryDisease,
		MAX(CASE WHEN prev.IsOtherLiverDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfOtherLiverDisease,
		MAX(CASE WHEN prev.IsOtherMalignantCancer = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfOtherMalignantCancer,
		MAX(CASE WHEN prev.IsMetastaticCancerWithSolidTumour = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
		MAX(CASE WHEN prev.IsModerateOrSevereLiverDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfModerateOrSevereLiverDisease,
		MAX(CASE WHEN prev.IsDiabetesWithChronicComplications = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfDiabetesWithChronicComplications,
		MAX(CASE WHEN prev.IsHemiplegiaOrParaplegia = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfHemiplegiaOrParaplegia,
		MAX(CASE WHEN prev.IsRenalDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfRenalDisease
	FROM 
		dbo.HospitalAdmissions a
		LEFT OUTER JOIN dbo.HospitalAdmissions prev
			ON prev.PatientId = a.PatientId
			AND prev.AdmissionDate < a.AdmissionDate
	WHERE 
		a.DischargeDate IS NULL
	GROUP BY 
		a.PatientId,
		a.AdmissionDate,
		a.PatientAge,
		a.PatientPostcode,
		a.IsEmergencyAdmission;
GO


DROP VIEW IF EXISTS dbo.vw_RiskOfReadmission_TrainingData;	
GO

CREATE VIEW dbo.vw_RiskOfReadmission_TrainingData AS
	WITH history AS (
		SELECT
			a.PatientId,
			a.AdmissionDate,
			a.PatientAge,
			a.PatientPostcode,
			a.IsEmergencyAdmission,
			MAX(CASE WHEN prev.IsEmergencyAdmission = 1 AND prev.AdmissionDate >= DATEADD(DAY, -30, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsEmergencyAdmissionLast30Days,
			SUM(CASE WHEN prev.IsEmergencyAdmission = 1 AND prev.AdmissionDate >= DATEADD(MONTH, -12, a.AdmissionDate) THEN 1 ELSE 0 END) AS NumberOfEmergencyAdmissionsLast12Months,
			MAX(CASE WHEN prev.IsCongestiveHeartFailure = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfCongestiveHeartFailure,
			MAX(CASE WHEN prev.IsPeripheralVascularDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfPeripheralVascularDisease,
			MAX(CASE WHEN prev.IsDementia = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfDementia, 
			MAX(CASE WHEN prev.IsChronicPulmonaryDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfChronicPulmonaryDisease,
			MAX(CASE WHEN prev.IsOtherLiverDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfOtherLiverDisease,
			MAX(CASE WHEN prev.IsOtherMalignantCancer = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfOtherMalignantCancer,
			MAX(CASE WHEN prev.IsMetastaticCancerWithSolidTumour = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
			MAX(CASE WHEN prev.IsModerateOrSevereLiverDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfModerateOrSevereLiverDisease,
			MAX(CASE WHEN prev.IsDiabetesWithChronicComplications = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfDiabetesWithChronicComplications,
			MAX(CASE WHEN prev.IsHemiplegiaOrParaplegia = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfHemiplegiaOrParaplegia,
			MAX(CASE WHEN prev.IsRenalDisease = 1 AND prev.AdmissionDate >= DATEADD(YEAR, -2, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsHistoryOfRenalDisease,
			MAX(CASE WHEN future.IsEmergencyAdmission = 1 AND future.AdmissionDate <= DATEADD(DAY, 30, a.AdmissionDate) THEN 1 ELSE 0 END) AS IsEmergencyReadmissionWithin30Days
		FROM 
			dbo.HospitalAdmissions a
			LEFT OUTER JOIN dbo.HospitalAdmissions prev
				ON prev.PatientId = a.PatientId
				AND prev.AdmissionDate < a.AdmissionDate
			LEFT OUTER JOIN dbo.HospitalAdmissions future
				ON future.PatientId = a.PatientId
				AND future.AdmissionDate > a.AdmissionDate
		WHERE 
			a.DischargeDate IS NOT NULL
		GROUP BY 
			a.PatientId,
			a.AdmissionDate,
			a.PatientAge,
			a.PatientPostcode,
			a.IsEmergencyAdmission
	)
	SELECT TOP(500) * 
	FROM history 
	WHERE 
		IsEmergencyReadmissionWithin30Days = 1 
		AND PatientPostcode IN (SELECT DISTINCT PatientPostcode FROM dbo.vw_RiskOfReadmission_SubjectData)

	UNION ALL 

	SELECT TOP(500) * 
	FROM history
	WHERE 
		IsEmergencyReadmissionWithin30Days = 0
		AND PatientPostcode IN (SELECT DISTINCT PatientPostcode FROM dbo.vw_RiskOfReadmission_SubjectData);
GO