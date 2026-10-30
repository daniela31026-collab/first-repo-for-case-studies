## package downloading

library(dplyr)

### 1 - Load files into data frames
data_dict <- read.csv("data_dictionary.csv", stringsAsFactors = FALSE)
pk_obs <- read.csv("dataset_1_pk_observations.csv", stringsAsFactors = FALSE)
subjects <- read.csv("dataset_2_subjects.csv", stringsAsFactors = FALSE)
study <- read.csv("dataset_3_study.csv", stringsAsFactors = FALSE)

#checking structure, variable types and dimensions of data frames
str(data_dict)
str(pk_obs)
str(subjects)
str(study)

#### 2 - Data sets cleaning

##Data_set_1_PK_Observations

pk_obs_clean <- pk_obs

# Retain raw shadow column for subject ID and standardize to character/matching ID format
pk_obs_clean$Subject_raw <- pk_obs_clean$Subject
pk_obs_clean$Subject <- gsub("SUB", "", pk_obs_clean$Subject)

# Standardize dates into ISO standard (YYYY-MM-DD) handling multiple formats
pk_obs_clean$SampleDate_raw <- pk_obs_clean$SampleDate
parse_dates <- function(date_str) {
  # Try YYYY-MM-DD
  parsed <- as.Date(date_str, format="%Y-%m-%d")
  # Try DD/MM/YYYY
  parsed[is.na(parsed)] <- as.Date(date_str[is.na(parsed)], format="%d/%m/%Y")
  # Try DD.MM.YYYY
  parsed[is.na(parsed)] <- as.Date(date_str[is.na(parsed)], format="%d.%m.%Y")
  return(as.character(parsed))
}
pk_obs_clean$SampleDate <- parse_dates(pk_obs_clean$SampleDate)

# Clean Concentration & build Conc_Flag companion column
pk_obs_clean$Concentration_ng_mL_raw <- pk_obs_clean$Concentration_ng_mL

clean_concentration <- function(val) {
  # Handle NA / missing
  if (is.na(val) || val == "") {
    return(list(val = NA_real_, flag = "Missing"))
  }
  
  val_trim <- trimws(as.character(val))
  
  if (val_trim == "BLQ") {
    return(list(val = NA_real_, flag = "BLQ"))
  }
  
  # Replace comma decimal separator with dot
  val_clean <- gsub(",", ".", val_trim)
  num_val <- suppressWarnings(as.numeric(val_clean))
  
  if (is.na(num_val)) {
    return(list(val = NA_real_, flag = "Missing"))
  } else if (num_val < 0) {
    return(list(val = num_val, flag = "Below zero — implausible"))
  } else {
    return(list(val = num_val, flag = "OK"))
  }
}

# Apply concentration cleaning row-by-row
conc_results <- lapply(pk_obs_clean$Concentration_ng_mL, clean_concentration)
pk_obs_clean$Concentration_ng_mL <- sapply(conc_results, function(x) x$val)
pk_obs_clean$Conc_Flag <- sapply(conc_results, function(x) x$flag)

# Making sure Subject as character for later join purposes
pk_obs_clean$Subject <- as.character(pk_obs_clean$Subject)
pk_obs_clean$Study <- as.character(pk_obs_clean$Study)

##Data_set_2_Subjects

subjects_clean <- subjects

# Standardize Sex vocabulary ('Female' -> 'F') with shadow column
subjects_clean$Sex_raw <- subjects_clean$Sex
subjects_clean$Sex[subjects_clean$Sex == "Female"] <- "F"

# Standardize Treatment casing ('Low' and 'LOW' -> 'LOW') with shadow column
subjects_clean$Treatment_raw <- subjects_clean$Treatment
subjects_clean$Treatment <- toupper(subjects_clean$Treatment)

#turning Subject ID into character for final join purposes
subjects_clean$SubjectID <- as.character(subjects_clean$SubjectID)
subjects_clean$StudyID <- as.character(subjects_clean$StudyID)


##Data_set_3_Study

study_clean <- study

# Standardize Country ('DE' -> 'Germany')
study_clean$Country_raw <- study_clean$Country
study_clean$Country[study_clean$Country == "DE"] <- "Germany"

# Standardize Assay ('LCMSMS' -> 'LC-MS/MS')
study_clean$Assay_raw <- study_clean$Assay
study_clean$Assay[study_clean$Assay == "LCMSMS"] <- "LC-MS/MS"

# Standardize StudyStatus ('complete' -> 'Completed')
study_clean$StudyStatus_raw <- study_clean$StudyStatus
study_clean$StudyStatus[study_clean$StudyStatus == "complete"] <- "Completed"

#Safety step to ensure character type
study_clean$StudyID <- as.character(study_clean$StudyID)

### 3 - Clean, analysis ready data sets keeping Conc_Flag

# Check and report duplicate rows for interview documentation
duplicate_count <- sum(duplicated(pk_obs_clean))
message(paste("Found", duplicate_count, "duplicate rows in PK observations."))

# Dropping raw columns, removing exact duplicates, and handling negative values
pk_obs_final <- pk_obs_clean %>%
  distinct() %>%
  select(-ends_with("_raw")) %>%
  mutate(
    # Convert negative concentrations to NA for safe math, preserving the flag for audit
    Concentration_ng_mL = if_else(Concentration_ng_mL < 0, NA_real_, Concentration_ng_mL)
  )

subjects_final <- subjects_clean %>%
  select(-ends_with("_raw"))

study_final <- study_clean %>%
  select(-ends_with("_raw"))

### 4 - Final step of joining final data_sets into one final analysis_ready table

analysis_ready <- pk_obs_final %>%
  left_join(subjects_final, by = c("Subject" = "SubjectID", "Study" = "StudyID")) %>%
  left_join(study_final, by = c("Study" = "StudyID")) %>%
  mutate(
    Study_All_Metadata_Available = !is.na(Country)  & !is.na(Assay) & !is.na(LLOQ_ng_mL)& !is.na(PlannedDose_mg),
    Has_Full_Demographics = !is.na(Treatment) & !is.na(Sex) & !is.na(Weight_kg)
  )

subjects_without_obs <- subjects_final %>%
  anti_join(pk_obs_final, by = c("SubjectID" = "Subject", "StudyID" = "Study")) %>%
  mutate(Has_Observations = FALSE)

### 5 - Exporting files

# Export the final clean files
write.csv(pk_obs_final, "dataset_1_pk_observations_clean_final.csv", row.names = FALSE)
write.csv(subjects_final, "dataset_2_subjects_clean_final.csv", row.names = FALSE)
write.csv(study_final, "dataset_3_study_clean_final.csv", row.names = FALSE)

# Export the final analysis ready file
write.csv(analysis_ready, "analysis_ready.csv", row.names = FALSE)
write.csv(subjects_without_obs, "subjects_without_obs.csv", row.names = FALSE)
