/*
 * Create Reporting Schema:
 *
 * This script creates the reporting schema containing following objects:
 *
 * vw_Reporting_RiskOfReadmission (View): 
 * Rag rates patients currently in hospital by their risk of emergency readmission.
 *
 * vw_Reporting_RiskOfReadmission_ByAge (View):
 * Rag rates the average risk of readmission by patient age.
 *
 * vw_Reporting_RiskOfReadmission_ByPostcode (View):
 * Rag rates the average risk of readmission by patient postcode.
 *
 **************************************************************************************/
 
DROP VIEW IF EXISTS dbo.vw_Reporting_RiskOfReadmission;	
GO

CREATE VIEW dbo.vw_Reporting_RiskOfReadmission AS
	SELECT
		PatientId,
		AdmissionDate,
		PatientAge,
		PatientPostcode,
		CAST(ROUND(RiskOfReadmission * 100, 2) AS VARCHAR) + '%' AS RiskOfReadmission,
		CASE 
			WHEN RiskOfReadmission >= 0.75 THEN 'Red'
			WHEN RiskOfReadmission >= 0.5 AND RiskOfReadmission < 0.75 THEN 'Amber'
			ELSE 'Green' 
		END AS RagRating
	FROM dbo.HospitalAdmissions
	WHERE DischargeDate IS NULL;
	
	
DROP VIEW IF EXISTS dbo.vw_Reporting_RiskOfReadmission_ByAge;	
GO

CREATE VIEW dbo.vw_Reporting_RiskOfReadmission_ByAge AS
	SELECT
		PatientAge,
		CAST(ROUND(AVG(RiskOfReadmission) * 100, 2) AS VARCHAR) + '%' AS RiskOfReadmission,
		CASE 
			WHEN AVG(RiskOfReadmission) >= 0.75 THEN 'Red'
			WHEN AVG(RiskOfReadmission) >= 0.5 AND AVG(RiskOfReadmission) < 0.75 THEN 'Amber'
			ELSE 'Green' 
		END AS RagRating
	FROM dbo.HospitalAdmissions
	WHERE DischargeDate IS NULL
	GROUP BY PatientAge;
	
	
DROP VIEW IF EXISTS dbo.vw_Reporting_RiskOfReadmission_ByPostcode;	
GO

CREATE VIEW dbo.vw_Reporting_RiskOfReadmission_ByPostcode AS
	SELECT
		PatientPostcode,
		CAST(ROUND(AVG(RiskOfReadmission) * 100, 2) AS VARCHAR) + '%' AS RiskOfReadmission,
		CASE 
			WHEN AVG(RiskOfReadmission) >= 0.75 THEN 'Red'
			WHEN AVG(RiskOfReadmission) >= 0.5 AND AVG(RiskOfReadmission) < 0.75 THEN 'Amber'
			ELSE 'Green' 
		END AS RagRating
	FROM dbo.HospitalAdmissions
	WHERE DischargeDate IS NULL
	GROUP BY PatientPostcode;