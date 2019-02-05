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
 * TODO: user
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
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcode,
		admissions.IsEmergencyAdmission,
		MAX(CASE WHEN previous.IsEmergencyAdmission = 1 AND previous.AdmissionDate >= DATEADD(DAY, -30, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsEmergencyAdmissionLast30Days,
		SUM(CASE WHEN previous.IsEmergencyAdmission = 1 AND previous.AdmissionDate >= DATEADD(MONTH, -12, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS NumberOfEmergencyAdmissionsLast12Months,
		MAX(CASE WHEN previous.IsCongestiveHeartFailure = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfCongestiveHeartFailure,
		MAX(CASE WHEN previous.IsPeripheralVascularDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfPeripheralVascularDisease,
		MAX(CASE WHEN previous.IsDementia = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDementia, 
		MAX(CASE WHEN previous.IsChronicPulmonaryDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfChronicPulmonaryDisease,
		MAX(CASE WHEN previous.IsOtherLiverDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherLiverDisease,
		MAX(CASE WHEN previous.IsOtherMalignantCancer = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfOtherMalignantCancer,
		MAX(CASE WHEN previous.IsMetastaticCancerWithSolidTumour = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
		MAX(CASE WHEN previous.IsModerateOrSevereLiverDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfModerateOrSevereLiverDisease,
		MAX(CASE WHEN previous.IsDiabetesWithChronicComplications = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfDiabetesWithChronicComplications,
		MAX(CASE WHEN previous.IsHemiplegiaOrParaplegia = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfHemiplegiaOrParaplegia,
		MAX(CASE WHEN previous.IsRenalDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
			THEN 1
			ELSE 0
		END) AS IsHistoryOfRenalDisease
	FROM 
		dbo.HospitalAdmissions admissions
		LEFT OUTER JOIN dbo.HospitalAdmissions previous
			ON previous.PatientId = admissions.PatientId
			AND previous.AdmissionDate < admissions.AdmissionDate
	WHERE 
		admissions.DischargeDate IS NULL
	GROUP BY 
		admissions.PatientId,
		admissions.AdmissionDate,
		admissions.PatientAge,
		admissions.PatientPostcode,
		admissions.IsEmergencyAdmission;
GO


DROP VIEW IF EXISTS dbo.vw_RiskOfReadmission_TrainingData;	
GO

CREATE VIEW dbo.vw_RiskOfReadmission_TrainingData AS
	WITH history AS (
		SELECT
			admissions.PatientId,
			admissions.AdmissionDate,
			admissions.PatientAge,
			admissions.PatientPostcode,
			admissions.IsEmergencyAdmission,
			MAX(CASE WHEN previous.IsEmergencyAdmission = 1 AND previous.AdmissionDate >= DATEADD(DAY, -30, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsEmergencyAdmissionLast30Days,
			SUM(CASE WHEN previous.IsEmergencyAdmission = 1 AND previous.AdmissionDate >= DATEADD(MONTH, -12, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS NumberOfEmergencyAdmissionsLast12Months,
			MAX(CASE WHEN previous.IsCongestiveHeartFailure = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfCongestiveHeartFailure,
			MAX(CASE WHEN previous.IsPeripheralVascularDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfPeripheralVascularDisease,
			MAX(CASE WHEN previous.IsDementia = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfDementia, 
			MAX(CASE WHEN previous.IsChronicPulmonaryDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfChronicPulmonaryDisease,
			MAX(CASE WHEN previous.IsOtherLiverDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfOtherLiverDisease,
			MAX(CASE WHEN previous.IsOtherMalignantCancer = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfOtherMalignantCancer,
			MAX(CASE WHEN previous.IsMetastaticCancerWithSolidTumour = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfMetastaticCancerWithSolidTumour,
			MAX(CASE WHEN previous.IsModerateOrSevereLiverDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfModerateOrSevereLiverDisease,
			MAX(CASE WHEN previous.IsDiabetesWithChronicComplications = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfDiabetesWithChronicComplications,
			MAX(CASE WHEN previous.IsHemiplegiaOrParaplegia = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfHemiplegiaOrParaplegia,
			MAX(CASE WHEN previous.IsRenalDisease = 1 AND previous.AdmissionDate >= DATEADD(YEAR, -2, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsHistoryOfRenalDisease,
			MAX(CASE WHEN future.IsEmergencyAdmission = 1 AND future.AdmissionDate <= DATEADD(DAY, 30, admissions.AdmissionDate)
				THEN 1
				ELSE 0
			END) AS IsEmergencyReadmissionWithin30Days
		FROM 
			dbo.HospitalAdmissions admissions
			LEFT OUTER JOIN dbo.HospitalAdmissions previous
				ON previous.PatientId = admissions.PatientId
				AND previous.AdmissionDate < admissions.AdmissionDate
			LEFT OUTER JOIN dbo.HospitalAdmissions future
				ON future.PatientId = admissions.PatientId
				AND future.AdmissionDate > admissions.AdmissionDate
		WHERE 
			admissions.DischargeDate IS NOT NULL
		GROUP BY 
			admissions.PatientId,
			admissions.AdmissionDate,
			admissions.PatientAge,
			admissions.PatientPostcode,
			admissions.IsEmergencyAdmission
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
		AND PatientPostcode IN (SELECT DISTINCT PatientPostcode FROM dbo.vw_RiskOfReadmission_SubjectData)
GO