# PK Data Standardization Workflow

## Purpose
Combines three raw data sources (PK observations, subject demographics, 
study metadata) into one standardized, analysis-ready table, while 
preserving traceability of all corrections and flagging data 
completeness gaps.

## Inputs
- dataset_1_pk_observations.csv
- dataset_2_subjects.csv
- dataset_3_study.csv
(see data_dictionary.csv for expected fields/types)


## What the script does
1. Standardizes subject/study identifiers, date formats, and decimal 
   separators
2. Normalizes categorical vocabularies (Sex, Treatment casing, Country, 
   Assay, StudyStatus)
3. Flags: BLQ values, missing values, implausible (negative) concentrations, 
and duplicate rows
4. Flags records with missing linked data (e.g., observations with no 
   matching study metadata, or subjects with no observations)
5. Joins all three sources into one long-format analysis-ready table

## Outputs
- analysis_ready.csv — one row per subject & time point observation
- subjects_without_obs.csv — subjects with demographic data but no 
  recorded observations (for follow-up)

## Known data issues at time of writing
- dataset_1_pk_observations.csv
1. Type mismatch for concentration: num according to the metadata but read in
as character
2. Mixed representation of Conc_ values: missing values; negative values;
chr (BLQ) and non-standard decimal values 
3. Irregular subject entries (SUB1003 - 1003)
4. Inconsistent date formats
5. A duplicate row (for subject 1004)
6. Study without studyID (PK03)

- dataset_2_subjects.csv
1. Type mismatch for SubjectID: character according to metadata & read in as int
2. Inconsistent treatment labels: two types (A/B AND Low/High) and
irregular formatting
3. Inconsistent sex coding: F and Female
4. Missing value for weight
5. Subject 2004 without observations

- dataset_3_study.csv
1. Inconsistent country and assay naming (Germany vs DE) (LC-MS/MS vs LCMSMS)
2. Inconsistent status casing (Completed vs complete)


## Design decisions
- Negative concentration values are nulled but flagged (Conc_Flag), 
  not silently corrected or removed — root cause should be confirmed 
  with data source owner
- Treatment codes (A/B vs LOW/HIGH) are study-specific vocabularies, 
  not standardized against each other, since they don't represent 
  the same category

## Maintainer notes
- Script assumes 3 known date formats; new formats will fail to parse 
  and require adding a new pattern to `parse_dates()`
- Adding a 4th data source: extend the join in section 6, no changes 
  needed to existing cleaning blocks
  
## Requirements
- Needed packages: dplyr