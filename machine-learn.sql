TRUNCATE TABLE dbo.PredictedReadmissions;

INSERT INTO dbo.PredictedReadmissions
	EXECUTE sp_execute_external_script
		@language =N'R',
		@script=N'
			library(healthcareai);

			db_conn <- "Driver=SQL Server;Server=sql-vm;Database=HealthcareAI;Uid=user1;Pwd=password;";

			training_data_q <- "SELECT * FROM dbo.vw_PredictedReadmissions_TrainingData";
			training_data <- RxSqlServerData(connectionString=db_conn, sqlQuery=training_data_q);
			training_data <- rxDataStep(training_data);

			models <- machine_learn(training_data, PatientId, AdmissionDate, outcome=IsEmergencyReadmissionWithin30Days);

			subject_data_q <- "SELECT * FROM dbo.vw_HospitalAdmissions_Current;";
			subject_data <- RxSqlServerData(connectionString=db_conn, sqlQuery=subject_data_q);
			subject_data <- rxDataStep(subject_data);

			OutputDataSet <- predict(models, subject_data);
		'

SELECT * FROM dbo.PredictedReadmissions;