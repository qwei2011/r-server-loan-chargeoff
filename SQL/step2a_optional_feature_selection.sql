SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[select_features];
GO

CREATE PROCEDURE [select_features] @training_set_table varchar(100), @test_set_table varchar(100), @selected_features_table varchar(100), @connectionString varchar(300)
AS 
BEGIN
    DECLARE @testing_set_query nvarchar(400), @del_cmd nvarchar(100), @ins_cmd nvarchar(max)
	/* 	select features using MicrosotML  */
	SET @del_cmd = 'DELETE FROM ' + @selected_features_table
	EXEC sp_executesql @del_cmd
	SET @ins_cmd = 'INSERT INTO ' + @selected_features_table + ' (feature_name)
	EXECUTE sp_execute_external_script @language = N''R'',
					   @script = N''
library(RevoScaleR)
library(MicrosoftML)
##########################################################################################################################################
##	Set the compute context to SQL for faster training
##########################################################################################################################################
testing_set <- RxSqlServerData(table=test_set, connectionString = connection_string)
training_set <- RxSqlServerData(table=train_set, connectionString = connection_string)

features <- rxGetVarNames(testing_set)
variables_to_remove <- c("memberId", "loanId", "payment_date", "loan_open_date", "charge_off")
feature_names <- features[!(features %in% variables_to_remove)]
model_formula <- as.formula(paste(paste("charge_off~"), paste(feature_names, collapse = "+")))
selected_count <- 0
features_to_remove <- c("(Bias)")
ml_trans <- list(categorical(vars = c("purpose", "residentialState", "homeOwnership", "yearsEmployment")),
                selectFeatures(model_formula, mode = mutualInformation(numFeaturesToKeep = 41)))
candidate_model <- rxLogisticRegression(model_formula, data = training_set, mlTransforms = ml_trans)
predicted_score <- rxPredict(candidate_model, testing_set, extraVarsToWrite = c("charge_off"))
predicted_roc <- rxRoc("charge_off", grep("Probability", names(predicted_score), value = T), predicted_score)
auc <- rxAuc(predicted_roc)

selected_features <- rxGetVarInfo(summary(candidate_model)$summary)
selected_feature_names <- names(selected_features)
selected_feature_filtered <- selected_feature_names[!(selected_feature_names %in% features_to_remove)]

selected_features_final <- data.frame(selected_feature_filtered)''
, @output_data_1_name = N''selected_features_final''
, @params = N''@connection_string varchar(300), @test_set varchar(100), @train_set varchar(100)''
, @connection_string = ''' + @connectionString + '''' +
', @train_set = ''' + @training_set_table + '''' +
', @test_set = ''' + @test_set_table + ''';'

EXEC sp_executesql @ins_cmd
END
GO