/*
 * Machine Learn:
 *
 * This script executes the R script which trains a model from our training data, then
 * runs predicitions on our subject data. The results are inserted into a table variable, 
 * which is then used to update the risk of readmission attribute on the hospital admissions
 * table.
 *
 **************************************************************************************/

DECLARE @Results TABLE (
	RiskOfReadmission FLOAT NOT NULL,
	PatientId INT NOT NULL,
	AdmissionDate DATE NOT NULL,
	PatientAge INT NOT NULL,
	PatientPostcode VARCHAR(6) NOT NULL,
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
	IsHistoryOfRenalDisease BIT NOT NULL
);

INSERT INTO @Results
	EXECUTE sp_execute_external_script
		@language =N'R',
		@script=N'
			library(healthcareai);

			db_conn <- "Driver=SQL Server;Server=sql-vm;Database=HealthcareAI;Uid=user1;Pwd=password;";

			training_data_q <- "SELECT * FROM dbo.vw_RiskOfReadmission_TrainingData";
			training_data <- RxSqlServerData(connectionString=db_conn, sqlQuery=training_data_q);
			training_data <- rxDataStep(training_data);

			models <- machine_learn(training_data, PatientId, AdmissionDate, outcome=IsEmergencyReadmissionWithin30Days);

			subject_data_q <- "SELECT * FROM dbo.vw_RiskOfReadmission_SubjectData;";
			subject_data <- RxSqlServerData(connectionString=db_conn, sqlQuery=subject_data_q);
			subject_data <- rxDataStep(subject_data);

			OutputDataSet <- predict(models, subject_data);
		';

UPDATE a
SET RiskOfReadmission = r.RiskOfReadmission
FROM
	dbo.HospitalAdmissions a
	INNER JOIN @Results r
		ON a.PatientId = r.PatientId
		AND a.AdmissionDate = r.AdmissionDate;